import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contexto que se pasa entre pestañas para guiar un trabajo mágico.

/// Planeta para pre-filtrar Materia Arcana (Hoy → Arte).
class MateriaPlanet extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? planet) => state = planet;
}

final materiaPlanetProvider =
    NotifierProvider<MateriaPlanet, String?>(MateriaPlanet.new);

/// Señal para abrir el editor del grimorio al entrar (Hoy/Arte → Grimorio).
class GrimoireCompose extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final grimoireComposeProvider =
    NotifierProvider<GrimoireCompose, bool>(GrimoireCompose.new);
