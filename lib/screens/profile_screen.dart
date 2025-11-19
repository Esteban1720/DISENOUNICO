// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/orders_service.dart';
import '../utils/screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _saving = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _nameCtrl = TextEditingController(text: auth.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final ordersService = Provider.of<OrdersService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() => _saving = true);
    try {
      final file = await ordersService.pickLocalImage();
      if (file == null) return;
      final url = await ordersService.uploadToCloudinary(file);
      if (!mounted) return;
      if (url != null) {
        await auth.setPhotoUrl(url);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Foto actualizada')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la foto')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveName() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final name = _nameCtrl.text.trim();
    await auth.setDisplayName(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Nombre guardado')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final avatarRadius = context.minPct(0.45) / 2;
    final padding = context.wPct(0.06);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                        radius: avatarRadius,
                        backgroundImage: auth.photoUrl != null
                            ? NetworkImage(auth.photoUrl!)
                            : null,
                        child: auth.photoUrl == null
                            ? Text(
                                (auth.displayName ?? '')
                                    .split(' ')
                                    .map((e) => e.isEmpty ? '' : e[0])
                                    .take(2)
                                    .join(),
                                style: TextStyle(
                                    fontSize: avatarRadius * 0.6,
                                    color: Colors.white))
                            : null,
                        backgroundColor: const Color(0xFF083B3D)),
                    SizedBox(height: context.hPct(0.03)),
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF083B3D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.camera_alt),
                        label: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Cambiar foto'),
                        onPressed: _saving ? null : _pickAndUpload),
                    SizedBox(height: context.hPct(0.03)),

                    // Etiqueta fuera del TextField
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Nombre a mostrar',
                        style: const TextStyle(
                          color: Color(0xFF083B3D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: context.hPct(0.01)),

                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF083B3D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),

                    SizedBox(height: context.hPct(0.02)),
                    Row(children: [
                      Expanded(
                          child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF083B3D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              onPressed: _saveName,
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar')))
                    ]),
                    SizedBox(height: context.hPct(0.02)),
                    Text('Usuario: ${auth.username ?? '—'}',
                        style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
