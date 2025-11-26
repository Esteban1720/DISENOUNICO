import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../modelos/pedido.dart';
import '../servicios/servicio_pedidos.dart';
import 'order_form_screen.dart';
import '../utilidades/pantalla.dart';

class OrderDetailScreen extends StatelessWidget {
  final Pedido order;
  const OrderDetailScreen({required this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final ordersService = Provider.of<ServicioPedidos>(context, listen: false);
    final imgHeight = context.altoPct(0.35);

    final isDone = (order.estado == 'done') || (order.pagado == true);

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
                Icon(order.estado == 'done' ? Icons.check_circle : Icons.check),
            tooltip: 'Marcar como realizado',
            onPressed: order.estado == 'done'
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Marcar como realizado'),
                        content: const Text(
                            '¿Deseas marcar este pedido como realizado? Esto también marcará como pagado.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar')),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Sí')),
                        ],
                      ),
                    );

                    if (confirm ?? false) {
                      // ignore: use_build_context_synchronously
                      final messenger = ScaffoldMessenger.of(context);
                      // ignore: use_build_context_synchronously
                      final navigator = Navigator.of(context);
                      try {
                        await ordersService.markAsDone(order.id);
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Pedido marcado como realizado')));
                        navigator.pop(); // volver a la lista
                      } catch (e) {
                        messenger
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                        title: const Text('Eliminar pedido'),
                        content: const Text(
                            '¿Seguro que quieres eliminar este pedido?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar')),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Eliminar')),
                        ],
                      ));
              if (confirm ?? false) {
                await ordersService.eliminarPedido(order.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(context.anchoPct(0.04)),
        child: ListView(
          children: [
            if (order.imagenUrl != null)
              SizedBox(
                  height: imgHeight,
                  child: CachedNetworkImage(
                      imageUrl: order.imagenUrl!, fit: BoxFit.cover)),
            SizedBox(height: context.altoPct(0.02)),
            Text('Cliente: ${order.nombreCliente}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: context.altoPct(0.01)),
            Text('Tela: ${order.tela}'),
            Text('Color: ${order.color}'),
            Text('Talla: ${order.talla}'),
            Text('Precio: \$${order.precio.toStringAsFixed(2)}'),
            SizedBox(height: context.altoPct(0.01)),
            Text('Estado: ${order.estado}'),
            Text('Pagado: ${order.pagado ? 'Sí' : 'No'}'),
            if (order.notas != null && order.notas!.isNotEmpty) ...[
              SizedBox(height: context.altoPct(0.01)),
              Text('Notas: ${order.notas}'),
            ],
          ],
        ),
      ),
    );
  }
}
