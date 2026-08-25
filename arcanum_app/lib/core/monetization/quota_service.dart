import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monetization_service.dart';

/// Límites diarios por tier.
class DailyLimits {
  static const free = DailyLimits._(
    tarotDraws: 1,
    oracleReads: 1,
    materiaRecipes: 1,
    cielosInvestigations: 3,
  );

  static const premium = DailyLimits._(
    tarotDraws: 50,
    oracleReads: 20,
    materiaRecipes: 50,
    cielosInvestigations: 50,
  );

  final int tarotDraws;
  final int oracleReads;
  final int materiaRecipes;
  final int cielosInvestigations;

  const DailyLimits._({
    required this.tarotDraws,
    required this.oracleReads,
    required this.materiaRecipes,
    required this.cielosInvestigations,
  });
}

/// Conteo diario actual del usuario.
class DailyUsage {
  final int tarotDraws;
  final int oracleReads;
  final int materiaRecipes;
  final int cielosInvestigations;

  const DailyUsage({
    this.tarotDraws = 0,
    this.oracleReads = 0,
    this.materiaRecipes = 0,
    this.cielosInvestigations = 0,
  });
}

class QuotaService {
  static const _prefix = 'quota_';
  SharedPreferences? _prefs;
  String? _currentDate;

  Future<void> _ensureLoaded() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _resetIfNeeded() async {
    await _ensureLoaded();
    final today = _todayKey();
    if (_currentDate != today) {
      _currentDate = today;
      // Borrar contadores del día anterior.
      final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        if (!key.endsWith('_$today')) {
          await _prefs!.remove(key);
        }
      }
    }
  }

  Future<int> _getCount(String type) async {
    await _resetIfNeeded();
    return _prefs!.getInt('$_prefix${type}_${_todayKey()}') ?? 0;
  }

  /// Cupos extra ganados hoy, por ver un anuncio.
  ///
  /// Se guardan con la fecha en la clave, igual que los contadores, así que
  /// caducan solos: `_resetIfNeeded` borra todo lo que no sea de hoy. Un bonus
  /// que sobreviviera a la noche sería un límite diario que deja de serlo.
  Future<int> _getBonus(String type) async {
    await _resetIfNeeded();
    return _prefs!.getInt('$_prefix${type}_bonus_${_todayKey()}') ?? 0;
  }

  /// Concede un uso extra de [action] para hoy.
  ///
  /// SUMA AL LÍMITE en vez de restar al contador. Parece lo mismo y no lo es:
  /// restando se perdería cuántas veces se usó de verdad, que es justo el dato
  /// que dice si esto le sirve a alguien.
  ///
  /// Quien llama debe haber comprobado que el anuncio se completó. Aquí no se
  /// pregunta: este objeto no sabe de anuncios.
  Future<void> grantBonus(String action) async {
    await _resetIfNeeded();
    final key = '$_prefix${action}_bonus_${_todayKey()}';
    await _prefs!.setInt(key, (_prefs!.getInt(key) ?? 0) + 1);
  }

  Future<void> _increment(String type) async {
    await _resetIfNeeded();
    final key = '$_prefix${type}_${_todayKey()}';
    final current = _prefs!.getInt(key) ?? 0;
    await _prefs!.setInt(key, current + 1);
  }

  Future<DailyUsage> getUsage() async {
    return DailyUsage(
      tarotDraws: await _getCount('tarot'),
      oracleReads: await _getCount('oracle'),
      materiaRecipes: await _getCount('materia'),
      cielosInvestigations: await _getCount('cielos'),
    );
  }

  /// Verifica si el usuario puede realizar una acción.
  /// Retorna true si tiene cupo disponible.
  Future<bool> canPerform(String action, SubscriptionTier tier) async {
    final usage = await getUsage();
    final limits = tier == SubscriptionTier.premium
        ? DailyLimits.premium
        : DailyLimits.free;
    final bonus = await _getBonus(action);

    switch (action) {
      case 'tarot':
        return usage.tarotDraws < limits.tarotDraws + bonus;
      case 'oracle':
        return usage.oracleReads < limits.oracleReads + bonus;
      case 'materia':
        return usage.materiaRecipes < limits.materiaRecipes + bonus;
      case 'cielos':
        return usage.cielosInvestigations < limits.cielosInvestigations + bonus;
      default:
        return true;
    }
  }

  /// Incrementa el contador de una acción.
  Future<void> recordUsage(String action) async {
    switch (action) {
      case 'tarot':
        await _increment('tarot');
      case 'oracle':
        await _increment('oracle');
      case 'materia':
        await _increment('materia');
      case 'cielos':
        await _increment('cielos');
    }
  }

  /// Retorna cuántos usos le quedan al usuario para una acción.
  Future<int> remaining(String action, SubscriptionTier tier) async {
    final usage = await getUsage();
    final limits = tier == SubscriptionTier.premium
        ? DailyLimits.premium
        : DailyLimits.free;

    final bonus = await _getBonus(action);
    int used;
    int limit;
    switch (action) {
      case 'tarot':
        used = usage.tarotDraws;
        limit = limits.tarotDraws;
      case 'oracle':
        used = usage.oracleReads;
        limit = limits.oracleReads;
      case 'materia':
        used = usage.materiaRecipes;
        limit = limits.materiaRecipes;
      case 'cielos':
        used = usage.cielosInvestigations;
        limit = limits.cielosInvestigations;
      default:
        return 999;
    }
    limit += bonus;
    return (limit - used).clamp(0, limit);
  }
}

final quotaServiceProvider = Provider<QuotaService>((ref) {
  return QuotaService();
});
