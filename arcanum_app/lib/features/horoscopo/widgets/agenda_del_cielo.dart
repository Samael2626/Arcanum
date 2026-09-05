/// «Lo que viene»: la agenda del cielo de esta persona, con fechas.
///
/// No es el horóscopo de hoy estirado. Cada línea es un SUCESO con día: el
/// aspecto que perfecciona el jueves, el planeta que cambia de casa el 12, el
/// cumpleaños que estrena señor del año. Lo que dura semanas —el capítulo de
/// fondo— va aparte y sin fecha, porque no ocurre ningún día concreto.
///
/// SOLO SE OFRECEN SEMANA Y MES. El servidor calcula la fecha exacta con la
/// velocidad instantánea del planeta, y más allá de 30 días eso deja de ser
/// una estimación para ser un invento: el motor devuelve nulo y aquí no se
/// enseña un botón de «tres meses» que daría una lista con huecos. El techo
/// llega del servidor en `max_days`; no se escribe a mano en el cliente.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/content/glossary.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';
import '../../../shared/widgets/info_dot.dart';

class AgendaDelCielo extends ConsumerStatefulWidget {
  const AgendaDelCielo({super.key});

  @override
  ConsumerState<AgendaDelCielo> createState() => _AgendaState();
}

class _AgendaState extends ConsumerState<AgendaDelCielo> {
  static const _semana = 7;
  static const _mes = 30;

  int _dias = _semana;
  Map<String, dynamic>? _agenda;
  bool _cargando = false;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    // Se carga sola: es cálculo, no cuesta cupo ni llama al modelo, y una
    // sección que hay que pedir dos veces para ver algo no se mira nunca.
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _fallo = false;
    });
    try {
      final datos = await ref.read(arcanumApiProvider).agenda(days: _dias);
      if (!mounted) return;
      setState(() {
        _agenda = datos;
        _cargando = false;
      });
    } catch (_) {
      // Sin interpolar el error: filtraría URL, estado y trazas.
      if (!mounted) return;
      setState(() {
        _fallo = true;
        _cargando = false;
      });
    }
  }

  void _cambiar(int dias) {
    if (dias == _dias) return;
    setState(() => _dias = dias);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tope = (_agenda?['max_days'] as num?)?.toInt() ?? _mes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 18, bottom: 12),
          color: ArcanumColors.goldMuted.withValues(alpha: 0.28),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'LO QUE VIENE',
                style: ArcanumText.body(
                  10,
                  color: ArcanumColors.ivoryMuted,
                ).copyWith(letterSpacing: 2.2),
              ),
            ),
            _Pestana(
              rotulo: '7 días',
              activa: _dias == _semana,
              onTap: () => _cambiar(_semana),
            ),
            const SizedBox(width: 6),
            _Pestana(
              rotulo: '$tope días',
              activa: _dias != _semana,
              onTap: () => _cambiar(tope),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _cuerpo(tope),
      ],
    );
  }

  Widget _cuerpo(int tope) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: ArcanumColors.goldMuted,
          ),
        ),
      );
    }
    if (_fallo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No se pudo leer la agenda ahora mismo.',
            style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
          ),
          TextButton(
            onPressed: _cargar,
            child: Text(
              'Reintentar',
              style: ArcanumText.body(13, color: ArcanumColors.gold),
            ),
          ),
        ],
      );
    }

    final sucesos = (_agenda?['events'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final fondo = (_agenda?['background'] as Map?)?.cast<String, dynamic>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sucesos.isEmpty)
          Text(
            'Nada señalado en los próximos $_dias días. El cielo puede estar '
            'en calma sobre una carta, y decirlo es la respuesta correcta.',
            style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
          )
        else
          for (final dia in _porDia(sucesos))
            _Dia(fecha: dia.$1, sucesos: dia.$2),
        if (fondo != null) ...[const SizedBox(height: 12), _Fondo(fondo)],
        const SizedBox(height: 10),
        Text(
          'La agenda llega a $tope días: más allá, la fecha exacta no se '
          'puede calcular sin inventarla.',
          style: ArcanumText.body(
            11,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
      ],
    );
  }

  /// Agrupa por día conservando el orden que ya trae el servidor.
  List<(String, List<Map<String, dynamic>>)> _porDia(
    List<Map<String, dynamic>> sucesos,
  ) {
    final fuera = <(String, List<Map<String, dynamic>>)>[];
    for (final s in sucesos) {
      final fecha = s['date'] as String? ?? '';
      if (fuera.isNotEmpty && fuera.last.$1 == fecha) {
        fuera.last.$2.add(s);
      } else {
        fuera.add((fecha, [s]));
      }
    }
    return fuera;
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.fecha, required this.sucesos});

  final String fecha;
  final List<Map<String, dynamic>> sucesos;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fechaCorta(fecha),
          style: ArcanumText.body(12, color: ArcanumColors.gold),
        ),
        const SizedBox(height: 3),
        for (final s in sucesos) _Suceso(s),
      ],
    ),
  );
}

