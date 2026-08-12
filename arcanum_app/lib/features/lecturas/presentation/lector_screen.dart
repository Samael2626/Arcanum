import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../data/library_repository.dart';
import '../data/reader_settings.dart';
import '../data/reading_repository.dart';
import '../domain/library_models.dart';
import '../domain/pagination.dart';
import '../domain/reading_position.dart';
import '../library_messages.dart';
import 'reader_widgets.dart';

/// El lector: un capítulo, página a página.
///
/// Página real, no una lista larga disfrazada: cada pantalla se compone
/// midiendo el texto contra el alto disponible, así que no hay recorte ni una
/// línea que se pierda al pasar. El precio es que la paginación cambia con la
/// tipografía y la pantalla — por eso lo que se guarda NUNCA es el número de
/// página, sino la posición estable, y al volver se recalcula qué página la
/// contiene.
class LectorScreen extends ConsumerStatefulWidget {
  final String workSlug;
  final String chapterSlug;

  /// Ancla desde la que abrir. La usan "Reanudar lectura" y los pasajes
  /// guardados para caer en el sitio exacto y no al principio del capítulo.
  final String? anchor;
  final int fragmentIndex;

  const LectorScreen({
    super.key,
    required this.workSlug,
    required this.chapterSlug,
    this.anchor,
    this.fragmentIndex = 0,
  });

  @override
  ConsumerState<LectorScreen> createState() => _LectorScreenState();
}

class _LectorScreenState extends ConsumerState<LectorScreen> {
  late Future<_ChapterBundle> _future = _load();

  final _controller = PageController();

  /// Se resuelve en initState y se guarda en un campo, nunca con `ref` dentro
  /// de dispose(): al desmontarse, el BuildContext ya no es valido y Riverpod
  /// lo prohibe. Y justo en dispose es cuando hay que guardar por donde ibas.
  ///
  /// Tampoco vale `late final ... = ref.read(...)`: eso es perezoso y la
  /// primera lectura acabaria ocurriendo dentro del propio dispose.
  late final ReadingRepository _reading;

  bool _spanish = true;
  List<ReaderPage> _pages = const [];
  int _page = 0;

  /// Ancla pendiente de restaurar. Se consume en el primer layout: hasta
  /// entonces no se sabe cuántas páginas hay ni en cuál cae.
  String? _pendingAnchor;
  int _pendingFragment = 0;
  bool _restored = false;

