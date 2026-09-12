import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../cielos/cielos_screen.dart';
import '../hoy/hoy_screen.dart';

/// "Cielo": el mismo cielo mirado ahora y mirado al nacer.
///
/// **Ahora** es el instrumento del instante -- regente, hora planetaria, luna y
/// el siguiente paso. **Tu carta** es la rueda natal y lo que hoy la toca.
/// Antes eran dos pestañas, y separarlas obligaba a saltar de sección para
/// entender por qué un tránsito aprieta: el tránsito vive en una y el punto que
/// recibe en la otra.
///
/// SE COMPONE, NO SE FUNDE, y es la condición de la que depende todo lo demás.
/// `CielosScreen` son 1.064 líneas y `HoyScreen` 629; juntarlas en un fichero
/// habría reescrito las dos pantallas más cargadas de la app. Aquí se montan
/// **intactas**, igual que Saber monta Plantas y Biblioteca.
///
/// Y hay un motivo que no es de estilo: `test/capturas/hoy_capturas_test.dart`
/// retrata `HoyScreen` y guarda 13 goldens, de los cuales **tres no se pueden
/// regenerar** desde el 04/09 (ver la deuda en `ARCANUM-Mejoras-y-Retos`).
/// Mientras el test siga montando `HoyScreen` sola y esta clase no la toque,
/// esos goldens siguen valiendo. Fundir las clases los habría invalidado todos
/// y tres de ellos no habrían vuelto.
///
/// `IndexedStack` y no un `if`: conserva el scroll y el estado de cada cara al
/// alternar, que es lo que hace que volver a "Ahora" no recargue el cielo.
///
/// PERO LA RUEDA NO SE MONTA HASTA QUE SE PIDE. `IndexedStack` construye TODOS
/// sus hijos, asi que al abrir la app se cargaria tambien la carta natal
/// aunque nadie mire esa cara: una llamada de red y una rueda entera pintadas
/// para nadie. Hasta la primera vez que se abre va un hueco; despues se queda
/// montada y conserva su estado como la otra.
class CieloScreen extends ConsumerStatefulWidget {
  const CieloScreen({super.key});

  @override
  ConsumerState<CieloScreen> createState() => _CieloScreenState();
}

class _CieloScreenState extends ConsumerState<CieloScreen> {
  bool _cartaMontada = false;

  @override
  Widget build(BuildContext context) {
    final cara = ref.watch(cieloCaraProvider);
    if (cara == 1) _cartaMontada = true;
    return Column(
      children: [
        const SizedBox(height: 10),
        _Caras(
          cara: cara,
          onChanged: (i) => ref.read(cieloCaraProvider.notifier).set(i),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: IndexedStack(
            index: cara,
            children: [
              const HoyScreen(),
              if (_cartaMontada)
                const CielosScreen()
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

/// El conmutador de las dos caras. Misma píldora que el de Saber: es el mismo
/// gesto -- dos vistas de una sección -- y merece la misma forma.
class _Caras extends StatelessWidget {
  const _Caras({required this.cara, required this.onChanged});

  final int cara;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _pastilla('Ahora', 0),
              const SizedBox(width: 10),
              _pastilla('Tu carta', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastilla(String rotulo, int valor) {
    final elegida = valor == cara;
    return Expanded(
      child: Semantics(
        button: true,
        selected: elegida,
        label: rotulo,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onChanged(valor),
          // 48 de alto: lo que se toca no baja de ahi. El de Saber se quedo en
          // 40 y no se toca aqui, que es otra pantalla y otro commit.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: elegida
                    ? ArcanumColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: elegida
                      ? ArcanumColors.gold
                      : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  rotulo,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(
                    16,
                    color: elegida
                        ? ArcanumColors.gold
                        : ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
