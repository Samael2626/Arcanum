/// Frontera publica del modulo Nombre y Umbral.
///
/// Tarot, Cielos y Oraculo pueden importar este archivo y ningun otro del
/// modulo. Lo garantiza `test/features/name_threshold/network_isolation_test.dart`:
/// el perfil, el repositorio cifrado, el controlador, el catalogo y el
/// conversor fonetico quedan fuera de su alcance, y lo que cruza es siempre
/// una [NameResonance] ya recortada.
library;

export 'application/bridge_resonance.dart' show nameResonanceProvider;
export 'domain/name_resonance.dart' show NameResonance;
export 'domain/threshold_bridge.dart' show ThresholdBridge;
export 'presentation/threshold_resonance_card.dart' show ThresholdResonanceCard;
