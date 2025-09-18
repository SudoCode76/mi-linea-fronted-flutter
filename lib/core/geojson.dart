import 'dart:ui';

class LngLat {
  final double lng;
  final double lat;
  const LngLat(this.lng, this.lat);
}

class GeoLine {
  final List<LngLat> points;
  final Color color;
  final double width;
  GeoLine(this.points, {required this.color, this.width = 3});
}

List<LngLat> _coordsFromList(dynamic coords) {
  final List<LngLat> pts = [];
  if (coords is List && coords.isNotEmpty) {
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        pts.add(LngLat(lng, lat));
      }
    }
  }
  return pts;
}

List<GeoLine> parseGeoJsonLine(dynamic geojson, {required Color color, double width = 4}) {
  final List<GeoLine> lines = [];
  if (geojson == null) return lines;

  if (geojson is Map && geojson['type'] == 'Feature') {
    return parseGeoJsonLine(geojson['geometry'], color: color, width: width);
  }
  if (geojson is Map && geojson['type'] == 'FeatureCollection') {
    final feats = (geojson['features'] as List?) ?? [];
    for (final f in feats) {
      lines.addAll(parseGeoJsonLine(f, color: color, width: width));
    }
    return lines;
  }
  if (geojson is Map && geojson['type'] == 'LineString') {
    final pts = _coordsFromList(geojson['coordinates']);
    if (pts.length >= 2) lines.add(GeoLine(pts, color: color, width: width));
  } else if (geojson is Map && geojson['type'] == 'MultiLineString') {
    final arr = (geojson['coordinates'] as List?) ?? [];
    for (final seg in arr) {
      final pts = _coordsFromList(seg);
      if (pts.length >= 2) lines.add(GeoLine(pts, color: color, width: width));
    }
  }
  return lines;
}

Color colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  final v = int.parse('FF$h', radix: 16);
  return Color(v);
}