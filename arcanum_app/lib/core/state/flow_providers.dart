import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contexto que se pasa entre pestañas para guiar un trabajo mágico.

/// Planeta para pre-filtrar Materia Arcana (Hoy → Arte).
class MateriaPlanet extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? planet) => state = planet;
}

final materiaPlanetProvider = NotifierProvider<MateriaPlanet, String?>(
  MateriaPlanet.new,
);

/// Señal para abrir el editor del grimorio al entrar (Hoy/Arte → Grimorio).
class GrimoireCompose extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final grimoireComposeProvider = NotifierProvider<GrimoireCompose, bool>(
  GrimoireCompose.new,
);

/// Planeta a enfocar en Cielos al entrar (Hoy → Cielos). Cielos resalta la fila
/// de ese planeta en la carta natal y se desplaza hasta ella; luego lo limpia
/// para no re-disparar el foco en visitas siguientes.
class CielosFocusPlanet extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? planet) => state = planet;
}

final cielosFocusPlanetProvider =
    NotifierProvider<CielosFocusPlanet, String?>(CielosFocusPlanet.new);

/// Cara de la pestaña Cielo: 0 = Ahora (el instrumento del instante), 1 = Tu
/// carta (la rueda natal).
///
/// Existe porque las dos caras son UNA pestaña desde el 11-sep-2026, y lo que
/// antes era un salto de sección -- "Hoy → Cielos" -- ahora es un cambio de
/// cara dentro de la misma. Sin esto, el chip de Hoy que llevaba a la rueda
/// navegaría a la pestaña donde ya está y no pasaría nada.
class CieloCara extends Notifier<int> {
  @override
  int build() => 0;
  void set(int cara) => state = cara;
}

final cieloCaraProvider = NotifierProvider<CieloCara, int>(CieloCara.new);

/// Carta de tarot a abrir en Oráculo → Aprender al entrar (Hoy → Oráculo). Es
/// el slug de la carta ('el-sol'); Oráculo arranca en modo Aprender y abre su
/// ficha. Se limpia tras consumirse.
class OraculoFocusCard extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? slug) => state = slug;
}

final oraculoFocusCardProvider =
    NotifierProvider<OraculoFocusCard, String?>(OraculoFocusCard.new);
