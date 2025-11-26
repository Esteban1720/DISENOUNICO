// lib/componentes/ficha_pedido.dart
import 'package:flutter/material.dart';
import '../modelos/pedido.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utilidades/pantalla.dart';

class FichaPedido extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback? onTap;
  const FichaPedido({required this.pedido, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final imgSize = context.anchoPct(0.14);
    final titleStyle = Theme.of(context).textTheme.bodyLarge;

    return ListTile(
      onTap: onTap,
      leading: pedido.imagenUrl != null && pedido.imagenUrl!.isNotEmpty
          ? SizedBox(
              width: imgSize,
              height: imgSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(imgSize / 2),
                child: CachedNetworkImage(
                  imageUrl: pedido.imagenUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => CircleAvatar(
                    radius: imgSize / 2,
                    backgroundColor: const Color(0xFF083B3D),
                    child: Text(
                      pedido.nombreCliente.isNotEmpty
                          ? pedido.nombreCliente[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : CircleAvatar(
              radius: imgSize / 2,
              backgroundColor: const Color(0xFF083B3D),
              child: Text(
                pedido.nombreCliente.isNotEmpty
                    ? pedido.nombreCliente[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      title: Text(pedido.nombreCliente, style: titleStyle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${pedido.tela} • ${pedido.talla} • \$${pedido.precio.toStringAsFixed(2)}'),
          if (pedido.propietarioId != null || pedido.propietarioNombre != null)
            Text(
                'Creado por: ${pedido.propietarioNombre ?? pedido.propietarioId}',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Icon(
        pedido.estado == 'done' ? Icons.check_circle : Icons.timelapse,
        color: pedido.estado == 'done'
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).primaryColor,
      ),
    );
  }
}
