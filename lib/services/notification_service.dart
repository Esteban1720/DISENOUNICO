// lib/services/notification_service.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String?
      _currentUser; // username almacenado en prefs (AuthService guarda 'logged_user')

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _local.initialize(settings);

    // load current username from shared prefs (AuthService saves it)
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUser = prefs.getString('logged_user');
      print('NotificationService.init: currentUser=$_currentUser');
    } catch (e) {
      _currentUser = null;
      print('NotificationService.init: error reading prefs: $e');
    }

    // Request permission via platform channel if needed (kept as in original)
    try {
      final granted = await requestNotificationPermission();
      print(
          'NotificationService.init: notification permission granted=$granted');
    } catch (e) {
      print(
          'NotificationService.init: error requesting platform permission: $e');
    }

    try {
      const androidChannel = AndroidNotificationChannel(
        'orders_channel',
        'Orders',
        description: 'Notificaciones de pedidos',
        importance: Importance.max,
      );
      final androidImpl = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(androidChannel);
        print('NotificationService.init: Android channel created');
      } else {
        print('NotificationService.init: Android implementation not available');
      }
    } catch (e) {
      print('NotificationService.init: error creating Android channel: $e');
    }

    print('NotificationService.init: skipping explicit iOS permission request');
  }

  /// Request notification permission via platform-specific MethodChannel.
  Future<bool> requestNotificationPermission() async {
    const channel = MethodChannel('disenounico/permissions');
    try {
      final result =
          await channel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print(
          'NotificationService.requestNotificationPermission: PlatformException $e');
      return false;
    } catch (e) {
      print('NotificationService.requestNotificationPermission: error $e');
      return false;
    }
  }

  /// Start listening to the fallback 'notifications' collection.
  /// Now uses a recipients list (uids). Only notifies if current user is in recipients.
  Future<void> startListening() async {
    // Cancel any previous subscription
    await stopListening();

    print(
        'NotificationService.startListening: subscribing to notifications collection');
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) async {
      print(
          'NotificationService: notifications snapshot received with changes=${snap.docChanges.length}');

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      for (final change in snap.docChanges) {
        try {
          if (change.type != DocumentChangeType.added) {
            continue; // only new docs
          }
          final data = change.doc.data();
          if (data == null) continue;

          // Expect recipients to be a list of UIDs.
          final recipients = (data['recipients'] is List)
              ? List<String>.from(data['recipients'].map((e) => e.toString()))
              : <String>[];

          // If recipients is empty, skip (or optionally show to all authenticated users).
          if (recipients.isEmpty) {
            print(
                'NotificationService: notification ${change.doc.id} has no recipients -> skipping');
            continue;
          }

          if (currentUid == null) {
            print(
                'NotificationService: no firebase auth uid available -> skipping notification');
            continue;
          }

          // Only notify if current user is listed as recipient
          if (!recipients.contains(currentUid)) {
            print(
                'NotificationService: currentUid not in recipients -> skipping (${change.doc.id})');
            continue;
          }

          // Prefer actorDisplayName if present, then actorName, then fallback.
          final actorDisplay = (data['actorDisplayName'] as String?)?.trim();
          final actorName = (data['actorName'] as String?)?.trim();
          final actorSafe = actorDisplay?.isNotEmpty == true
              ? actorDisplay!
              : (actorName?.isNotEmpty == true ? actorName! : 'Alguien');

          final action = (data['action'] as String?) ?? '';
          String title;
          String body;
          if (action == 'created') {
            title = 'Nuevo pedido';
            body = '$actorSafe creó un pedido.';
          } else if (action == 'updated') {
            title = 'Pedido actualizado';
            body = '$actorSafe actualizó un pedido.';
          } else if (action == 'deleted') {
            title = 'Pedido eliminado';
            body = '$actorSafe eliminó un pedido.';
          } else {
            title = 'Pedido';
            body = '$actorSafe hizo un cambio en pedidos.';
          }

          print(
              'NotificationService: showing notification id=${change.doc.id} title="$title" body="$body"');

          await _showLocalNotification(title, body);

          // After showing, remove currentUid from recipients transactionally.
          await _consumeNotificationFor(change.doc.id, currentUid);
        } catch (e) {
          print('NotificationService: error handling notification doc: $e');
        }
      }
    }, onError: (e) {
      print('NotificationService.startListening: snapshot listen error: $e');
    });
  }

  Future<void> _consumeNotificationFor(String docId, String uid) async {
    final docRef =
        FirebaseFirestore.instance.collection('notifications').doc(docId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final d = snap.data()!;
        final List<dynamic> curr = List<dynamic>.from(d['recipients'] ?? []);
        final recipients = curr.map((e) => e.toString()).toList();
        if (!recipients.contains(uid)) return;
        final updated = List<String>.from(recipients)..remove(uid);
        if (updated.isEmpty) {
          // delete the doc if no recipients remain
          tx.delete(docRef);
        } else {
          tx.update(docRef, {
            'recipients': updated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      print('NotificationService: consumed notification $docId for $uid');
    } catch (e) {
      print('NotificationService: failed to consume notification $docId: $e');
    }
  }

  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'orders_channel',
      'Orders',
      channelDescription: 'Notificaciones de pedidos',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _local.show(id, title, body, details);
  }
}
