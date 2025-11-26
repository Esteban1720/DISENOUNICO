import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/servicio_pedidos.dart';
import '../utilidades/pantalla.dart';
import '../servicios/servicio_autenticacion.dart';

class OrderFormScreen extends StatefulWidget {
  final String? orderId;
  const OrderFormScreen({this.orderId, super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _fabricCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  File? _previewImageFile;
  bool _isReadOnly = false;
  bool _canSave = false;

  @override
  void dispose() {
    _customerCtrl.removeListener(_updateCanSave);
    _fabricCtrl.removeListener(_updateCanSave);
    _colorCtrl.removeListener(_updateCanSave);
    _sizeCtrl.removeListener(_updateCanSave);
    _priceCtrl.removeListener(_updateCanSave);
    _notesCtrl.removeListener(_updateCanSave);

    _customerCtrl.dispose();
    _fabricCtrl.dispose();
    _colorCtrl.dispose();
    _sizeCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _customerCtrl.addListener(_updateCanSave);
    _fabricCtrl.addListener(_updateCanSave);
    _colorCtrl.addListener(_updateCanSave);
    _sizeCtrl.addListener(_updateCanSave);
    _priceCtrl.addListener(_updateCanSave);
    _notesCtrl.addListener(_updateCanSave);

    if (widget.orderId != null) {
      _loadOrder(widget.orderId!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateCanSave());
    }
  }

  Future<void> _loadOrder(String orderId) async {
    final service = Provider.of<ServicioPedidos>(context, listen: false);
    try {
      final doc = await service.obtenerDocPedido(orderId);
      if (!doc.exists) return;
      final map = doc.data() as Map<String, dynamic>;
      setState(() {
        _customerCtrl.text = map['customerName'] ?? '';
        _fabricCtrl.text = map['fabric'] ?? '';
        _colorCtrl.text = map['color'] ?? '';
        _sizeCtrl.text = map['size'] ?? '';
        _priceCtrl.text = (map['price'] ?? '').toString();
        _notesCtrl.text = map['notes'] ?? '';
        final isDone = (map['status'] == 'done') || (map['paid'] == true);
        _isReadOnly = isDone;
      });
      _updateCanSave();
    } catch (e) {
      debugPrint('Failed to load order $orderId: $e');
    }
  }

  Future<void> _pickPreviewImage() async {
    if (_isReadOnly) return;
    final service = Provider.of<ServicioPedidos>(context, listen: false);
    final file = await service.pickLocalImage();
    if (file != null) {
      setState(() {
        _previewImageFile = file;
        _updateCanSave();
      });
    }
  }

  void _updateCanSave() {
    if (_isReadOnly || _saving) {
      if (_canSave) setState(() => _canSave = false);
      return;
    }
    final customerOk = _customerCtrl.text.trim().isNotEmpty;
    final fabricOk = _fabricCtrl.text.trim().isNotEmpty;
    final colorOk = _colorCtrl.text.trim().isNotEmpty;
    final sizeOk = _sizeCtrl.text.trim().isNotEmpty;
    final notesOk = _notesCtrl.text.trim().isNotEmpty;
    final priceOk = _isPriceValid(_priceCtrl.text.trim());

    final shouldEnable =
        customerOk && fabricOk && colorOk && sizeOk && notesOk && priceOk;
    if (shouldEnable != _canSave) setState(() => _canSave = shouldEnable);
  }

  bool _isPriceValid(String text) {
    if (text.isEmpty) return false;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return false;
    return value > 0;
  }

  Future<void> _save() async {
    if (_isReadOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('No se puede editar un pedido que ya está realizado')));
      }
      return;
    }

    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Por favor completa todos los campos correctamente.')));
      }
      return;
    }

    setState(() => _saving = true);
    _updateCanSave();

    final ordersService = Provider.of<ServicioPedidos>(context, listen: false);
    final auth = Provider.of<ServicioAutenticacion>(context, listen: false);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario no autenticado')));
      }
      setState(() => _saving = false);
      _updateCanSave();
      return;
    }

    final data = <String, dynamic>{
      'customerName': _customerCtrl.text.trim(),
      'fabric': _fabricCtrl.text.trim(),
      'color': _colorCtrl.text.trim(),
      'size': _sizeCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
      'status': 'pending',
      'paid': false,
      'notes': _notesCtrl.text.trim(),
    };

    try {
      if (widget.orderId != null) {
        await ordersService.actualizarPedido(widget.orderId!, data);
        if (_previewImageFile != null) {
          final imageUrl =
              await ordersService.uploadToCloudinary(_previewImageFile!);
          if (imageUrl != null) {
            await ordersService
                .actualizarPedido(widget.orderId!, {'imageUrl': imageUrl});
          }
        }
      } else {
        data['ownerUid'] = currentUid;
        data['ownerId'] = currentUid;
        data['ownerName'] = auth.username ?? auth.displayName ?? '';

        if (_previewImageFile != null) {
          final orderId = await ordersService.crearPedido({...data});
          final imageUrl =
              await ordersService.uploadToCloudinary(_previewImageFile!);
          if (imageUrl != null) {
            await ordersService
                .actualizarPedido(orderId, {'imageUrl': imageUrl});
          }
        } else {
          await ordersService.crearPedido({...data});
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _updateCanSave();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidePad = context.anchoPct(0.04);
    final previewHeight = context.altoPct(0.28);
    final btnHeight = context.altoPct(0.065);

    const mainColor = Color(0xFF083B3D);

    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.orderId != null ? 'Editar pedido' : 'Nuevo pedido')),
      body: Padding(
        padding: EdgeInsets.all(sidePad),
        child: Card(
          color: mainColor,
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(sidePad),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_isReadOnly)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.altoPct(0.01)),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 18, color: Colors.white),
                          SizedBox(width: context.anchoPct(0.02)),
                          Expanded(
                              child: Text(
                            'Este pedido está realizado — solo se permite eliminarlo.',
                            style: TextStyle(
                                fontSize: context.tamTexto(12),
                                color: Colors.white),
                          )),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(context.anchoPct(0.04)),
                    child: Column(
                      children: [
                        _buildTextField(_customerCtrl, 'Nombre del cliente'),
                        SizedBox(height: context.altoPct(0.012)),
                        _buildTextField(_fabricCtrl, 'Tela'),
                        SizedBox(height: context.altoPct(0.012)),
                        _buildTextField(_colorCtrl, 'Color'),
                        SizedBox(height: context.altoPct(0.012)),
                        _buildTextField(_sizeCtrl, 'Talla'),
                        SizedBox(height: context.altoPct(0.012)),
                        _buildTextField(_priceCtrl, 'Precio', isNumber: true),
                        SizedBox(height: context.altoPct(0.012)),
                        _buildTextField(_notesCtrl, 'Notas', maxLines: 3),
                      ],
                    ),
                  ),
                  SizedBox(height: context.altoPct(0.02)),
                  if (_previewImageFile != null) ...[
                    SizedBox(
                        height: previewHeight,
                        child:
                            Image.file(_previewImageFile!, fit: BoxFit.cover)),
                    SizedBox(height: context.altoPct(0.01)),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isReadOnly ? null : _pickPreviewImage,
                          icon: const Icon(Icons.photo, color: Colors.white),
                          label: const Text('Seleccionar imagen',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            minimumSize: Size.fromHeight(btnHeight),
                          ),
                        ),
                      ),
                      SizedBox(width: context.anchoPct(0.03)),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isReadOnly
                              ? null
                              : () async {
                                  final service = Provider.of<ServicioPedidos>(
                                      context,
                                      listen: false);
                                  final file = await service.pickLocalImage(
                                      source: ImageSource.camera);
                                  if (file != null) {
                                    setState(() {
                                      _previewImageFile = file;
                                      _updateCanSave();
                                    });
                                  }
                                },
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text('Tomar foto',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            minimumSize: Size.fromHeight(btnHeight),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.altoPct(0.02)),
                  SizedBox(
                    width: double.infinity,
                    height: btnHeight,
                    child: ElevatedButton(
                      onPressed:
                          (_saving || _isReadOnly || !_canSave) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const CircularProgressIndicator.adaptive()
                          : const Text('Guardar pedido',
                              style: TextStyle(color: mainColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {bool isNumber = false, int maxLines = 1}) {
    const mainColor = Color(0xFF083B3D);
    return TextFormField(
      controller: ctrl,
      readOnly: _isReadOnly,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: mainColor),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: mainColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: mainColor),
        ),
      ),
      style: const TextStyle(color: mainColor),
      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
    );
  }
}
