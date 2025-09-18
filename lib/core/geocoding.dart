import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';
import 'geojson.dart';

class PlaceSuggestion {
  final String name;
  final LngLat coord;
  const PlaceSuggestion({required this.name, required this.coord});
}

class GeocodingService {
  static String get _token => AppEnv.mapboxToken;

  // Centro de Cochabamba para mejorar relevancia (lon, lat)
  static const double _proxLng = -66.157;
  static const double _proxLat = -17.39;

  // Cabeceras para Nominatim (requeridas por su política)
  static const Map<String, String> _nomHeaders = {
    'User-Agent': 'mi-linea-app/1.0 (contact: example@example.com)'
  };

  static Uri _mapboxForwardUrl(String query, {int limit = 6}) {
    final t = _token;
    return Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
          '?access_token=$t'
          '&limit=$limit'
          '&autocomplete=true'
          '&language=es'
          '&proximity=$_proxLng,$_proxLat'
          '&types=address,street,place,poi',
    );
  }

  static Uri _mapboxReverseUrl(double lng, double lat) {
    final t = _token;
    return Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
          '?access_token=$t'
          '&limit=1'
          '&language=es'
          '&types=address,street,place',
    );
  }

  static Uri _nominatimForwardUrl(String query, {int limit = 6}) {
    return Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeQueryComponent(query)}'
          '&format=jsonv2'
          '&limit=$limit'
          '&addressdetails=0'
          '&accept-language=es',
    );
  }

  static Uri _nominatimReverseUrl(double lng, double lat) {
    return Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2'
          '&lon=$lng'
          '&lat=$lat'
          '&zoom=18'
          '&addressdetails=0'
          '&accept-language=es',
    );
  }

  // Autocomplete: Mapbox -> fallback Nominatim
  static Future<List<PlaceSuggestion>> suggest(String query, {int limit = 6}) async {
    if (_token.isNotEmpty) {
      try {
        final url = _mapboxForwardUrl(query, limit: limit);
        // ignore: avoid_print
        print('GEOCODING suggest(Mapbox) -> $url');
        final resp = await http.get(url);
        // ignore: avoid_print
        print('GEOCODING suggest(Mapbox) <- ${resp.statusCode}');
        if (resp.statusCode < 400) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final feats = (data['features'] as List?) ?? [];
          return feats.map((f) {
            final m = f as Map<String, dynamic>;
            final center = (m['center'] as List).cast<num>();
            final name = (m['place_name'] ?? m['text'] ?? '').toString();
            return PlaceSuggestion(
              name: name,
              coord: LngLat(center[0].toDouble(), center[1].toDouble()),
            );
          }).toList();
        }
      } catch (e) {
        // ignore: avoid_print
        print('GEOCODING suggest(Mapbox) ERROR: $e');
      }
    }

    // Fallback Nominatim
    try {
      final url = _nominatimForwardUrl(query, limit: limit);
      // ignore: avoid_print
      print('GEOCODING suggest(Nominatim) -> $url');
      final resp = await http.get(url, headers: _nomHeaders);
      // ignore: avoid_print
      print('GEOCODING suggest(Nominatim) <- ${resp.statusCode}');
      if (resp.statusCode < 400) {
        final arr = (jsonDecode(resp.body) as List?) ?? const [];
        return arr.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final name = (m['display_name'] ?? m['name'] ?? '').toString();
          final lng = double.tryParse('${m['lon']}') ?? 0.0;
          final lat = double.tryParse('${m['lat']}') ?? 0.0;
          return PlaceSuggestion(name: name, coord: LngLat(lng, lat));
        }).toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('GEOCODING suggest(Nominatim) ERROR: $e');
    }

    return [];
  }

  // Reverse geocoding: Mapbox -> fallback Nominatim
  static Future<String?> reverse(double lng, double lat) async {
    if (_token.isNotEmpty) {
      try {
        final url = _mapboxReverseUrl(lng, lat);
        // ignore: avoid_print
        print('GEOCODING reverse(Mapbox) -> $url');
        final resp = await http.get(url);
        // ignore: avoid_print
        print('GEOCODING reverse(Mapbox) <- ${resp.statusCode}');
        if (resp.statusCode < 400) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final feats = (data['features'] as List?) ?? [];
          if (feats.isNotEmpty) {
            final f = feats.first as Map<String, dynamic>;
            return (f['place_name'] ?? f['text'])?.toString();
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('GEOCODING reverse(Mapbox) ERROR: $e');
      }
    }

    // Fallback Nominatim
    try {
      final url = _nominatimReverseUrl(lng, lat);
      // ignore: avoid_print
      print('GEOCODING reverse(Nominatim) -> $url');
      final resp = await http.get(url, headers: _nomHeaders);
      // ignore: avoid_print
      print('GEOCODING reverse(Nominatim) <- ${resp.statusCode}');
      if (resp.statusCode < 400) {
        final data = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
        final name = (data['display_name'] ?? data['name'])?.toString();
        return name;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GEOCODING reverse(Nominatim) ERROR: $e');
    }

    return null;
  }

  // Búsqueda simple (primera coincidencia)
  static Future<({LngLat? coord, String? name, String? error})> searchFirst(String query) async {
    if (_token.isNotEmpty) {
      try {
        final url = _mapboxForwardUrl(query, limit: 1);
        // ignore: avoid_print
        print('GEOCODING searchFirst(Mapbox) -> $url');
        final resp = await http.get(url);
        // ignore: avoid_print
        print('GEOCODING searchFirst(Mapbox) <- ${resp.statusCode}');
        if (resp.statusCode < 400) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final feats = (data['features'] as List?) ?? [];
          if (feats.isNotEmpty) {
            final f = feats.first as Map<String, dynamic>;
            final center = (f['center'] as List).cast<num>();
            final name = (f['place_name'] ?? f['text'])?.toString();
            return (coord: LngLat(center[0].toDouble(), center[1].toDouble()), name: name, error: null);
          }
          return (coord: null, name: null, error: 'Sin resultados');
        }
      } catch (e) {
        // ignore: avoid_print
        print('GEOCODING searchFirst(Mapbox) ERROR: $e');
      }
    }

    // Fallback Nominatim
    try {
      final url = _nominatimForwardUrl(query, limit: 1);
      // ignore: avoid_print
      print('GEOCODING searchFirst(Nominatim) -> $url');
      final resp = await http.get(url, headers: _nomHeaders);
      // ignore: avoid_print
      print('GEOCODING searchFirst(Nominatim) <- ${resp.statusCode}');
      if (resp.statusCode < 400) {
        final arr = (jsonDecode(resp.body) as List?) ?? const [];
        if (arr.isEmpty) return (coord: null, name: null, error: 'Sin resultados');
        final m = Map<String, dynamic>.from(arr.first as Map);
        final name = (m['display_name'] ?? m['name'])?.toString();
        final lng = double.tryParse('${m['lon']}') ?? 0.0;
        final lat = double.tryParse('${m['lat']}') ?? 0.0;
        return (coord: LngLat(lng, lat), name: name, error: null);
      }
    } catch (e) {
      // ignore: avoid_print
      print('GEOCODING searchFirst(Nominatim) ERROR: $e');
    }

    return (coord: null, name: null, error: 'Error realizando búsqueda');
  }
}