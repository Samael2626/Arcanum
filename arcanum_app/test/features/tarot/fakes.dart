import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:dio/dio.dart';

/// Servidor de mentira con la misma forma de respuesta que el backend.
class FakeServer extends ArcanumApi {
  FakeServer() : super(Dio());

  int opened = 0;
  String? id;
  Map<String, List<String?>> piles = {};
  List<String> drawn = [];
  String status = 'open';
  Map<String, dynamic>? lastInterpret;
  Map<String, dynamic>? closedWith;
  int seq = 0;
  final List<String> shuffles = [];

  /// Si no es null, la proxima operacion de mesa falla con este error.
  Object? failNext;

  Map<String, dynamic> _view() => {
    'id': id,
    'status': status,
    'deck': 'rws',
    'state': 'sin barajar',
    'total': piles.values.fold<int>(
      0,
      (a, p) => a + p.whereType<String>().length,
    ),
    'piles': {
      for (final e in piles.entries)
        e.key: {
          'count': e.value.whereType<String>().length,
          'positions': [
            for (var i = 0; i < e.value.length; i++)
              if (e.value[i] != null) i,
          ],
        },
    },
    'drawn': [
      for (final s in drawn) {'slug': s, 'reversed': s == 'c2'},
    ],
    'expires_at': '2026-09-30T12:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> tarotOpenTable(String deck) async {
    id = 'mesa-${++opened}';
    piles = {'p0': List.generate(6, (i) => 'c$i')};
    drawn = [];
    status = 'open';
    return _view();
  }

  @override
  Future<Map<String, dynamic>?> tarotCurrentTable() async =>
      id == null || status == 'closed' ? null : _view();

  @override
  Future<Map<String, dynamic>> tarotTableOp(
    String sessionId,
    String op,
    Map<String, dynamic> body,
  ) async {
    if (sessionId != id) throw StateError('mesa ajena');
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
    switch (op) {
      case 'take':
        final pile = piles[body['pile']]!;
        final slug = pile[body['position'] as int]!;
        pile[body['position'] as int] = null;
        drawn.add(slug);
        return {
          'table': _view(),
          'card': {'slug': slug, 'reversed': slug == 'c2', 'name': slug},
        };
      case 'cut':
        final live = piles[body['pile']]!.whereType<String>().toList();
        final n = body['n'] as int;
        final pid = 'p${++seq}';
        piles[pid] = List<String?>.of(live.sublist(0, n));
        piles[body['pile'] as String] = List<String?>.of(live.sublist(n));
        return {'table': _view(), 'pile': pid};
      case 'merge':
        final into = body['into'] as String;
        final all = [
          for (final p in (body['piles'] as List).cast<String>())
            ...piles[p]!.whereType<String>(),
        ];
        for (final p in (body['piles'] as List).cast<String>()) {
          piles.remove(p);
        }
        piles[into] = List<String?>.of(all);
        return _view();
      case 'gather':
        final pid = body['pile'] as String;
        piles[pid] = [...piles[pid]!.whereType<String>(), ...drawn];
        drawn = [];
        return _view();
      case 'shuffle':
        shuffles.add('${body['pile']}:${body['style']}');
        return _view();
      case 'return':
        drawn.remove(body['slug']);
        piles[body['pile']]!.add(body['slug'] as String);
        return _view();
      default:
        return _view();
    }
  }

  @override
  Future<Map<String, dynamic>> tarotInterpret(
    String sessionId, {
    required String spread,
    required List<Map<String, dynamic>> placements,
    String? question,
    String? idempotencyKey,
  }) async {
    lastInterpret = {
      'spread': spread,
      'placements': placements,
      'question': question,
    };
    status = 'interpreted';
    return {
      'session_id': sessionId,
      'spread': spread,
      'spread_name': 'Una carta',
      'question': question,
      'cards': [
        {
          'slug': placements.first['slug'],
          'reversed': false,
          'slot': 0,
          'position': 'Mensaje',
          'meaning': 'derecha',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> tarotCloseTable(
    String sessionId, {
    Map<String, dynamic>? table,
  }) async {
    closedWith = table;
    status = 'closed';
    return {'id': 'lectura-1', 'spread_type': 'one_card'};
  }
}
