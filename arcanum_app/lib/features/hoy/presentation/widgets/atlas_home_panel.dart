import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/moon_disc.dart';

/// Portada de acceso a las cinco secciones. El cielo es la quinta placa.
/// Ninguna superficie aplica blur ni anima de forma permanente.
class AtlasHomePanel extends StatelessWidget {
  const AtlasHomePanel({
    super.key,
    required this.moon,
    required this.observedAt,
    required this.onMoonTap,
    required this.onHoroscope,
    required this.onGrimoire,
    required this.onSaber,
    required this.onTable,
    required this.onOracle,
    this.showTable = false,
    this.horoscopeKey,
  });

  final Map<String, dynamic> moon;
  final DateTime observedAt;
  final VoidCallback onMoonTap;
  final VoidCallback onHoroscope;
  final VoidCallback onGrimoire;
  final VoidCallback onSaber;
  final VoidCallback onTable;
  final VoidCallback onOracle;

  /// La placa de la mesa de tarot sale solo donde la mesa ya se ensena (builds
  /// de desarrollo y perfil, como su entrada del cajon). Se SUMA a la del
  /// Oraculo, no la sustituye: quitarla dejaba el Oraculo sin entrada.
  final bool showTable;
  final Key? horoscopeKey;

  @override
  Widget build(BuildContext context) {
    final phase = moon['phase_name'] as String;
    final illumination = (moon['illumination'] as num).toDouble();
    final waxing = moon['is_waxing'] as bool;
    final percent = (illumination * 100).round();
    final moment = MaterialLocalizations.of(
      context,
    ).formatMediumDate(observedAt);
    final time = TimeOfDay.fromDateTime(observedAt).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AtlasTile(
          key: const Key('atlas-cielo'),
          label: 'Cielo · consultado $moment, $time',
          title: phase,
          detail: '$percent % de la Luna iluminada',
          action: 'Explorar la Luna',
          accent: ArcanumColors.moonAccent,
          background: ArcanumColors.moonCore,
          height: 194,
          onTap: onMoonTap,
          art: MoonDisc(illumination: illumination, waxing: waxing, size: 82),
        ),
        const SizedBox(height: 22),
        Text('Elige tu práctica', style: ArcanumText.heading(29)),
        const SizedBox(height: 12),
        if (showTable) ...[
          _AtlasTile(
            key: const Key('atlas-mesa'),
            label: 'Tarot',
            title: 'Mesa de tarot',
            detail: 'Baraja, tira y desvela con tus manos',
            action: 'Abrir la mesa',
            accent: ArcanumColors.burgundyLight,
            background: ArcanumColors.burgundy,
            height: 184,
            onTap: onTable,
            art: Image.asset(
              'assets/tarot/la-luna.webp',
              width: 91,
              height: 143,
              fit: BoxFit.cover,
              semanticLabel: '',
            ),
          ),
          const SizedBox(height: 12),
        ],
        _AtlasTile(
          key: const Key('atlas-oraculo'),
          label: 'Consulta',
          title: 'Oráculo',
          detail: 'Pregunta y recibe una lectura',
          action: 'Abrir Oráculo',
          accent: ArcanumColors.burgundyLight,
          background: ArcanumColors.burgundy,
          height: showTable ? 115 : 184,
          onTap: onOracle,
          art: Image.asset(
            'assets/tarot/la-luna.webp',
            width: 91,
            height: 143,
            fit: BoxFit.cover,
            semanticLabel: '',
          ),
        ),
        const SizedBox(height: 12),
        _AtlasTile(
          key: horoscopeKey ?? const Key('atlas-horoscopo'),
          label: 'Lectura diaria',
          title: 'Horóscopo',
          detail: 'Tu cielo de hoy, sobre tu carta',
          action: 'Abrir Horóscopo',
          accent: ArcanumColors.goldLight,
          background: ArcanumColors.surfaceHigh,
          height: 115,
          onTap: onHoroscope,
          art: const Icon(Icons.brightness_4_outlined, size: 56),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35;
            final grimorio = _AtlasTile(
              key: const Key('atlas-grimorio'),
              label: 'Tu espacio',
              title: 'Grimorio',
              detail: 'Escribe en tu diario cifrado',
              action: 'Escribir',
              accent: ArcanumColors.goldLight,
              background: ArcanumColors.neutralCore,
              height: stacked ? 132 : 190,
              onTap: onGrimoire,
              compact: !stacked,
              art: const Icon(Icons.menu_book_outlined, size: 40),
            );
            final saber = _AtlasTile(
              key: const Key('atlas-saber'),
              label: 'Tradición',
              title: 'Saber',
              detail: 'Plantas y libros',
              action: 'Explorar',
              accent: ArcanumColors.elementEarth,
              background: ArcanumColors.earthCore,
              height: stacked ? 132 : 190,
              onTap: onSaber,
              compact: !stacked,
              art: const Icon(Icons.local_library_outlined, size: 40),
            );
            return stacked
                ? Column(
                    children: [grimorio, const SizedBox(height: 12), saber],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: grimorio),
                      const SizedBox(width: 12),
                      Expanded(child: saber),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _AtlasTile extends StatelessWidget {
  const _AtlasTile({
    super.key,
    required this.label,
    required this.title,
    required this.detail,
    required this.action,
    required this.accent,
    required this.background,
    required this.height,
    required this.onTap,
    required this.art,
    this.compact = false,
  });

  final String label;
  final String title;
  final String detail;
  final String action;
  final Color accent;
  final Color background;

  /// Alto de diseño, como minimo: con letra grande o en pantalla estrecha la
  /// baldosa crece. Con alto fijo, el texto se salia por abajo.
  final double height;
  final VoidCallback onTap;
  final Widget art;
  final bool compact;

  /// Hueco que la columna deja a la accion de abajo.
  static const double _actionRoom = 34;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$action. $detail',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [background, ArcanumColors.surface],
            ),
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: .65)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Padding(
                padding: EdgeInsets.all(compact ? 14 : 20),
                // la accion va anclada abajo y la columna le deja su hueco:
                // asi la baldosa mide su alto de diseno o lo que pida el texto
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      bottom: compact ? 54 : 0,
                      child: IconTheme(
                        data: IconThemeData(
                          color: accent.withValues(alpha: .65),
                        ),
                        child: art,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: _actionRoom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ArcanumText.label(),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ArcanumText.heading(compact ? 25 : 33),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: compact ? 112 : 204,
                            child: Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ArcanumText.body(
                                14,
                                color: ArcanumColors.ivoryMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        '$action  →',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArcanumText.body(14, color: accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