class _Suceso extends StatelessWidget {
  const _Suceso(this.suceso);

  final Map<String, dynamic> suceso;

  @override
  Widget build(BuildContext context) {
    final tipo = suceso['kind'] as String?;
    final (texto, color) = switch (tipo) {
      'aspect_exact' => (_aspecto(), ArcanumColors.ivory),
      'house_ingress' => (_ingreso(), ArcanumColors.ivory),
      'profection_change' => (_anio(), ArcanumColors.goldLight),
      _ => ('', ArcanumColors.ivoryMuted),
    };
    if (texto.isEmpty) return const SizedBox.shrink();

    final ayuda = tipo == 'aspect_exact'
        ? aspectGlossaryKey(suceso['aspect'] as String? ?? '')
        : null;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 3),
      child: InkWell(
        onTap: ayuda == null ? null : () => showGlossarySheet(context, ayuda),
        child: Text('· $texto', style: ArcanumText.body(13, color: color)),
      ),
    );
  }

  /// «Mercurio cuadratura tu Sol, exacto». La palabra «exacto» es el dato: no
  /// se anuncia que el aspecto exista —lleva días—, sino que ese día cierra.
  String _aspecto() {
    final t = pointEs(suceso['transit'] as String?);
    final n = pointEs(suceso['natal'] as String?);
    final asp = aspectEs[suceso['aspect'] as String?] ?? '';
    if (t.isEmpty || n.isEmpty || asp.isEmpty) return '';
    return '$t $asp tu $n, exacto';
  }

  String _ingreso() {
    final t = pointEs(suceso['transit'] as String?);
    final casa = (suceso['to_house'] as num?)?.toInt();
    if (t.isEmpty || casa == null) return '';
    final vuelve = suceso['retrograde'] == true;
    return vuelve
        ? '$t vuelve a tu casa $casa, retrógrado'
        : '$t entra en tu casa $casa';
  }

  String _anio() {
    final senor = pointEs(suceso['lord'] as String?);
    final casa = (suceso['house'] as num?)?.toInt();
    final edad = (suceso['age'] as num?)?.toInt();
    if (senor.isEmpty || casa == null) return '';
    final cumple = edad == null ? '' : 'Cumples $edad: ';
    return '${cumple}empieza tu año de casa $casa, manda $senor';
  }
}

/// El capítulo que sostiene el periodo. Va SIN fecha a propósito: lleva
/// semanas ahí y no ocurre ningún día, así que anunciarlo como suceso sería
/// convertir en noticia lo que no ha cambiado.
class _Fondo extends StatelessWidget {
  const _Fondo(this.fondo);

  final Map<String, dynamic> fondo;

  @override
  Widget build(BuildContext context) {
    final t = pointEs(fondo['transit'] as String?);
    final n = pointEs(fondo['natal'] as String?);
    final asp = aspectEs[fondo['aspect'] as String?] ?? '';
    if (t.isEmpty || n.isEmpty || asp.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: ArcanumColors.surfaceHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DE FONDO, TODO EL PERIODO',
            style: ArcanumText.body(
              9,
              color: ArcanumColors.ivoryMuted,
            ).copyWith(letterSpacing: 1.8),
          ),
          const SizedBox(height: 3),
          Text('$t $asp tu $n', style: ArcanumText.body(13)),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.rotulo,
    required this.activa,
    required this.onTap,
  });

  final String rotulo;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activa
              ? ArcanumColors.gold
              : ArcanumColors.goldMuted.withValues(alpha: 0.4),
        ),
        color: activa
            ? ArcanumColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
      ),
      child: Text(
        rotulo,
        style: ArcanumText.body(
          12,
          color: activa ? ArcanumColors.goldLight : ArcanumColors.ivoryMuted,
        ),
      ),
    ),
  );
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// «hoy», «mañana» o «12 de septiembre». Los dos primeros días tienen nombre
/// antes que fecha para quien mira una agenda.
String fechaCorta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final ahora = DateTime.now();
  final dias = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Mañana';
  return '${d.day} de ${_meses[d.month - 1]}';
}
