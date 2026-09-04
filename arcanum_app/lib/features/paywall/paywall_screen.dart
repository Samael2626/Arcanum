import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/monetization/monetization_service.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/gold_button.dart';

/// Paywall de ARCANUM: 3 vías — Gratis, Consumibles, Premium.
/// Annual es la opción por defecto (sweet spot de conversión).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    // Los precios vienen de Play/App Store ya localizados. Si no cargan, el
    // SKU no se muestra ni se puede tocar: mejor una via menos que un precio
    // inventado, que ademas es motivo de rechazo en ambas tiendas.
    // `.value ?? {}` aplastaba los tres estados del provider en uno: cargando,
    // fallido y "la tienda no tiene nada" quedaban igual de mudos. Se conserva
    // el AsyncValue para poder decir cual de los tres es.
    final preciosAsync = ref.watch(storePricesProvider);
    final precios = preciosAsync.value ?? const <String, String>{};
    final cargandoPrecios = preciosAsync.isLoading;
    final hayConsumibles = ProductIds.enVenta.any(precios.containsKey);
    final hayAnual = precios[ProductIds.premiumAnnual] != null;
    // El ahorro se calcula con los importes reales de la tienda. Escrito a
    // mano ("AHORRA 42%") era una afirmacion sobre precios en dolares que deja
    // de ser cierta en cuanto cambia la moneda o el precio en la consola.
    final ahorroAnual = ref.watch(descuentoAnualProvider).value;

    return Scaffold(
      backgroundColor: ArcanumColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                const SizedBox(height: 12),
                // Header
                const Text(
                  '✦',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 42, color: ArcanumColors.gold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Desbloquea tu práctica',
                  textAlign: TextAlign.center,
                  style: ArcanumText.heading(28),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige el camino que resuene contigo',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(
                    15,
                    color: ArcanumColors.ivoryMuted,
                    italic: true,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Tier 1: Gratis ──
                _TierCard(
                  title: 'Explorador',
                  subtitle: 'Siempre gratis',
                  price: '',
                  features: const [
                    'Carta natal y tránsitos',
                    '1 tirada de tarot / día',
                    '1 lectura oráculo / día',
                    'Grimorio personal',
                    '3 capítulos de Saber / semana',
                  ],
                  accent: ArcanumColors.ivoryMuted,
                  selected: false,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 14),

                // ── Tier 2: Consumibles ──
                _TierCard(
                  title: 'Prácticante',
                  subtitle: 'Compra lo que necesites',
                  price: '',
                  features: [
                    'Todo lo del Explorador',
                    if (precios[ProductIds.credit1] != null)
                      'Lectura del Umbral — ${precios[ProductIds.credit1]}',
                    if (precios[ProductIds.pack3] != null)
                      'Pack de 3 lecturas — ${precios[ProductIds.pack3]}',
                    'Ningún crédito expira',
                    'Sin compromiso mensual',
                  ],
                  accent: ArcanumColors.goldMuted,
                  selected: false,
                  onTap: hayConsumibles
                      ? _showConsumablesSheet
                      : () => _avisarSinOfertas(cargandoPrecios),
                  estado: hayConsumibles ? null : _leyendaOfertas(cargandoPrecios),
                  ctaLabel: 'Ver créditos y packs',
                ),
                const SizedBox(height: 14),

                // ── Tier 3: Premium ──
                _TierCard(
                  title: 'Místico',
                  subtitle: 'La experiencia completa',
                  price: precios[ProductIds.premiumAnnual] ?? '',
                  features: const [
                    'Más lecturas diarias según tu plan',
                    'Sin anuncios',
                    'Interpretaciones profundas',
                    'Modo Aprender completo',
                    '7 días gratis',
                  ],
                  accent: ArcanumColors.gold,
                  selected: true,
                  onTap: hayAnual
                      ? _purchaseAnnual
                      : () => _avisarSinOfertas(cargandoPrecios),
                  estado: hayAnual ? null : _leyendaOfertas(cargandoPrecios),
                  badge: ahorroAnual,
                ),
                const SizedBox(height: 10),

                // Monthly option
                if (precios[ProductIds.premiumMonthly] != null)
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _purchaseMonthly,
                    child: Text(
                      'O ${precios[ProductIds.premiumMonthly]}/mes',
                      style: ArcanumText.body(
                        14,
                        color: ArcanumColors.goldMuted,
                      ),
                    ),
                  ),
                ),

                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(
                      color: ArcanumColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: ArcanumText.body(
                      13,
                      color: ArcanumColors.burgundyLight,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading ? null : _restore,
                  child: Text(
                    'Restaurar compras',
                    style: ArcanumText.body(
                      13,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchaseAnnual() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(monetizationServiceProvider);
      final offerings = await service.getOfferings();
      final annual = offerings?.current?.annual;
      if (annual == null) {
        setState(() {
          _error = 'Oferta no disponible. Intenta de nuevo.';
          _loading = false;
        });
        return;
      }
      final success = await service.purchasePackage(annual);
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al procesar. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  /// Lo que se pinta donde iria el precio mientras no hay ninguno.
  String _leyendaOfertas(bool cargando) => cargando
      ? 'Consultando los precios de Google Play…'
      : 'Precios no disponibles ahora mismo';

  /// Un boton apagado que no dice por que es un callejon sin salida: el usuario
  /// pulsa, no pasa nada y no tiene forma de saber si es culpa suya. Si no hay
  /// oferta que comprar se dice, y ademas se reintenta la consulta.
  void _avisarSinOfertas(bool cargando) {
    if (!cargando) ref.invalidate(storePricesProvider);
    setState(() {
      _error = cargando
          ? 'Todavía estamos consultando los precios. Inténtalo en un momento.'
          : 'Oferta no disponible. Revisa tu conexión e inténtalo de nuevo.';
    });
  }

  Future<void> _purchaseMonthly() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(monetizationServiceProvider);
      final offerings = await service.getOfferings();
      final monthly = offerings?.current?.monthly;
      if (monthly == null) {
        setState(() {
          _error = 'Oferta no disponible.';
          _loading = false;
        });
        return;
      }
      final success = await service.purchasePackage(monthly);
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al procesar.';
        _loading = false;
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(monetizationServiceProvider);
      final restored = await service.restorePurchases();
      if (restored && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'No se encontraron compras previas.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al restaurar.';
        _loading = false;
      });
    }
  }

  void _showConsumablesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcanumColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ConsumiblesSheet(parentContext: context),
    );
  }
}

