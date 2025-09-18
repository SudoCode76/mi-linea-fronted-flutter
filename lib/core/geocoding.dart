import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
import 'geojson.dart';

class GeocodingService {
  // Mapbox Places
  static Future<({LngLat? coord, String? name, String? error})> searchFirst(String query) async {
    final token = AppEnv.mapboxToken;
    if (token.isEmpty) {
      return (coord: null, name: null, error: 'MAPBOX_TOKEN faltante en .env');
    }
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
          '?access_token=$token&limit=1&language=es',
    );
    final resp = await http.get(url);
    if (resp.statusCode >= 400) {
      return (coord: null, name: null, error: 'Geocoding ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final feats = (data['features'] as List?) ?? [];
    if (feats.isEmpty) return (coord: null, name: null, error: 'Sin resultados');
    final f = feats.first as Map<String, dynamic>;
    final center = (f['center'] as List).cast<num>();
    return (coord: LngLat(center[0].toDouble(), center[1].toDouble()), name: f['place_name'] as String?, error: null);
  }
}