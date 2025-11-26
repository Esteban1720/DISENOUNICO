// lib/modelos/pedido.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Pedido {
  final String id;
  final String nombreCliente;
  final String tela;
  final String color;
  final String talla;
  final double precio;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;
  final String estado;
  final bool pagado;
  final String? notas;
  final String? imagenUrl;
  final String? actualizadoPor;
  final String? propietarioId;
  final String? propietarioNombre;

  Pedido({
    required this.id,
    required this.nombreCliente,
    required this.tela,
    required this.color,
    required this.talla,
    required this.precio,
    required this.creadoEn,
    this.actualizadoEn,
    this.estado = 'pending',
    this.pagado = false,
    this.notas,
    this.imagenUrl,
    this.actualizadoPor,
    this.propietarioId,
    this.propietarioNombre,
  });

  Map<String, dynamic> toMap() => {
        // Mantener las keys usadas en Firestore para no alterar la funcionalidad
        'customerName': nombreCliente,
        'fabric': tela,
        'color': color,
        'size': talla,
        'price': precio,
        'createdAt': Timestamp.fromDate(creadoEn),
        'updatedAt':
            actualizadoEn != null ? Timestamp.fromDate(actualizadoEn!) : null,
        'status': estado,
        'paid': pagado,
        'notes': notas,
        'imageUrl': imagenUrl,
        'updatedBy': actualizadoPor,
        'ownerId': propietarioId,
        'ownerName': propietarioNombre,
      };

  factory Pedido.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Pedido(
      id: doc.id,
      nombreCliente: map['customerName'] ?? '',
      tela: map['fabric'] ?? '',
      color: map['color'] ?? '',
      talla: map['size'] ?? '',
      precio: (map['price'] ?? 0).toDouble(),
      creadoEn: (map['createdAt'] as Timestamp).toDate(),
      actualizadoEn: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      estado: map['status'] ?? 'pending',
      pagado: map['paid'] ?? false,
      notas: map['notes'],
      imagenUrl: map['imageUrl'],
      actualizadoPor: map['updatedBy'],
      propietarioId: map['ownerId'],
      propietarioNombre: map['ownerName'],
    );
  }
}
