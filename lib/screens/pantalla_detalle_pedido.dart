import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../modelos/pedido.dart';
import '../servicios/servicio_pedidos.dart';
import 'pantalla_formulario_pedido.dart';
import '../utilidades/pantalla.dart';

class PantallaDetallePedido extends StatelessWidget {
  final Pedido order;
  const PantallaDetallePedido({required this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final ordersService = Provider.of<ServicioPedidos>(context, listen: false);
    final imgHeight = context.altoPct(0.35);
    final theme = Theme.of(context);

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
                        builder: (_) =>
                            PantallaFormularioPedido(orderId: order.id))),
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
              GestureDetector(
                onTap: () async {
                  await showDialog(
                      context: context,
                      builder: (ctx) {
                        return GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            color: Colors.black,
                            child: Center(
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: order.imagenUrl!,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      });
                },
                child: SizedBox(
                    height: imgHeight,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                            imageUrl: order.imagenUrl!, fit: BoxFit.cover))),
              ),
            SizedBox(height: context.altoPct(0.02)),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(context.anchoPct(0.04)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente',
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: context.tamTexto(16))),
                    SizedBox(height: context.altoPct(0.005)),
                    Text(order.nombreCliente,
                        style: TextStyle(
                            fontSize: context.tamTexto(18),
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: context.altoPct(0.015)),
                    _infoRow(context, 'Tela', order.tela, theme),
                    _infoRow(context, 'Color', order.color, theme),
                    _infoRow(context, 'Talla', order.talla, theme),
                    _infoRow(context, 'Precio',
                        '\$${order.precio.toStringAsFixed(2)}', theme),
                    SizedBox(height: context.altoPct(0.01)),
                    Row(
                      children: [
                        Expanded(
                            child:
                                _badge(context, 'Estado', order.estado, theme)),
                        SizedBox(width: context.anchoPct(0.02)),
                        Expanded(
                            child: _badge(context, 'Pagado',
                                order.pagado ? 'Sí' : 'No', theme)),
                      ],
                    ),
                    if (order.notas != null && order.notas!.isNotEmpty) ...[
                      SizedBox(height: context.altoPct(0.015)),
                      Text('Notas',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: context.tamTexto(16))),
                      SizedBox(height: context.altoPct(0.005)),
                      Text(order.notas!,
                          style: TextStyle(fontSize: context.tamTexto(15))),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, String label, String value, ThemeData theme) {
    IconData icon;
    switch (label.toLowerCase()) {
      case 'tela':
        icon = Icons.straighten;
        break;
      case 'color':
        icon = Icons.color_lens;
        break;
      case 'talla':
        icon = Icons.format_size;
        break;
      case 'precio':
        icon = Icons.attach_money;
        break;
      default:
        icon = Icons.info_outline;
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: theme.colorScheme.primary, size: context.tamTexto(18)),
            SizedBox(width: context.anchoPct(0.03)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: context.tamTexto(13))),
                  SizedBox(height: context.altoPct(0.004)),
                  Text(value,
                      style: TextStyle(
                          fontSize: context.tamTexto(16),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.altoPct(0.01)),
        const Divider(height: 1),
        SizedBox(height: context.altoPct(0.01)),
      ],
    );
  }

  Widget _badge(
      BuildContext context, String label, String value, ThemeData theme) {
    final bool positive = value.toLowerCase() == 'sí' ||
        value.toLowerCase() == 'si' ||
        value.toLowerCase() == 'yes';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: context.tamTexto(13))),
        SizedBox(height: context.altoPct(0.005)),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: context.anchoPct(0.03),
              vertical: context.altoPct(0.008)),
          decoration: BoxDecoration(
            color: positive ? theme.colorScheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary),
          ),
          child: Center(
            child: Text(value,
                style: TextStyle(
                    color: positive ? Colors.white : theme.colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
