import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../servicios/servicio_pedidos.dart';
import '../servicios/servicio_autenticacion.dart';
import '../modelos/pedido.dart';
import '../componentes/ficha_pedido.dart';
import 'pantalla_formulario_pedido.dart';
import 'pantalla_detalle_pedido.dart';
import 'pantalla_perfil.dart';
import '../utilidades/pantalla.dart';
import '../theme.dart'; // Importa tu tema global

class PantallaListaPedidos extends StatefulWidget {
  const PantallaListaPedidos({super.key});

  @override
  State<PantallaListaPedidos> createState() => _PantallaListaPedidosState();
}

class _PantallaListaPedidosState extends State<PantallaListaPedidos> {
  String _statusFilter = 'pending';

  late TextEditingController _camisaCtrl;
  late TextEditingController _busoCtrl;

  static const _kKeyCamisa = 'precios_camisa';
  static const _kKeyBuso = 'precios_buso';

  static const _defaultCamisa = '''PRECIOS DE CAMISA
ALGODÓN 50
REGULAR FIT ORIGINAL 65
REGULAR FIT SEMI 60
TELA FRÍA ORIGINAL 65
OVERZIDE REGULAR FIT ORIGINAL 80
OVERZIDE SENCILLA 70
POLO 55''';

  static const _defaultBuso = '''PRECIOS DE BUSOS
BUSO SIN CAPUCHA 80.000
BUSO CON CAPUCHA 90.000''';

  @override
  void initState() {
    super.initState();
    _camisaCtrl = TextEditingController();
    _busoCtrl = TextEditingController();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final sp = await SharedPreferences.getInstance();
    final camisa = sp.getString(_kKeyCamisa) ?? _defaultCamisa;
    final buso = sp.getString(_kKeyBuso) ?? _defaultBuso;
    if (!mounted) return;
    setState(() {
      _camisaCtrl.text = camisa;
      _busoCtrl.text = buso;
    });
  }

  Future<void> _savePrices() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKeyCamisa, _camisaCtrl.text);
    await sp.setString(_kKeyBuso, _busoCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Precios guardados')));
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
  }

  @override
  Widget build(BuildContext context) {
    final ordersService = Provider.of<ServicioPedidos>(context, listen: false);
    final auth = Provider.of<ServicioAutenticacion>(context);

    final padding = context.anchoPct(0.03);
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
              final authSvc =
                  Provider.of<ServicioAutenticacion>(context, listen: false);
              await authSvc.logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: context.altoPct(0.02),
        ),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: EdgeInsets.all(context.anchoPct(0.04)),
                child: Row(
                  children: [
                    finalAvatar(context, auth),
                    SizedBox(width: context.anchoPct(0.04)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName ?? (auth.username ?? '—'),
                            style: TextStyle(
                              fontSize: context.tamTexto(24),
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: context.altoPct(0.006)),
                          Text(
                            auth.username ?? contact,
                            style: TextStyle(
                              fontSize: context.tamTexto(16),
                              color: const Color.fromRGBO(8, 59, 61, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                            context.anchoPct(0.15), context.altoPct(0.075)),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.anchoPct(0.015),
                          vertical: context.altoPct(0.008),
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
                          style: TextStyle(fontSize: context.tamTexto(14))),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PantallaPerfil()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.altoPct(0.02)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: context.anchoPct(0.03),
              runSpacing: context.altoPct(0.01),
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
                ChoiceChip(
                  label: const Text('Tabla de precios'),
                  selected: _statusFilter == 'prices',
                  onSelected: (_) => setState(() => _statusFilter = 'prices'),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: fieldFill,
                  labelStyle: TextStyle(
                    color: _statusFilter == 'prices'
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.altoPct(0.02)),
            Expanded(
              child: _statusFilter == 'prices'
                  ? _buildPriceTables(context)
                  : StreamBuilder<List<Pedido>>(
                      stream: ordersService.flujoPedidos(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                                'Error al cargar pedidos: ${snapshot.error}'),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final orders = snapshot.data ?? [];

                        List<Pedido> visible = orders.where((o) {
                          final isDone =
                              (o.estado == 'done') || (o.pagado == true);
                          if (_statusFilter == 'done') return isDone;
                          return !isDone;
                        }).toList();

                        if (visible.isEmpty) {
                          return const Center(
                              child: Text('No hay pedidos aún'));
                        }

                        return ListView.builder(
                          padding: EdgeInsets.only(
                            top: context.altoPct(0.01),
                            bottom: context.altoPct(0.02),
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final o = visible[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: context.altoPct(0.009),
                              ),
                              child: Dismissible(
                                key: ValueKey(o.id),
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: EdgeInsets.only(
                                      left: context.anchoPct(0.04)),
                                  child: const Icon(Icons.check,
                                      color: Colors.white),
                                ),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  final isDone = (o.estado == 'done') ||
                                      (o.pagado == true);
                                  if (isDone) return false;

                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title:
                                          const Text('Marcar como realizado'),
                                      content: const Text(
                                          '¿Deseas marcar este pedido como realizado?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, false),
                                            child: const Text('Cancelar')),
                                        TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, true),
                                            child: const Text('Sí')),
                                      ],
                                    ),
                                  );
                                  if (confirm ?? false) {
                                    try {
                                      await ordersService.markAsDone(o.id);
                                      if (mounted) {
                                        messenger.showSnackBar(const SnackBar(
                                            content: Text(
                                                'Pedido marcado como realizado')));
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        messenger.showSnackBar(SnackBar(
                                            content: Text('Error: $e')));
                                      }
                                    }
                                  }
                                  return confirm ?? false;
                                },
                                child: FichaPedido(
                                  pedido: o,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PantallaDetallePedido(order: o)),
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
          MaterialPageRoute(builder: (_) => const PantallaFormularioPedido()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPriceTables(BuildContext context) {
    final sidePad = context.anchoPct(0.04);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: context.altoPct(0.01)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(sidePad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('PRECIOS DE CAMISA',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.tamTexto(16),
                                  color: theme.colorScheme.primary)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                tooltip: 'Copiar',
                                onPressed: () =>
                                    _copyToClipboard(_camisaCtrl.text),
                                icon: Icon(Icons.copy,
                                    color: theme.colorScheme.primary)),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white),
                                onPressed: _savePrices,
                                child: const Text('Guardar')),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _camisaCtrl,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: context.altoPct(0.02)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(sidePad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('PRECIOS DE BUSOS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.tamTexto(16),
                                  color: theme.colorScheme.primary)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                tooltip: 'Copiar',
                                onPressed: () =>
                                    _copyToClipboard(_busoCtrl.text),
                                icon: Icon(Icons.copy,
                                    color: theme.colorScheme.primary)),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white),
                                onPressed: _savePrices,
                                child: const Text('Guardar')),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _busoCtrl,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: context.altoPct(0.04)),
        ],
      ),
    );
  }

  Widget finalAvatar(BuildContext context, ServicioAutenticacion auth) {
    final avatarSize = context.minimoPct(0.22);
    final initials = (auth.displayName ?? '')
        .split(' ')
        .map((e) => e.isEmpty ? '' : e[0])
        .take(2)
        .join();

    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, auth.photoUrl, initials),
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
                          fontSize: context.tamTexto(18),
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
                        fontSize: context.tamTexto(18),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showFullScreenImage(
      BuildContext context, String? url, String initials) async {
    await showDialog(
        context: context,
        builder: (ctx) {
          return GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              color: Colors.black,
              child: Center(
                child: url != null
                    ? InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 48)),
                          ),
                        ),
                      )
                    : Text(initials,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 48)),
              ),
            ),
          );
        });
  }
}
