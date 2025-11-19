// lib/screens/login_screen.dart
// Versión: logo más grande y desplazado un poquito hacia arriba.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  String? _error;

  // Colores reutilizables (inspirados en tu logo)
  static const Color _accentTeal = Color(0xFF083B3D);
  static const Color _scaffoldPink = Color(0xFFF6E8EA);
  static const Color _fieldFill = Color(0xFF083B3D);
  static const Color _buttonFill = Color(0xFF083B3D);

  @override
  void initState() {
    super.initState();
    _userFocus.addListener(() {
      if (_userFocus.hasFocus) _ensureVisibleFor(_userFocus);
    });
    _passFocus.addListener(() {
      if (_passFocus.hasFocus) _ensureVisibleFor(_passFocus);
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureVisibleFor(FocusNode node) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final ctx = node.context;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.25);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text.trim());

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ok ? null : 'Usuario o contraseña incorrectos';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error al iniciar sesión';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;

    // Tamaños responsivos ajustados para logo más grande
    final logoPct = keyboardOpen ? 0.18 : 0.40;
    final baseLogoSize = context.minPct(logoPct);
    // Multiplicador mayor para que el logo sea más grande
    final logoSize = math.min(baseLogoSize * 4.2, mq.size.height * 0.42);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _scaffoldPink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: context.wPct(0.06),
              right: context.wPct(0.06),
              top: context.hPct(0.03),
              bottom: bottomInset + context.hPct(0.03),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(540, mq.size.width * 0.95),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo más grande y desplazado un poco hacia arriba.
                  Transform.translate(
                    offset: Offset(0, -context.hPct(0.03)),
                    child: SizedBox(
                      height: logoSize,
                      child: Image.asset(
                        'assets/login.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo Diseño Único',
                      ),
                    ),
                  ),

                  SizedBox(height: context.hPct(0.01)),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 10),
                          blurRadius: 24,
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 20),
                    child: _LoginForm(
                      formKey: _formKey,
                      userCtrl: _userCtrl,
                      passCtrl: _passCtrl,
                      userFocus: _userFocus,
                      passFocus: _passFocus,
                      loading: _loading,
                      onSubmit: _submit,
                      error: _error,
                      fieldFill: _fieldFill,
                      accentTeal: _accentTeal,
                      buttonFill: _buttonFill,
                    ),
                  ),

                  SizedBox(height: context.hPct(0.03)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final FocusNode userFocus;
  final FocusNode passFocus;
  final bool loading;
  final VoidCallback onSubmit;
  final String? error;
  final Color fieldFill;
  final Color accentTeal;
  final Color buttonFill;

  const _LoginForm({
    required this.formKey,
    required this.userCtrl,
    required this.passCtrl,
    required this.userFocus,
    required this.passFocus,
    required this.loading,
    required this.onSubmit,
    required this.error,
    required this.fieldFill,
    required this.accentTeal,
    required this.buttonFill,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: context.sp(14),
      fontWeight: FontWeight.w600,
      color: accentTeal,
    );

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white, width: 1.0),
      ),
      focusColor: Colors.white,
    );

    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Gestiona tus pedidos',
                  style: TextStyle(
                    fontSize: context.sp(18),
                    fontWeight: FontWeight.w700,
                    color: accentTeal,
                  )),
            ),
            const SizedBox(height: 12),
            Text('Usuario', style: labelStyle),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextFormField(
                controller: userCtrl,
                focusNode: userFocus,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                keyboardType: TextInputType.text,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration.copyWith(
                  hintText: 'ingrese su usuario',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  return null;
                },
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(passFocus),
              ),
            ),
            SizedBox(height: context.hPct(0.03)),
            Text('Contraseña', style: labelStyle),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextFormField(
                controller: passCtrl,
                focusNode: passFocus,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration.copyWith(
                  hintText: 'ingrese su contraseña',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ),
            SizedBox(height: context.hPct(0.04)),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonFill,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 6,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('INICIAR SESIÓN',
                        style: TextStyle(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        )),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
