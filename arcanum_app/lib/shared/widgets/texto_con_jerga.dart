import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/content/court_lore.dart';
import '../../core/content/jerga_en_la_lectura.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'info_dot.dart';

/// Un texto del Oraculo con sus terminos de oficio subrayados y tocables.
///
/// EL PROBLEMA. En las lecturas quedan palabras que nadie entiende --"la obra
/// del hod terrestre", "primer decanato", "tu Venus natal", "el Caballero de
/// Copas"--. No las inventa el modelo: vienen del significado de cada carta
/// del catalogo, y tres variantes del prompt no las quitaron.
///
/// LA DECISION es no esconderlas. La sefira es la estructura real del arcano
/// menor y la figura es media lectura; borrarlas empobreceria las cartas. Se
/// subrayan en dorado y se abren, que es lo que ya hace Cielos con los
/// terminos del sello y lo que ARCANUM dice ser: un instrumento que ensena
/// usandolo.
///
/// SE DEGRADA SOLO. Si la voz mejora y un dia no queda jerga,
/// `jergaEnLaLectura` devuelve vacio y esto pinta un `Text` normal. No hay que
/// quitarlo de la pantalla: deja de hacer nada.
class TextoConJerga extends StatefulWidget {
  final String texto;
  final TextStyle? estilo;

  const TextoConJerga(this.texto, {super.key, this.estilo});

  @override
  State<TextoConJerga> createState() => _TextoConJergaState();
}

class _TextoConJergaState extends State<TextoConJerga> {
  /// Los reconocedores son objetos con ciclo de vida: si no se liberan, cada
  /// lectura nueva deja los de la anterior vivos. Se guardan para poder
  /// soltarlos en `dispose` y al cambiar de texto.
  final List<TapGestureRecognizer> _gestos = [];
  late List<TerminoJerga> _terminos;

  @override
  void initState() {
    super.initState();
    _terminos = jergaEnLaLectura(widget.texto);
  }

  @override
  void didUpdateWidget(TextoConJerga viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.texto != widget.texto) {
      _soltarGestos();
      _terminos = jergaEnLaLectura(widget.texto);
    }
  }

  @override
  void dispose() {
    _soltarGestos();
    super.dispose();
  }

  void _soltarGestos() {
    for (final g in _gestos) {
      g.dispose();
    }
    _gestos.clear();
  }

  void _abrir(TerminoJerga t) {
    final sefira = t.sefira;
    final figura = t.figura;
    final glosario = t.glosario;

    if (sefira != null) {
      showConceptSheet(
        context,
        titulo: sefira.titulo,
        subtitulo: '${sefira.numero} de 10 · ${sefira.planeta} · ${sefira.mundo}',
        que: sefira.que,
        comoLabel: 'QUÉ APORTA EN LA CARTA',
        como: sefira.enLaCarta,
      );
    } else if (figura != null) {
      showConceptSheet(
        context,
        titulo: figura.titulo,
        subtitulo: 'figura de la corte · elemento ${figura.elemento}',
        que: figura.que,
        comoLabel: 'QUÉ APORTA EN LA TIRADA',
        como: '${figura.enLaTirada}\n\n$courtElementoDoble\n\n$courtAviso',
      );
    } else if (glosario != null) {
      showConceptSheet(
        context,
        titulo: glosario.title,
        que: glosario.what,
        como: glosario.howTo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.estilo ?? ArcanumText.body(16);
    if (_terminos.isEmpty) return Text(widget.texto, style: base);

    _soltarGestos();
    final marcado = base.copyWith(
      color: ArcanumColors.gold,
      decoration: TextDecoration.underline,
      decorationColor: ArcanumColors.goldMuted,
      decorationThickness: 2,
    );

    final trozos = <InlineSpan>[];
    var cursor = 0;
    for (final t in _terminos) {
      if (t.inicio > cursor) {
        trozos.add(TextSpan(text: widget.texto.substring(cursor, t.inicio)));
      }
      final gesto = TapGestureRecognizer()..onTap = () => _abrir(t);
      _gestos.add(gesto);
      trozos.add(
        TextSpan(
          text: t.textoVisible,
          style: marcado,
          recognizer: gesto,
          // Sin esto, el lector de pantalla lee la palabra y no dice que se
          // puede abrir: el subrayado dorado no existe para quien no lo ve.
          semanticsLabel: '${t.textoVisible}, toca para saber qué significa',
        ),
      );
      cursor = t.fin;
    }
    if (cursor < widget.texto.length) {
      trozos.add(TextSpan(text: widget.texto.substring(cursor)));
    }

    return Text.rich(TextSpan(style: base, children: trozos));
  }
}
