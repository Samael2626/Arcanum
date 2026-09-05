/// Los días anteriores: el archivo de horóscopos de esta persona.
///
/// NO se pide al abrir la pantalla. El horóscopo de hoy es lo que se viene a
/// leer; el historial es una segunda intención, y cargarlo de oficio sería una
/// llamada de red por cada apertura para algo que casi nadie mira a diario.
///
/// TOLERA LECTURAS VIEJAS. El archivo guarda el cielo tal como se calculó
/// aquel día, y el motor ha ido aprendiendo cosas —el año profectado, los
/// ingresos por casa— que las lecturas anteriores no traen. Aquí se pinta lo
/// que haya: nunca se rellena un hueco con un valor de hoy, porque parecería
/// calculado entonces y no lo fue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';

class HistorialHoroscopo extends ConsumerStatefulWidget {
  const HistorialHoroscopo({super.key});

  @override
  ConsumerState<HistorialHoroscopo> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<HistorialHoroscopo> {
  // Estado explícito y no un `FutureBuilder`: el future que falla nace dentro
  // de `setState` y, hasta que el builder se suscribe, nadie lo escucha — el
  // framework lo da por error no atendido y tumba el test aunque la pantalla
  // pintase bien. Lo cazó `historial_horoscopo_test`.
  List<Map<String, dynamic>>? _dias;
  bool _cargando = false;
  bool _fallo = false;

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _fallo = false;
    });
    try {
      final dias = await ref.read(arcanumApiProvider).horoscopeHistory();
      if (!mounted) return;
      setState(() {
        _dias = dias;
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

  @override
  Widget build(BuildContext context) {
    if (_dias == null && !_cargando && !_fallo) {
      return _Filete(
        child: TextButton(
          onPressed: _cargar,
          child: Text(
            'Ver días anteriores',
            style: ArcanumText.body(13, color: ArcanumColors.gold),
          ),
        ),
      );
    }

    if (_cargando) {
      return const _Filete(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: ArcanumColors.goldMuted,
            ),
          ),
        ),
      );
    }

    if (_fallo) {
      return _Filete(
        child: _Aviso(
          texto: 'No se pudo leer tu archivo ahora mismo.',
          accion: 'Reintentar',
          onTap: _cargar,
        ),
      );
    }

    final dias = _dias ?? const <Map<String, dynamic>>[];
    if (dias.isEmpty) {
      // El archivo empieza hoy: no se rellenó hacia atrás con lecturas
      // reconstruidas, que serían textos que esta persona nunca leyó.
      return const _Filete(
        child: _Aviso(
          texto:
              'Todavía no hay días guardados. El de hoy se archiva en '
              'cuanto abras el sello.',
        ),
      );
    }

    return _Filete(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DÍAS ANTERIORES',
            style: ArcanumText.body(
              10,
              color: ArcanumColors.ivoryMuted,
            ).copyWith(letterSpacing: 2.2),
          ),
          const SizedBox(height: 4),
          for (final dia in dias) _DiaArchivado(dia),
        ],
      ),
    );
  }
}

/// Un día del archivo, plegado. Se abre el que se quiera releer.
class _DiaArchivado extends StatelessWidget {
  const _DiaArchivado(this.dia);

  final Map<String, dynamic> dia;

  @override
  Widget build(BuildContext context) {
    final sky = (dia['sky'] as Map?)?.cast<String, dynamic>() ?? const {};
    final titular = _titular(sky);
    return Theme(
      // El divisor propio del ExpansionTile duplicaría el filete de la sección.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        iconColor: ArcanumColors.goldMuted,
        collapsedIconColor: ArcanumColors.goldMuted,
        title: Text(
          _fechaLarga(dia['date'] as String?),
          style: ArcanumText.body(14, color: ArcanumColors.goldLight),
        ),
        subtitle: titular == null
            ? null
            : Text(
                titular,
                style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
              ),
        children: [
          Text(
            (dia['text'] as String?)?.trim() ?? '',
            style: ArcanumText.body(14),
          ),
        ],
      ),
    );
  }

  /// «Luna trígono Medio Cielo», si aquel día se guardó con esa información.
  ///
  /// Devuelve null cuando no la hay, y entonces la fila enseña solo la fecha:
  /// una lectura de las primeras es una lectura completa aunque su cielo
  /// viniera con menos campos.
  static String? _titular(Map<String, dynamic> sky) {
    final a =
        (sky['today'] as Map?)?.cast<String, dynamic>() ??
        (sky['chapter'] as Map?)?.cast<String, dynamic>();
    if (a == null) return null;
    final t = pointEs(a['transit'] as String?);
    final n = pointEs(a['natal'] as String?);
    final asp = aspectEs[a['aspect'] as String?];
    if (t.isEmpty || n.isEmpty || asp == null) return null;
    return '$t $asp $n';
  }
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

/// «4 de septiembre», y «hoy» o «ayer» cuando toca: quien mira su archivo
/// busca un día que vivió, y esos dos tienen nombre antes que fecha.
String _fechaLarga(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return iso ?? '';
  final hoy = DateTime.now();
  final dias = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  return '${d.day} de ${_meses[d.month - 1]}';
}

class _Filete extends StatelessWidget {
  const _Filete({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: 1,
        margin: const EdgeInsets.only(top: 18, bottom: 10),
        color: ArcanumColors.goldMuted.withValues(alpha: 0.28),
      ),
      child,
    ],
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.accion, this.onTap});
  final String texto;
  final String? accion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(texto, style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
      if (accion != null && onTap != null)
        TextButton(
          onPressed: onTap,
          child: Text(
            accion!,
            style: ArcanumText.body(13, color: ArcanumColors.gold),
          ),
        ),
    ],
  );
}