  /// True cuando ya se sabe si habia una posicion que restaurar.
  ///
  /// Hasta entonces no se guarda nada: guardar la primera pagina antes de
  /// resolver el punto de reanudacion pisaria el progreso real con el
  /// principio del capitulo.
  bool _resumeResolved = false;
  bool _savedOpening = false;

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _reading = ref.read(readingRepositoryProvider);
    _pendingAnchor = widget.anchor;
    _pendingFragment = widget.fragmentIndex;
    if (_pendingAnchor == null) {
      _resolveResumePoint();
    } else {
      _resumeResolved = true;
    }
  }

  /// Sin ancla explícita, se intenta reanudar donde se quedó esta obra.
  ///
  /// Solo si el progreso guardado es de ESTE capítulo: entrar por el índice a
  /// un capítulo concreto y que el lector te lleve a otro sería desobedecer.
  Future<void> _resolveResumePoint() async {
    try {
      final progress = await _reading.progressFor(widget.workSlug);
      if (!mounted || progress == null) return;
      if (progress.position.chapterSlug != widget.chapterSlug) return;
      setState(() {
        _pendingAnchor = progress.position.paragraphAnchor;
        _pendingFragment = progress.position.fragmentIndex;
        _spanish = progress.spanish;
        _restored = false;
      });
    } catch (_) {
      // Sin sesión o sin red se empieza por el principio, en silencio: no es
      // un fallo que merezca interrumpir la lectura.
    } finally {
      if (mounted) setState(() => _resumeResolved = true);
    }
  }

  Future<_ChapterBundle> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final chapter = await repo.chapter(widget.workSlug, widget.chapterSlug);
    LibraryWork? work;
    try {
      work = await repo.work(widget.workSlug);
    } catch (_) {
      // Sin el índice se puede leer igual; solo se pierde "siguiente capítulo".
    }
    return _ChapterBundle(chapter: chapter, work: work);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // Guardado final al salir: el debounce pendiente se perdería, y salir del
    // lector es justo cuando más importa no perder por dónde ibas.
    _flushProgress();
    _controller.dispose();
    super.dispose();
  }

  ReadingPosition? _positionAt(int index) {
    if (_pages.isEmpty) return null;
    // La pagina de cierre no es texto de la obra, asi que no tiene posicion
    // propia: hereda la de la ultima pagina real. Sin esto, un capitulo de una
    // sola pagina no registraba NADA — se leia entero y la obra seguia
    // diciendo "Comenzar lectura".
    final page = _pages[index.clamp(0, _pages.length - 1)];
    if (page.isEmpty) return null;
    final fragment = page.first;
    return ReadingPosition(
      workSlug: widget.workSlug,
      chapterSlug: widget.chapterSlug,
      paragraphAnchor: fragment.anchor,
      fragmentIndex: fragment.fragmentIndex,
    );
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    // Un segundo de calma: pasar cinco páginas seguidas es UN sitio donde te
    // quedaste, no cinco peticiones.
    _saveDebounce = Timer(const Duration(seconds: 1), _flushProgress);
  }

  void _flushProgress() {
    final position = _positionAt(_page);
    if (position == null) return;
    unawaited(_reading.saveProgress(position, spanish: _spanish));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final palette = settings.palette;

    return Scaffold(
      backgroundColor: palette == ReaderPalette.sepia
          ? ReaderColors.sepiaBackground
          : ArcanumColors.background,
      body: SafeArea(
        child: FutureBuilder<_ChapterBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (snapshot.hasError) {
              logLibraryFailure('capitulo', snapshot.error);
              return ChapterUnavailable(
                workSlug: widget.workSlug,
                onRetry: () => setState(() => _future = _load()),
              );
            }
            return _reader(snapshot.data!, settings);
          },
        ),
      ),
    );
  }

  Widget _reader(_ChapterBundle bundle, ReaderSettings settings) {
    final chapter = bundle.chapter;
    final onSepia = settings.palette == ReaderPalette.sepia;
    final textColor = onSepia ? ReaderColors.sepiaInk : ArcanumColors.ivory;

    final style = ArcanumText.body(settings.fontSize, color: textColor)
        .copyWith(height: 1.62);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, settings.maxWidth);
        // El alto útil descuenta cabecera, barra inferior y respiración: si se
        // paginase contra el alto total, la última línea quedaría debajo de la
        // barra, que es exactamente el recorte que hay que evitar.
        final usable = constraints.maxHeight - _chromeHeight;

        _pages = paginateChapter(
          paragraphs: [
            for (final p in chapter.paragraphs)
              ParagraphSource(
                anchor: p.anchor,
                text: p.textFor(spanish: _spanish),
              ),
          ],
          measure: (text) => _measure(text, style, width - 48),
          pageHeight: usable,
          paragraphSpacing: settings.fontSize * 0.9,
        );

        _restorePendingPage();
        _saveOpeningPosition();

        // +1: la página de cierre del capítulo, que no es texto de la obra y
        // por eso no la genera el paginador.
        final total = _pages.length + 1;

        return Column(
          children: [
            ReaderHeader(
              chapterTitle: chapter.title,
              page: _page + 1,
              total: total,
              spanish: _spanish,
              onLanguageChanged: _changeLanguage,
              onSettings: () => showReaderSettingsSheet(context, ref),
              onClose: () => context.pop(),
              onSepia: onSepia,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: settings.maxWidth),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (index) {
                      setState(() => _page = index);
                      _scheduleSave();
                    },
                    itemBuilder: (context, index) {
                      if (index == _pages.length) {
                        return ChapterClosing(
                          chapter: chapter,
                          next: bundle.nextChapter,
                          onSepia: onSepia,
                          onContinue: bundle.nextChapter == null
                              ? null
                              : () => _goToChapter(bundle.nextChapter!.slug),
                        );
                      }
                      return _PageBody(
                        page: _pages[index],
                        style: style,
                        chapter: chapter,
                        showHeader: index == 0,
                        onSepia: onSepia,
                        onPassageActions: (fragment) => showPassageActionsSheet(
                          context,
                          text: fragment.text,
                          chapterTitle: chapter.title,
                          workTitle: chapter.workTitle,
                          onSave: () => _savePassage(
                            fragment.anchor,
                            fragment.fragmentIndex,
                            fragment.text,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            ReaderBottomBar(
              onSepia: onSepia,
              canGoBack: _page > 0,
              canGoForward: _page < total - 1,
              onPrevious: () => _turn(-1),
              onNext: () => _turn(1),
              onIndex: () => context.push('/saber/${widget.workSlug}/indice'),
              onBookmark: _addBookmark,
            ),
          ],
        );
      },
    );
  }

  /// Alto del cromo fijo: cabecera + barra inferior + márgenes verticales.
  static const _chromeHeight = 168.0;

  double _measure(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    )..layout(maxWidth: maxWidth < 0 ? 0 : maxWidth);
    return painter.height;
  }

  /// Registra la posicion nada mas abrir el capitulo.
  ///
  /// Un capitulo de una sola pagina no dispara ningun cambio de pagina, asi
  /// que sin esto se podia leer entero y salir sin dejar rastro. Se hace una
  /// vez, tras el primer reparto en paginas y despues de resolver la
  /// reanudacion, y fuera del build: guardar durante el build seria un efecto
  /// secundario en mitad del pintado.
  void _saveOpeningPosition() {
    if (_savedOpening || !_resumeResolved || _pages.isEmpty) return;
    _savedOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _flushProgress();
    });
  }

  /// Lleva la vista a la página que contiene la posición pendiente.
  ///
  /// Se hace tras paginar y una sola vez: es el momento en el que la posición
  /// estable se traduce por fin a una página concreta.
  void _restorePendingPage() {
    if (_restored || _pendingAnchor == null || _pages.isEmpty) return;
    _restored = true;
    final target = pageIndexForPosition(
      _pages,
      paragraphAnchor: _pendingAnchor!,
      fragmentIndex: _pendingFragment,
    );
    if (target == _page) return;
    _page = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(target);
    });
  }

  /// Cambiar de idioma repagina: el mismo párrafo ocupa distinto en cada
  /// lengua. Se ancla al párrafo actual para no perder el sitio.
  void _changeLanguage(bool spanish) {
    final here = _positionAt(_page);
    setState(() {
      _spanish = spanish;
      _pendingAnchor = here?.paragraphAnchor;
      _pendingFragment = 0;
      _restored = false;
    });
    _scheduleSave();
  }

  void _turn(int delta) {
    _controller.animateToPage(
      _page + delta,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToChapter(String slug) =>
      context.pushReplacement('/saber/${widget.workSlug}/$slug');

  Future<void> _addBookmark() async {
    final position = _positionAt(_page);
    if (position == null) return;
    final created = await _reading.addBookmark(position);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == null
              ? 'Ya tenías un marcador aquí.'
              : 'Marcador guardado en esta página.',
        ),
      ),
    );
  }

  Future<void> _savePassage(String anchor, int fragment, String quote) async {
    final note = await showPassageNoteDialog(context, quote: quote);
    if (note == null || !mounted) return;

    final saved = await _reading.savePassage(
      position: ReadingPosition(
        workSlug: widget.workSlug,
        chapterSlug: widget.chapterSlug,
        paragraphAnchor: anchor,
        fragmentIndex: fragment,
      ),
      quote: quote,
      spanish: _spanish,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Ese pasaje ya estaba en tu grimorio.'
              : 'Pasaje guardado en el grimorio.',
        ),
      ),
    );
  }
}

