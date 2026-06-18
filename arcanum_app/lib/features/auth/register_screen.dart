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
  final _name = TextEditingController();
  final _lat = TextEditingController(text: '4.71');
  final _lon = TextEditingController(text: '-74.07');
  final _tz = TextEditingController(text: 'America/Bogota');
  final _dateField = TextEditingController();
  final _timeField = TextEditingController();
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _loading = false;
  String? _error;

  static String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _birthDate = d;
        _dateField.text = '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (t != null) {
      setState(() {
        _birthTime = t;
        _timeField.text = '${_pad(t.hour)}:${_pad(t.minute)}';
      });
    }
  }

  Future<void> _submit() async {
    if (_birthDate == null || _birthTime == null) {
      setState(() => _error = 'Indica fecha y hora de nacimiento');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = _birthDate!;
    final t = _birthTime!;
    try {
      await ref.read(authProvider.notifier).register(RegisterData(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            birthDate: '${d.year}-${_pad(d.month)}-${_pad(d.day)}T00:00:00',
            birthTime: '2000-01-01T${_pad(t.hour)}:${_pad(t.minute)}:00',
            birthLat: _lat.text.trim(),
            birthLon: _lon.text.trim(),
            birthTimezone: _tz.text.trim(),
          ));
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
                const SizedBox(height: 16),
                ArcanumField(controller: _name, label: 'Nombre (opcional)'),
                const SizedBox(height: 24),
                const SectionLabel('DATOS DE NACIMIENTO'),
                const SizedBox(height: 8),
                ArcanumField(controller: _dateField, label: 'Fecha', readOnly: true, onTap: _pickDate),
                const SizedBox(height: 16),
                ArcanumField(controller: _timeField, label: 'Hora', readOnly: true, onTap: _pickTime),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: ArcanumField(controller: _lat, label: 'Latitud', keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: ArcanumField(controller: _lon, label: 'Longitud', keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                ArcanumField(controller: _tz, label: 'Zona horaria (IANA)'),
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
