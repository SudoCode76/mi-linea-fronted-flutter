class LineItem {
  final int lineDirectionId;
  final String lineName;
  final String code;
  final String headsign;
  final String direction;
  final String colorHex;

  // Opcionalmente, datos adicionales por si los usas luego
  final int? lineId;
  final double? avgSpeedKmh;
  final int? waitMinutes;

  LineItem({
    required this.lineDirectionId,
    required this.lineName,
    required this.code,
    required this.headsign,
    required this.direction,
    required this.colorHex,
    this.lineId,
    this.avgSpeedKmh,
    this.waitMinutes,
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

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final di = int.tryParse(v);
      if (di != null) return di;
      final dd = double.tryParse(v);
      if (dd != null) return dd.round();
    }
    return null;
  }

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    lineDirectionId: _asInt(j['line_direction_id']),
    lineName: (j['name'] ?? j['line_name'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    headsign: (j['headsign'] ?? '').toString(),
    direction: (j['direction'] ?? '').toString(),
    colorHex: (j['color_hex'] ?? '#2196F3').toString(),
    lineId: _asIntOrNull(j['line_id']),
    avgSpeedKmh: _asDoubleOrNull(j['avg_speed_kmh']),
    waitMinutes: _asIntOrNull(j['wait_minutes']),
  );
}