/// El capítulo y su obra: la obra solo hace falta para saber qué viene después.
class _ChapterBundle {
  final LibraryChapter chapter;
  final LibraryWork? work;

  const _ChapterBundle({required this.chapter, this.work});

  /// El capítulo siguiente por posición, o null si este cierra la obra.
  LibraryChapterSummary? get nextChapter {
    final chapters = work?.chapters;
    if (chapters == null || chapters.isEmpty) return null;
    final ordered = [...chapters]
      ..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((c) => c.slug == chapter.slug);
    if (index < 0 || index + 1 >= ordered.length) return null;
    return ordered[index + 1];
  }
}

/// Una página de texto. Sin tarjetas ni molduras: es una página de libro.
class _PageBody extends StatelessWidget {
  final ReaderPage page;
  final TextStyle style;
  final LibraryChapter chapter;
  final bool showHeader;
  final bool onSepia;
  final void Function(ReaderFragment fragment) onPassageActions;

  const _PageBody({
    required this.page,
    required this.style,
    required this.chapter,
    required this.showHeader,
    required this.onSepia,
    required this.onPassageActions,
  });

  @override
  Widget build(BuildContext context) {
    // La primera página lleva el encabezado del capítulo; las demás son texto
    // limpio. Repetir el título en cada página sería cromo, no lectura.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            chapter.title,
            style: ArcanumText.heading(
              style.fontSize! + 8,
              color: onSepia ? ReaderColors.sepiaGold : ArcanumColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          ChapterOpening(chapter: chapter, onSepia: onSepia),
        ],
        for (final fragment in page.fragments)
          Padding(
            padding: EdgeInsets.only(bottom: style.fontSize! * 0.9),
            child: Semantics(
              label: 'Pasaje. Mantén pulsado para guardarlo o consultarlo.',
              child: GestureDetector(
                onLongPress: () => onPassageActions(fragment),
                child: Text(
                  fragment.text,
                  textAlign: TextAlign.justify,
                  style: style,
                ),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
      // La primera página puede desbordar por el encabezado; solo ahí se
      // permite desplazar. Las páginas de texto puro vienen medidas para caber.
      child: showHeader ? SingleChildScrollView(child: body) : body,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        color: ArcanumColors.gold,
        strokeWidth: 2,
      ),
    ),
  );
}
