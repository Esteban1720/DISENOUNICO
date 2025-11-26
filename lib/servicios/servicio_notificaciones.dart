// lib/servicios/servicio_notificaciones.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ServicioNotificaciones {
  static final ServicioNotificaciones _instance =
      ServicioNotificaciones._internal();
  factory ServicioNotificaciones() => _instance;
  ServicioNotificaciones._internal();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String?
      _currentUser; // username almacenado en prefs (ServicioAutenticacion guarda 'logged_user')

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _local.initialize(settings);

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUser = prefs.getString('logged_user');
      debugPrint('ServicioNotificaciones.init: currentUser=$_currentUser');
    } catch (e) {
      _currentUser = null;
      debugPrint('ServicioNotificaciones.init: error reading prefs: $e');
    }

    try {
      final granted = await requestNotificationPermission();
      debugPrint(
          'ServicioNotificaciones.init: notification permission granted=$granted');
    } catch (e) {
      debugPrint(
          'ServicioNotificaciones.init: error requesting platform permission: $e');
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
        debugPrint('ServicioNotificaciones.init: Android channel created');
      } else {
        debugPrint(
            'ServicioNotificaciones.init: Android implementation not available');
      }
    } catch (e) {
      debugPrint(
          'ServicioNotificaciones.init: error creating Android channel: $e');
    }

    debugPrint(
        'ServicioNotificaciones.init: skipping explicit iOS permission request');
  }

  Future<bool> requestNotificationPermission() async {
    const channel = MethodChannel('disenounico/permissions');
    try {
      final result =
          await channel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          'ServicioNotificaciones.requestNotificationPermission: PlatformException $e');
      return false;
    } catch (e) {
      debugPrint(
          'ServicioNotificaciones.requestNotificationPermission: error $e');
      return false;
    }
  }

  Future<void> startListening() async {
    await stopListening();

    debugPrint(
        'ServicioNotificaciones.startListening: subscribing to notifications collection');
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) async {
      debugPrint(
          'ServicioNotificaciones: notifications snapshot received with changes=${snap.docChanges.length}');

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      for (final change in snap.docChanges) {
        try {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;

          final recipients = (data['recipients'] is List)
              ? List<String>.from(data['recipients'].map((e) => e.toString()))
              : <String>[];

          if (recipients.isEmpty) {
            debugPrint(
                'ServicioNotificaciones: notification ${change.doc.id} has no recipients -> skipping');
            continue;
          }

          if (currentUid == null) {
            debugPrint(
                'ServicioNotificaciones: no firebase auth uid available -> skipping notification');
            continue;
          }

          if (!recipients.contains(currentUid)) {
            debugPrint(
                'ServicioNotificaciones: currentUid not in recipients -> skipping (${change.doc.id})');
            continue;
          }

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

          debugPrint(
              'ServicioNotificaciones: showing notification id=${change.doc.id} title="$title" body="$body"');
          await _showLocalNotification(title, body);
          await _consumeNotificationFor(change.doc.id, currentUid);
        } catch (e) {
          debugPrint(
              'ServicioNotificaciones: error handling notification doc: $e');
        }
      }
    }, onError: (e) {
      debugPrint(
          'ServicioNotificaciones.startListening: snapshot listen error: $e');
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
          tx.delete(docRef);
        } else {
          tx.update(docRef, {
            'recipients': updated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      debugPrint(
          'ServicioNotificaciones: consumed notification $docId for $uid');
    } catch (e) {
      debugPrint(
          'ServicioNotificaciones: failed to consume notification $docId: $e');
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
