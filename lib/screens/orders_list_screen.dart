import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/orders_service.dart';
import '../services/auth_service.dart';
import '../models/order.dart';
import '../widgets/order_tile.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';
import 'profile_screen.dart';
import '../utils/screen.dart';
import '../theme.dart'; // Importa tu tema global

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _statusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    final ordersService = Provider.of<OrdersService>(context, listen: false);
    final auth = Provider.of<AuthService>(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ownerId = auth.username ?? uid;
    final padding = context.wPct(0.03);
    final theme = Theme.of(context);

    final contact =
        FirebaseAuth.instance.currentUser?.email ?? auth.username ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diseño Único'),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: context.hPct(0.02),
        ),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: EdgeInsets.all(context.wPct(0.04)),
                child: Row(
                  children: [
                    finalAvatar(context, auth),
                    SizedBox(width: context.wPct(0.04)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName ?? (auth.username ?? '—'),
                            style: TextStyle(
                              fontSize: context.sp(24),
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: context.hPct(0.006)),
                          Text(
                            auth.username ?? contact,
                            style: TextStyle(
                              fontSize: context.sp(16),
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            Size(context.wPct(0.15), context.hPct(0.075)),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.wPct(0.015),
                          vertical: context.hPct(0.008),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.person_outline, size: 22),
                      label: Text('Editar',
                          style: TextStyle(fontSize: context.sp(14))),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.hPct(0.02)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Pendientes'),
                  selected: _statusFilter == 'pending',
                  onSelected: (_) => setState(() => _statusFilter = 'pending'),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: fieldFill,
                  labelStyle: TextStyle(
                    color: _statusFilter == 'pending'
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: context.wPct(0.03)),
                ChoiceChip(
                  label: const Text('Realizados'),
                  selected: _statusFilter == 'done',
                  onSelected: (_) => setState(() => _statusFilter = 'done'),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: fieldFill,
                  labelStyle: TextStyle(
                    color: _statusFilter == 'done'
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.hPct(0.02)),
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: ordersService.ordersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar pedidos: ${snapshot.error}'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = snapshot.data ?? [];

                  List<OrderModel> visible = orders.where((o) {
                    final isDone = (o.status == 'done') || (o.paid == true);
                    if (_statusFilter == 'done') return isDone;
                    return !isDone;
                  }).toList();

                  if (visible.isEmpty) {
                    return const Center(child: Text('No hay pedidos aún'));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(
                      top: context.hPct(0.01),
                      bottom: context.hPct(0.02),
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final o = visible[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.hPct(0.009),
                        ),
                        child: Dismissible(
                          key: ValueKey(o.id),
                          background: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: context.wPct(0.04)),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            final isDone =
                                (o.status == 'done') || (o.paid == true);
                            if (isDone) return false;

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Marcar como realizado'),
                                content: const Text(
                                    '¿Deseas marcar este pedido como realizado?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Sí')),
                                ],
                              ),
                            );
                            if (confirm ?? false) {
                              try {
                                await ordersService.markAsDone(o.id);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                            return confirm ?? false;
                          },
                          child: OrderTile(
                            order: o,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: o),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrderFormScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget finalAvatar(BuildContext context, AuthService auth) {
    final avatarSize = context.minPct(0.22);
    final initials = (auth.displayName ?? '')
        .split(' ')
        .map((e) => e.isEmpty ? '' : e[0])
        .take(2)
        .join();

    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: auth.photoUrl != null
            ? CachedNetworkImage(
                imageUrl: auth.photoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: fieldFill,
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: context.sp(18),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                color: fieldFill,
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: context.sp(18),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
