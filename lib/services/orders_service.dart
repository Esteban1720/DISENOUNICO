// lib/services/orders_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../config.dart';

class OrdersService {
  CollectionReference get _orders =>
      FirebaseFirestore.instance.collection('orders');
  CollectionReference get _users =>
      FirebaseFirestore.instance.collection('users');
  CollectionReference get _profiles =>
      FirebaseFirestore.instance.collection('profiles');

  final ImagePicker _picker = ImagePicker();

  /// Intenta resolver el uid real a partir de un username guardado en /users o /profiles.
  Future<String?> _resolveUidFromUsername(String username) async {
    try {
      final uDoc = await _users.doc(username).get();
      if (uDoc.exists && uDoc.data() != null) {
        final d = uDoc.data() as Map<String, dynamic>;
        if (d['ownerUid'] is String && (d['ownerUid'] as String).isNotEmpty) {
          return d['ownerUid'] as String;
        }
        if (d['uid'] is String && (d['uid'] as String).isNotEmpty) {
          return d['uid'] as String;
        }
      }
    } catch (_) {}
    try {
      final pDoc = await _profiles.doc(username).get();
      if (pDoc.exists && pDoc.data() != null) {
        final pd = pDoc.data() as Map<String, dynamic>;
        if (pd['ownerUid'] is String && (pd['ownerUid'] as String).isNotEmpty) {
          return pd['ownerUid'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Devuelve displayName (perfil) para un uid, buscando primero en /profiles y luego en /users.
  Future<String?> _displayNameForUid(String uid) async {
    try {
      final q1 =
          await _profiles.where('ownerUid', isEqualTo: uid).limit(1).get();
      if (q1.docs.isNotEmpty) {
        final d = q1.docs.first.data() as Map<String, dynamic>;
        if (d['displayName'] is String &&
            (d['displayName'] as String).isNotEmpty) {
          return d['displayName'] as String;
        }
      }
    } catch (e) {
      debugPrint('_displayNameForUid: profiles lookup error: $e');
    }
    try {
      final q2 = await _users.where('ownerUid', isEqualTo: uid).limit(1).get();
      if (q2.docs.isNotEmpty) {
        final d = q2.docs.first.data() as Map<String, dynamic>;
        if (d['displayName'] is String &&
            (d['displayName'] as String).isNotEmpty) {
          return d['displayName'] as String;
        }
      }
    } catch (e) {
      debugPrint('_displayNameForUid: users lookup error: $e');
    }
    return null;
  }

  /// Construye una lista base de colaboradores incluyendo david/maria y el owner actual.
  Future<List<String>> _defaultCollaborators(String ownerUid) async {
    final set = <String>{};
    try {
      final david = await _resolveUidFromUsername('david1720');
      final maria = await _resolveUidFromUsername('maria1720');
      if (david != null && david.isNotEmpty) set.add(david);
      if (maria != null && maria.isNotEmpty) set.add(maria);
    } catch (e) {
      debugPrint('_defaultCollaborators: error resolving users: $e');
    }
    if (ownerUid.isNotEmpty) set.add(ownerUid);
    return set.toList();
  }

  Stream<List<OrderModel>> ordersStream({String? ownerUid, String? status}) {
    try {
      Query q = _orders.orderBy('createdAt', descending: true);
      if (ownerUid != null) q = q.where('ownerUid', isEqualTo: ownerUid);
      if (status != null) q = q.where('status', isEqualTo: status);
      return q
          .snapshots()
          .map((snap) => snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
    } catch (e) {
      debugPrint('ordersStream() error: $e');
      return Stream.value(<OrderModel>[]);
    }
  }

  /// Crea un pedido — AQUI se establece ownerUid/ownerId/ownerName y collaborators.
  Future<String> createOrder(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    data['createdAt'] = FieldValue.serverTimestamp();

    // Garantizar ownerUid/ownerId/ownerName en el documento de creación (reglas requieren esto)
    data['ownerUid'] = user.uid;
    data['ownerId'] = user.uid;
    data['ownerName'] =
        data['ownerName'] ?? user.displayName ?? user.email ?? '';

    // Validación mínima útil
    if (!(data['customerName'] is String)) {
      data['customerName'] = (data['customerName'] ?? '').toString();
    }
    if (!(data['price'] is num)) {
      final maybe = double.tryParse(
          (data['price'] ?? '').toString().replaceAll(',', '.'));
      data['price'] = maybe ?? 0.0;
    }

    // Construir lista inicial de colaboradores (incluye david1720 y maria1720 si existen)
    try {
      data['collaborators'] = await _defaultCollaborators(user.uid);
    } catch (e) {
      data['collaborators'] = [user.uid];
    }

    final docRef = await _orders.add(data);

    // Notificación de fallback: incluir recipients = collaborators - actorUid
    try {
      final List<dynamic> collaborators =
          List<dynamic>.from(data['collaborators'] ?? [user.uid]);
      final recipients = collaborators
          .where((c) => c is String && c != user.uid)
          .map((e) => e as String)
          .toList();

      // Resolvemos el displayName del actor (si existe)
      final actorDisplay = await _displayNameForUid(user.uid);
      final actorDisplayName =
          actorDisplay ?? data['ownerName'] ?? user.displayName ?? '';

      await FirebaseFirestore.instance.collection('notifications').add({
        'action': 'created',
        'orderId': docRef.id,
        'actorId': user.uid,
        'actorName': data['ownerName'] ?? '',
        'actorDisplayName': actorDisplayName,
        'recipients': recipients,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('createOrder: failed writing notification doc: $e');
    }

    return docRef.id;
  }

  /// Actualiza un pedido.
  /// Importante: **no** modificamos ownerUid/ownerId/collaborators aquí para evitar violar reglas.
  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // proteger campos sensibles: eliminarlos si vienen en data (owner sólo se cambia por owner explícito)
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.remove('ownerUid');
    sanitized.remove('ownerId');
    sanitized.remove('collaborators');
    sanitized.remove('createdAt');

    sanitized['updatedAt'] = FieldValue.serverTimestamp();

    await _orders.doc(orderId).update(sanitized);

    // notificación: leer doc actualizado para obtener collaborators actuales
    try {
      final doc = await _orders.doc(orderId).get();
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> collaborators =
          List<dynamic>.from(d['collaborators'] ?? []);
      final recipients = collaborators
          .where((c) => c is String && c != user.uid)
          .map((e) => e as String)
          .toList();

      // Resolvemos el displayName del actor (si existe)
      final actorDisplay = await _displayNameForUid(user.uid);
      final actorDisplayName =
          actorDisplay ?? sanitized['ownerName'] ?? user.displayName ?? '';

      await FirebaseFirestore.instance.collection('notifications').add({
        'action': 'updated',
        'orderId': orderId,
        'actorId': user.uid,
        'actorName':
            sanitized['ownerName'] ?? user.displayName ?? user.email ?? '',
        'actorDisplayName': actorDisplayName,
        'recipients': recipients,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('updateOrder: failed writing notification doc: $e');
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      final doc = await _orders.doc(orderId).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      // Antes de eliminar, guardamos collaborators para enviar notificación
      final collaborators = List<dynamic>.from(data['collaborators'] ?? []);
      await _orders.doc(orderId).delete();
      try {
        final recipients = collaborators
            .where((c) => c is String && c != user.uid)
            .map((e) => e as String)
            .toList();

        // Resolvemos el displayName del actor (si existe)
        final actorDisplay = await _displayNameForUid(user.uid);
        final actorDisplayName = actorDisplay ?? data['ownerName'] ?? '';

        await FirebaseFirestore.instance.collection('notifications').add({
          'action': 'deleted',
          'orderId': orderId,
          'actorId': user.uid,
          'actorName': data['ownerName'] ?? '',
          'actorDisplayName': actorDisplayName,
          'recipients': recipients,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('deleteOrder: failed writing notification doc: $e');
      }
    } catch (e) {
      debugPrint(
          'deleteOrder: error deleting order or writing notification: $e');
      // intentar de nuevo sin notificación
      try {
        await _orders.doc(orderId).delete();
      } catch (_) {}
    }
  }

  Future<DocumentSnapshot> getOrderDoc(String orderId) async {
    return await _orders.doc(orderId).get();
  }

  Future<File?> pickLocalImage(
      {ImageSource source = ImageSource.gallery, int imageQuality = 80}) async {
    final XFile? picked =
        await _picker.pickImage(source: source, imageQuality: imageQuality);
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<String?> uploadToCloudinary(File file,
      {String? cloudName, String? uploadPreset}) async {
    final cn = cloudName ?? cloudinaryCloudName;
    final up = uploadPreset ?? cloudinaryUploadPreset;

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cn/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = up;

    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final mediaType = MediaType.parse(mimeType);
    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: mediaType,
      filename: path.basename(file.path),
    );
    request.files.add(multipartFile);

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> jsonResp = json.decode(resp.body);
      return jsonResp['secure_url'] as String?;
    } else {
      debugPrint('Cloudinary upload failed: ${resp.statusCode} ${resp.body}');
      return null;
    }
  }

  Future<void> createOrderWithImage(
      {required Map<String, dynamic> orderData}) async {
    // Lógica: createOrder ya maneja ownerUid y collaborators
    final orderId = await createOrder(orderData);

    final file = await pickLocalImage();
    if (file == null) return;
    final imageUrl = await uploadToCloudinary(file);
    if (imageUrl != null) {
      await _orders.doc(orderId).update({
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> pickAndAttachImageToOrder({required String orderId}) async {
    final file = await pickLocalImage();
    if (file == null) return null;
    final url = await uploadToCloudinary(file);
    if (url != null) {
      await _orders.doc(orderId).update({
        'imageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return url;
  }

  Future<void> removeImageFromOrder(String orderId) async {
    await _orders.doc(orderId).update({
      'imageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp()
    });
  }

  Future<void> markAsDone(String orderId) async {
    await _orders.doc(orderId).update({
      'status': 'done',
      'paid': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Añade un colaborador (solo owner debe exponer esto en la UI)
  Future<void> addCollaborator(String orderId, String collaboratorUid) async {
    await _orders.doc(orderId).update({
      'collaborators': FieldValue.arrayUnion([collaboratorUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remueve un colaborador
  Future<void> removeCollaborator(
      String orderId, String collaboratorUid) async {
    await _orders.doc(orderId).update({
      'collaborators': FieldValue.arrayRemove([collaboratorUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
