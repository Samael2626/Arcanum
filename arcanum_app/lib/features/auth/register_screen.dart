import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/arcanum_field.dart';
import '../../shared/widgets/gold_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 8) {
      setState(() => _error = 'Correo válido y contraseña de mínimo 8 caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).register(RegisterData(
            email: email,
            password: password,
          ));
      // Datos natales se capturan en el onboarding (no se duplican aquí).
      if (mounted) context.go('/onboarding');
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
          icon: const Icon(Icons.arrow_back, color: ArcanumColors.ivoryMuted),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const ArcanumHeader(subtitle: 'Inscríbete en el grimorio'),
                const SizedBox(height: 28),
                ArcanumField(controller: _email, label: 'Correo', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                ArcanumField(controller: _password, label: 'Contraseña (mín. 8)', obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: ArcanumText.body(14, color: ArcanumColors.error)),
                ],
                const SizedBox(height: 28),
                GoldButton(label: 'Crear cuenta', loading: _loading, onPressed: _submit),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Ya tengo cuenta', style: ArcanumText.body(14, color: ArcanumColors.gold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
