class DirectionRoute {
  final Map<String, dynamic>? geometry;
  final int segments;
  final int lengthMTotal;

  // Meta opcional
  final Map<String, dynamic>? direction;

  DirectionRoute({
    required this.geometry,
    required this.segments,
    required this.lengthMTotal,
    this.direction,
  });

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final di = int.tryParse(v);
      if (di != null) return di;
      final dd = double.tryParse(v);
      if (dd != null) return dd.round();
    }
    return 0;
  }

  static Map<String, dynamic>? _asMapOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  factory DirectionRoute.fromJson(Map<String, dynamic> j) => DirectionRoute(
    geometry: _asMapOrNull(j['geometry']),
    segments: _asInt(j['segments']),
    lengthMTotal: _asInt(j['length_m_total']),
    direction: _asMapOrNull(j['direction']),
  );
}