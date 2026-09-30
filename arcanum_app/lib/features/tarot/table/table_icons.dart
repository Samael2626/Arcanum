/// Iconos de trazo de la mesa, los mismos del prototipo (24 x 24, trazo 1,6).
///
/// Propios y no de Material: la mesa es un instrumento, no una app de oficina.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _paths = <String, String>{
  'x': '<path d="M6 6l12 12M18 6 6 18"/>',
  'shuffle':
      '<path d="M3 7h4l9 10h5M3 17h4l9-10h5"/><path d="M18 4l3 3-3 3M18 14l3 3-3 3"/>',
  'cut':
      '<rect x="3" y="3" width="10" height="13" rx="1.5"/><rect x="11" y="8" width="10" height="13" rx="1.5"/>',
  'fan': '<path d="M12 21 4 9M12 21 8.5 6M12 21l3.5-15M12 21l8-12"/>',
  'spread':
      '<rect x="2.5" y="7" width="5.5" height="9" rx="1"/><rect x="9.25" y="4" width="5.5" height="9" rx="1"/><rect x="16" y="7" width="5.5" height="9" rx="1"/>',
  'deal':
      '<rect x="3" y="6" width="8" height="12" rx="1.5"/><path d="M14 12h7M18 9l3 3-3 3"/>',
  'collect':
      '<rect x="13" y="6" width="8" height="12" rx="1.5"/><path d="M3 12h7M7 9l3 3-3 3"/>',
  'reveal':
      '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'read':
      '<path d="M3 5h6a3 3 0 0 1 3 3v12a2 2 0 0 0-2-2H3zM21 5h-6a3 3 0 0 0-3 3v12a2 2 0 0 1 2-2h7z"/>',
  'turn': '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 3.5v5h-5"/>',
  'aside':
      '<rect x="7" y="11" width="10" height="10" rx="1.5"/><path d="M12 8V2M9 5l3-3 3 3"/>',
  'riffle':
      '<path d="M4 5h6M4 9h6M4 13h6M14 11h6M14 15h6M14 19h6"/><path d="M10 7l4 6"/>',
  'over':
      '<rect x="4" y="12" width="16" height="8" rx="1.5"/><path d="M12 10V3M8.5 6.5 12 3l3.5 3.5"/>',
  'wash': '<path d="M12 12a2 2 0 1 1 2-2 5 5 0 1 1-5-5 8 8 0 1 1-6 7"/>',
  'union': '<path d="M4 6h6l3 4h7M4 18h6l3-4h7"/><path d="m17 7 3 3-3 3"/>',
  'order':
      '<rect x="4" y="4" width="11" height="8" rx="1.5"/><rect x="9" y="12" width="11" height="8" rx="1.5"/>',
  'undo': '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
  'seal':
      '<circle cx="12" cy="12" r="8"/><path d="M12 7.5 15.9 14.2H8.1ZM12 16.5 8.1 9.8h7.8Z"/>',
  'gather':
      '<rect x="8" y="8" width="8" height="11" rx="1.5"/><path d="M3 4l4 4M21 4l-4 4M3 21l4-3M21 21l-4-3"/>',
  'hist': '<path d="M4 4h12l4 4v12H4z"/><path d="M8 11h8M8 15h6"/>',
  'circle': '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5"/>',
  'sound':
      '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
};

/// Icono de cada opcion de los radiales. Las tiradas usan todas el mismo.
const _byItem = <String, String>{
  'read': 'read',
  'reveal': 'reveal',
  'reveal-all': 'reveal',
  'turn': 'turn',
  'collect': 'collect',
  'aside': 'aside',
  'shuffle': 'shuffle',
  'cut': 'cut',
  'fan': 'fan',
  'deal': 'deal',
  'take': 'deal',
  'gather': 'collect',
  'spread': 'spread',
  'union': 'union',
  'order': 'order',
  'auto': 'union',
  'cascada': 'riffle',
  'por_encima': 'over',
  'sobre_el_pano': 'wash',
  'seal': 'seal',
  'all': 'gather',
  'hist': 'hist',
  'sound': 'sound',
  'close': 'circle',
  'drop': 'gather',
  'undo': 'undo',
};

class TableIcon extends StatelessWidget {
  const TableIcon(this.item, {super.key, required this.color, this.size = 24});

  /// Id de la opcion del radial (o del icono directamente).
  final String item;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = _paths[_byItem[item] ?? item] ?? _paths['spread']!;
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.6" '
      'stroke-linecap="round" stroke-linejoin="round">$path</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
