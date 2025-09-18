class FastestOption {
  final int lineDirectionId;
  final String lineName;
  final String code;
  final String colorHex;
  final String direction;
  final String headsign;

  final double rideM;
  final double walkToM;
  final double walkFromM;
  final double etaMinutes;

  // GeoJSONs tal como vienen del backend
  final Map<String, dynamic> segGeom;
  final Map<String, dynamic> walkTo;
  final Map<String, dynamic> walkFrom;

  FastestOption({
    required this.lineDirectionId,
    required this.lineName,
    required this.code,
    required this.colorHex,
    required this.direction,
    required this.headsign,
    required this.rideM,
    required this.walkToM,
    required this.walkFromM,
    required this.etaMinutes,
    required this.segGeom,
    required this.walkTo,
    required this.walkFrom,
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

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  factory FastestOption.fromJson(Map<String, dynamic> j) => FastestOption(
    lineDirectionId: _asInt(j['line_direction_id']),
    lineName: (j['line_name'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    colorHex: (j['color_hex'] ?? '#2196F3').toString(),
    direction: (j['direction'] ?? '').toString(),
    headsign: (j['headsign'] ?? '').toString(),
    rideM: _asDouble(j['ride_m']),
    walkToM: _asDouble(j['walk_to_m']),
    walkFromM: _asDouble(j['walk_from_m']),
    etaMinutes: _asDouble(j['eta_minutes']),
    segGeom: _asMap(j['seg_geom_geojson'] ?? j['seg_geom']),
    walkTo: _asMap(j['walk_to_geojson'] ?? j['walk_to']),
    walkFrom: _asMap(j['walk_from_geojson'] ?? j['walk_from']),
  );
}