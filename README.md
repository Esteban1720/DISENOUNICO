Diseño Único — App de gestión de pedidos (Flutter)

Resumen

Aplicación Flutter para que Esteban y Luisa administren pedidos de camisetas personalizadas de la empresa Diseño Único. Permite crear, editar, eliminar y ver pedidos en tiempo real (Firestore), adjuntar una imagen por pedido (Firebase Storage) y recibir notificaciones en la app (FCM). Diseñada como MVP para usarse entre los dos socios.


---

Características principales

Autenticación: Firebase Authentication (Email/Password u otro proveedor).

Base de datos: Cloud Firestore para almacenar pedidos en tiempo real.

Almacenamiento de imágenes: Firebase Storage (una imagen por pedido).

Notificaciones: Firebase Cloud Messaging (FCM) + flutter_local_notifications para primer plano.

State management: Provider o Riverpod (sugerido).


Campos por pedido

id (doc id)

customerName (String)

fabric (String)

color (String)

size (String)

price (double)

createdAt (timestamp)

updatedAt (timestamp opcional)

status ("pending" | "done")

paid (boolean)

notes (String?)

imageUrl (String?)

updatedBy (String?)



---

Estructura recomendada del proyecto

lib/
├─ main.dart
├─ models/
│  └─ order.dart
├─ services/
│  ├─ auth_service.dart
│  ├─ firestore_service.dart
│  ├─ storage_service.dart
│  └─ notification_service.dart
├─ providers/
├─ screens/
│  ├─ orders_list_screen.dart
│  ├─ order_detail_screen.dart
│  └─ order_form_screen.dart
├─ widgets/
│  └─ order_tile.dart


---

Dependencias sugeridas (pubspec.yaml)

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.10.0
  cloud_firestore: ^4.9.0
  firebase_auth: ^4.6.0
  firebase_messaging: ^14.5.0
  firebase_storage: ^11.0.0
  provider: ^6.0.5
  image_picker: ^0.8.7+4
  flutter_local_notifications: ^13.0.0
  cached_network_image: ^3.2.3


---

Flujo sugerido para crear un pedido con imagen

1. Crear documento de pedido en orders con campos básicos (sin imageUrl) y createdAt.


2. Obtener orderId (document id) generado por Firestore.


3. Elegir imagen (cámara/galería) y subirla a Storage en ruta orders/{orderId}/{timestamp}.jpg.


4. Obtener downloadURL y actualizar el documento de pedido con imageUrl y updatedAt.



Este flujo evita guardar imágenes sin relación a un pedido.


---

Reglas básicas (Firestore y Storage)

Firestore

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /orders/{orderId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}

Storage

rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /orders/{orderId}/{allPaths=} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /{allPaths=} {
      allow read, write: if false;
    }
  }
}


---

Buenas prácticas para imágenes

Comprimir y redimensionar antes de subir (imageQuality, resize).

Usar nombres de archivo con orderId y timestamp.

Eliminar imagen en Storage cuando se elimina el pedido.

Cachear imágenes en la app con cached_network_image.

Monitorizar almacenamiento y descargas para controlar costos.



---

Código de ejemplo: orders_service.dart (CRUD + upload/delete image)

> Guarda este archivo en lib/services/orders_service.dart



import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class OrderModel {
  final String id;
  final String customerName;
  final String fabric;
  final String color;
  final String size;
  final double price;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;
  final bool paid;
  final String? notes;
  final String? imageUrl;
  final String? updatedBy;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.fabric,
    required this.color,
    required this.size,
    required this.price,
    required this.createdAt,
    this.updatedAt,
    this.status = 'pending',
    this.paid = false,
    this.notes,
    this.imageUrl,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'fabric': fabric,
        'color': color,
        'size': size,
        'price': price,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'status': status,
        'paid': paid,
        'notes': notes,
        'imageUrl': imageUrl,
        'updatedBy': updatedBy,
      };

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customerName: map['customerName'] ?? '',
      fabric: map['fabric'] ?? '',
      color: map['color'] ?? '',
      size: map['size'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'pending',
      paid: map['paid'] ?? false,
      notes: map['notes'],
      imageUrl: map['imageUrl'],
      updatedBy: map['updatedBy'],
    );
  }
}

class OrdersService {
  final _orders = FirebaseFirestore.instance.collection('orders');
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Stream<List<OrderModel>> ordersStream() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map((snap) =>
        snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
  }

  Future<String> createOrder(Map<String, dynamic> data) async {
    final docRef = await _orders.add(data..['createdAt'] = FieldValue.serverTimestamp());
    return docRef.id;
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _orders.doc(orderId).update(data);
  }

  Future<void> deleteOrder(String orderId) async {
    // borrar imagen asociada si existe
    final doc = await _orders.doc(orderId).get();
    final map = doc.data();
    if (map != null && map['imageUrl'] != null) {
      try {
        final imageUrl = map['imageUrl'] as String;
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        // no bloquear el borrado por errores en Storage
        print('Error deleting image: $e');
      }
    }
    await _orders.doc(orderId).delete();
  }

  /// Abre galería/cámara, sube la imagen y retorna downloadURL.
  Future<String?> pickAndUploadImage(String orderId, {ImageSource source = ImageSource.gallery, int imageQuality = 80}) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: imageQuality);
    if (picked == null) return null;
    final file = File(picked.path);
    final path = 'orders/$orderId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  Future<void> attachImageToOrder(String orderId, String imageUrl) async {
    await _orders.doc(orderId).update({
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeImageFromOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final map = doc.data();
    if (map != null && map['imageUrl'] != null) {
      try {
        final imageUrl = map['imageUrl'] as String;
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        print('Error deleting image: $e');
      }
    }
    await _orders.doc(orderId).update({
      'imageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}


---

Notas sobre notificaciones (resumen)

Guardar token FCM por usuario en users/{uid}/fcmToken.

Usar Cloud Functions para enviar notificaciones al otro socio cuando se crea/actualiza/elimina un pedido.

Para mostrar notificaciones en foreground, integrar flutter_local_notifications y manejar FirebaseMessaging.onMessage.



---

Sugerencias de siguientes pasos

Copiar orders_service.dart a lib/services/ y adaptar imports si usas un patrón diferente.

Implementar pantallas con StreamBuilder para ordersStream().

Añadir flujo UI para crear pedido, luego llamar a pickAndUploadImage + attachImageToOrder si hay imagen.



---

¡Listo! Si quieres que también genere:

order_form_screen.dart (pantalla para crear/editar pedidos con subida de imagen),

Un ejemplo de Cloud Function para notificaciones, o

Un README.md independiente con pasos de instalación (comandos flutter y configuración exacta de Firebase), nómbralo y lo creo enseguida.