// lib/models/order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? ownerId;
  final String? ownerName;

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
    this.ownerId,
    this.ownerName,
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
        'ownerId': ownerId,
        'ownerName': ownerName,
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
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
      paid: map['paid'] ?? false,
      notes: map['notes'],
      imageUrl: map['imageUrl'],
      updatedBy: map['updatedBy'],
      ownerId: map['ownerId'],
      ownerName: map['ownerName'],
    );
  }
}
