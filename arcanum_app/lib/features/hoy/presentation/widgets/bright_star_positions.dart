import 'dart:math' as math;

class BrightStar {
  const BrightStar(
    this.name,
    this.rightAscensionHours,
    this.declination,
    this.magnitude,
  );

  final String name;
  final double rightAscensionHours;
  final double declination;
  final double magnitude;
}

class ApparentStar {
  const ApparentStar({
    required this.star,
    required this.altitude,
    required this.azimuth,
  });

  final BrightStar star;
  final double altitude;
  final double azimuth;
}

/// Catalogo de estrellas brillantes; coordenadas ICRS/J2000 consultadas en SIMBAD.
class BrightStarPositions {
  static const _catalog = <BrightStar>[
    BrightStar('Sirius', 6.752478, -16.716122, -1.46),
    BrightStar('Canopus', 6.399197, -52.695661, -0.74),
    BrightStar('Alpha Centauri', 14.660137, -60.833993, -0.27),
    BrightStar('Vega', 18.615649, 38.783689, 0.03),
    BrightStar('Arcturus', 14.261020, 19.182409, -0.05),
    BrightStar('Rigel', 5.242298, -8.201638, 0.13),
    BrightStar('Capella', 5.278155, 45.997991, 0.08),
    BrightStar('Procyon', 7.655033, 5.224988, 0.37),
    BrightStar('Altair', 19.846389, 8.868321, 0.76),
    BrightStar('Deneb', 20.690532, 45.280339, 1.25),
  ];

  static List<ApparentStar> visibleAt({
    required DateTime utc,
    required double latitude,
    required double longitude,
  }) {
    final jd = utc.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
    final d = jd - 2451545.0;
    final t = d / 36525;
    final gmst = _wrapDegrees(
      280.46061837 +
          360.98564736629 * d +
          0.000387933 * t * t -
          t * t * t / 38710000,
    );
    final lst = _wrapDegrees(gmst + longitude);
    final lat = _radians(latitude);
    final stars = <ApparentStar>[];

    for (final star in _catalog) {
      final dec = _radians(star.declination);
      final hourAngle = _radians(
        _wrapSignedDegrees(lst - star.rightAscensionHours * 15),
      );
      final altitude = math.asin(
        math.sin(lat) * math.sin(dec) +
            math.cos(lat) * math.cos(dec) * math.cos(hourAngle),
      );
      final altitudeDegrees = _degrees(altitude);
      if (altitudeDegrees <= 0) continue;

      final azimuth = math.atan2(
        -math.sin(hourAngle) * math.cos(dec),
        math.sin(dec) * math.cos(lat) -
            math.cos(dec) * math.sin(lat) * math.cos(hourAngle),
      );
      stars.add(
        ApparentStar(
          star: star,
          altitude: altitudeDegrees,
          azimuth: _wrapDegrees(_degrees(azimuth)),
        ),
      );
    }

    stars.sort((a, b) => a.star.magnitude.compareTo(b.star.magnitude));
    return List.unmodifiable(stars.take(4));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
  static double _degrees(double radians) => radians * 180 / math.pi;

  static double _wrapDegrees(double value) => (value % 360 + 360) % 360;

  static double _wrapSignedDegrees(double value) {
    final wrapped = _wrapDegrees(value);
    return wrapped > 180 ? wrapped - 360 : wrapped;
  }
}
