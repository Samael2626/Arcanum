import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/arcanum_field.dart';
import '../../shared/widgets/gold_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
      if (mounted) context.go('/cielos');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted),
          onPressed: () => context.go('/hoy'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const ArcanumHeader(subtitle: 'Cruza el umbral'),
                const SizedBox(height: 32),
                ArcanumField(controller: _email, label: 'Correo', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 18),
                ArcanumField(controller: _password, label: 'Contraseña', obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: ArcanumText.body(14, color: ArcanumColors.error)),
                ],
                const SizedBox(height: 28),
                GoldButton(label: 'Entrar', loading: _loading, onPressed: _submit),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text('¿Aún no tienes cuenta? Regístrate',
                      style: ArcanumText.body(14, color: ArcanumColors.gold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
