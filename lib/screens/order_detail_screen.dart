import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order.dart';
import '../services/orders_service.dart';
import 'order_form_screen.dart';
import '../utils/screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({required this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final ordersService = Provider.of<OrdersService>(context, listen: false);
    final imgHeight = context.hPct(0.35);

    final isDone = (order.status == 'done') || (order.paid == true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de pedido'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: isDone ? 'No editable (pedido realizado)' : 'Editar',
            // Deshabilitamos editar si ya está realizado/pagado
            onPressed: isDone
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderFormScreen(orderId: order.id))),
          ),
          // Botón para marcar como realizado
          IconButton(
            icon:
                Icon(order.status == 'done' ? Icons.check_circle : Icons.check),
            tooltip: 'Marcar como realizado',
            onPressed: order.status == 'done'
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Marcar como realizado'),
                        content: const Text(
                            '¿Deseas marcar este pedido como realizado? Esto también marcará como pagado.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sí')),
                        ],
                      ),
                    );

                    if (confirm ?? false) {
                      try {
                        await ordersService.markAsDone(order.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Pedido marcado como realizado')));
                          Navigator.pop(context); // volver a la lista
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                        title: const Text('Eliminar pedido'),
                        content: const Text(
                            '¿Seguro que quieres eliminar este pedido?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar')),
                        ],
                      ));
              if (confirm ?? false) {
                await ordersService.deleteOrder(order.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(context.wPct(0.04)),
        child: ListView(
          children: [
            if (order.imageUrl != null)
              SizedBox(
                  height: imgHeight,
                  child: CachedNetworkImage(
                      imageUrl: order.imageUrl!, fit: BoxFit.cover)),
            SizedBox(height: context.hPct(0.02)),
            Text('Cliente: ${order.customerName}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: context.hPct(0.01)),
            Text('Tela: ${order.fabric}'),
            Text('Color: ${order.color}'),
            Text('Talla: ${order.size}'),
            Text('Precio: \$${order.price.toStringAsFixed(2)}'),
            SizedBox(height: context.hPct(0.01)),
            Text('Estado: ${order.status}'),
            Text('Pagado: ${order.paid ? 'Sí' : 'No'}'),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              SizedBox(height: context.hPct(0.01)),
              Text('Notas: ${order.notes}'),
            ],
          ],
        ),
      ),
    );
  }
}