// ── Tarjeta de tier ────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final List<String> features;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  final String? badge;

  /// Texto del boton cuando el automatico no describe lo que pasa al tocarlo.
  /// Sin esto, un tier sin precio anuncia "Continuar gratis" aunque abra la
  /// hoja de packs de pago.
  final String? ctaLabel;

  /// Ocupa el sitio del precio cuando la tienda todavia no ha dado ninguno.
  /// Una tarjeta sin precio y sin explicacion no se distingue de una tarjeta
  /// que simplemente no cuesta nada.
  final String? estado;

  const _TierCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.features,
    required this.accent,
    required this.selected,
    this.onTap,
    this.badge,
    this.ctaLabel,
    this.estado,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ArcanumColors.surface,
          border: Border.all(
            color: selected
                ? accent
                : accent.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ArcanumText.heading(20, color: accent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: ArcanumText.body(
                          13,
                          color: ArcanumColors.ivoryMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: accent.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      badge!,
                      style: ArcanumText.label(),
                    ),
                  ),
              ],
            ),
            if (price.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                price,
                style: ArcanumText.heading(26, color: accent),
              ),
            ] else if (estado != null) ...[
              const SizedBox(height: 12),
              Text(
                estado!,
                style: ArcanumText.body(
                  13,
                  color: ArcanumColors.ivoryMuted,
                  italic: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✦ ',
                      style: TextStyle(
                        fontSize: 12,
                        color: accent.withValues(alpha: 0.7),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        f,
                        style: ArcanumText.body(
                          13,
                          color: ArcanumColors.ivoryMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GoldButton(
                label: ctaLabel ??
                    (selected
                        ? 'Empezar prueba gratis'
                        : price.isEmpty
                            ? 'Continuar gratis'
                            : 'Ver opciones'),
                onPressed: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet de consumibles ────────────────────────────────────────────

class _ConsumiblesSheet extends ConsumerWidget {
  final BuildContext parentContext;

  const _ConsumiblesSheet({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precios =
        ref.watch(storePricesProvider).value ?? const <String, String>{};

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Créditos y packs',
            style: ArcanumText.heading(22),
          ),
          const SizedBox(height: 6),
          Text(
            'Compra solo lo que necesitas. Ningún crédito expira.',
            style: ArcanumText.body(
              14,
              color: ArcanumColors.ivoryMuted,
              italic: true,
            ),
          ),
          const SizedBox(height: 20),
          if (precios[ProductIds.credit1] != null)
            _ConsumableTile(
              title: 'Lectura del Umbral',
              price: precios[ProductIds.credit1]!,
              description: '1 crédito — una lectura completa',
              onTap: () => _comprar(context, ProductIds.credit1),
            ),
          if (precios[ProductIds.pack3] != null)
            _ConsumableTile(
              title: 'Pack de 3 lecturas',
              price: precios[ProductIds.pack3]!,
              description: '3 créditos, más barato que sueltos',
              onTap: () => _comprar(context, ProductIds.pack3),
            ),
          if (!ProductIds.enVenta.any(precios.containsKey))
            Text(
              'No pudimos consultar la tienda. Inténtalo de nuevo en un momento.',
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
        ],
      ),
    );
  }

  Future<void> _comprar(BuildContext context, String productId) async {
    Navigator.of(context).pop();
    final service = ProviderScope.containerOf(parentContext)
        .read(monetizationServiceProvider);
    await service.purchaseProduct(productId);
  }
}

class _ConsumableTile extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final VoidCallback onTap;

  const _ConsumableTile({
    required this.title,
    required this.price,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ArcanumColors.surfaceHigh,
            border: Border.all(
              color: ArcanumColors.goldMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ArcanumText.body(15, color: ArcanumColors.gold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: ArcanumText.body(
                        12,
                        color: ArcanumColors.ivoryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: ArcanumText.heading(18, color: ArcanumColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
