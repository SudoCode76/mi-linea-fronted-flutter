import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mi_linea/core/env.dart';
import '../models/fastest_option.dart';
import '../models/direction_route.dart';
import '../models/line_item.dart';

class BackendService {
  final String base = AppEnv.baseUrl;

  Uri _u(String p, [Map<String, dynamic>? q]) =>
      Uri.parse('$base$p').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
      );

  Future<List<LineItem>> getLines() async {
    final url = _u('/lines');
    // ignore: avoid_print
    print('HTTP GET $url');
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 12));
      // ignore: avoid_print
      print('HTTP $url -> ${r.statusCode}');
      if (r.statusCode >= 400) {
        throw HttpException('GET /lines -> ${r.statusCode} ${r.body}');
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (json['data'] as List?) ?? [];
      return list
          .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('ERROR GET $url: $e');
      rethrow;
    }
  }

  Future<List<FastestOption>> fastest({
    required double oLng,
    required double oLat,
    required double dLng,
    required double dLat,
  }) async {
    final url = _u('/routes/fastest');
    final bodyMap = {
      'origin': {'lng': oLng, 'lat': oLat},
      'destination': {'lng': dLng, 'lat': dLat},
      'threshold_m': AppEnv.fastestThresholdM,
    };
    // ignore: avoid_print
    print('HTTP POST $url body=$bodyMap');
    try {
      final r = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      )
          .timeout(const Duration(seconds: 15));
      // ignore: avoid_print
      print('HTTP $url -> ${r.statusCode}');
      if (r.statusCode >= 400) {
        throw HttpException('POST /routes/fastest -> ${r.statusCode} ${r.body}');
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (json['results'] as List?) ?? [];
      return list
          .map((e) => FastestOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('ERROR POST $url: $e');
      rethrow;
    }
  }

  Future<DirectionRoute> directionRoute(int directionId) async {
    final url = _u('/directions/$directionId/route');
    // ignore: avoid_print
    print('HTTP GET $url');
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 12));
      // ignore: avoid_print
      print('HTTP $url -> ${r.statusCode}');
      if (r.statusCode >= 400) {
        throw HttpException('GET /directions/$directionId/route -> ${r.statusCode} ${r.body}');
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return DirectionRoute.fromJson(json);
    } catch (e) {
      // ignore: avoid_print
      print('ERROR GET $url: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> chatAsk({
    required String message,
    double? oLng,
    double? oLat,
  }) async {
    final url = _u('/chat');
    final bodyMap = {
      'message': message,
      if (oLng != null && oLat != null) 'origin': {'lng': oLng, 'lat': oLat},
      'threshold_m': AppEnv.fastestThresholdM,
    };
    // ignore: avoid_print
    print('HTTP POST $url body=$bodyMap');
    try {
      final r = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      )
          .timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('HTTP $url -> ${r.statusCode}');
      if (r.statusCode >= 400) {
        throw HttpException('POST /chat -> ${r.statusCode} ${r.body}');
      }
      return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (e) {
      // ignore: avoid_print
      print('ERROR POST $url: $e');
      rethrow;
    }
  }
}