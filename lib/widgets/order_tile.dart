// lib/widgets/order_tile.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/screen.dart';

class OrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;
  const OrderTile({required this.order, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final imgSize = context.wPct(0.14);
    final titleStyle = Theme.of(context).textTheme.bodyLarge;

    return ListTile(
      onTap: onTap,
      leading: order.imageUrl != null && order.imageUrl!.isNotEmpty
          ? SizedBox(
              width: imgSize,
              height: imgSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(imgSize / 2),
                child: CachedNetworkImage(
                  imageUrl: order.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => CircleAvatar(
                    radius: imgSize / 2,
                    backgroundColor: const Color(0xFF083B3D),
                    child: Text(
                      order.customerName.isNotEmpty
                          ? order.customerName[0].toUpperCase()
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
                order.customerName.isNotEmpty
                    ? order.customerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      title: Text(order.customerName, style: titleStyle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${order.fabric} • ${order.size} • \$${order.price.toStringAsFixed(2)}'),
          if (order.ownerId != null || order.ownerName != null)
            Text('Creado por: ${order.ownerName ?? order.ownerId}',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Icon(
        order.status == 'done' ? Icons.check_circle : Icons.timelapse,
        color: order.status == 'done'
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).primaryColor,
      ),
    );
  }
}
