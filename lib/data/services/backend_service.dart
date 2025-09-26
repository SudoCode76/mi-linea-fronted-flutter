import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:mi_linea/core/env.dart';
import '../models/fastest_option.dart';
import '../models/direction_route.dart';
import '../models/line_item.dart';

/// Servicio central para llamadas al backend.
/// Mantiene un session_id simple en memoria para el flujo del chat.
class BackendService {
  final String base = AppEnv.baseUrl;

  // Session id simple (memoria). Se podría persistir con shared_preferences.
  static String? _sessionId;
  static String get sessionId {
    if (_sessionId == null) {
      final rnd = Random();
      final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final rand = List.generate(6, (_) => rnd.nextInt(36))
          .map((n) => n.toRadixString(36))
          .join();
      _sessionId = 'f_$stamp$rand';
    }
    return _sessionId!;
  }

  Uri _u(String p, [Map<String, dynamic>? q]) =>
      Uri.parse('$base$p').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
      );

  // --------------------------------------------------
  // LÍNEAS / DIRECCIONES
  // --------------------------------------------------
  /// Obtiene listado de direcciones de líneas.
  /// Si se pasa [query] agrega ?q= para que el backend filtre (code, name, headsign).
  Future<List<LineItem>> getLines({String? query}) async {
    final qp = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }
    final url = _u('/lines/directions', qp.isEmpty ? null : qp);
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 12));
      if (r.statusCode >= 400) {
        throw HttpException(
            'GET /lines/directions -> ${r.statusCode} ${r.body}');
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (json['data'] as List?) ?? [];
      return list
          .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // --------------------------------------------------
  // RUTA MÁS RÁPIDA (cálculo directo sin chat)
  // --------------------------------------------------
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
    try {
      final r = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 400) {
        throw HttpException(
            'POST /routes/fastest -> ${r.statusCode} ${r.body}');
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (json['results'] as List?) ?? [];
      return list
          .map((e) => FastestOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // --------------------------------------------------
  // DETALLE DE DIRECCIÓN (shape completo)
  // --------------------------------------------------
  Future<DirectionRoute> directionRoute(int directionId) async {
    final url = _u('/directions/$directionId/route');
    final r = await http.get(url).timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) {
      throw HttpException(
          'GET /directions/$directionId/route -> ${r.statusCode} ${r.body}');
    }
    final json = jsonDecode(r.body) as Map<String, dynamic>;
    return DirectionRoute.fromJson(json);
  }

  // --------------------------------------------------
  // CHAT (flujo conversacional con intent + rutas)
  // --------------------------------------------------
  Future<Map<String, dynamic>> chatAsk({
    required String message,
    double? oLng,
    double? oLat,
  }) async {
    final url = _u('/chat');
    final bodyMap = {
      'message': message,
      'session_id': sessionId,
      if (oLng != null && oLat != null)
        'origin': {
          'lng': oLng,
          'lat': oLat,
        },
      'threshold_m': AppEnv.fastestThresholdM,
    };
    try {
      final r = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode >= 400) {
        throw HttpException('POST /chat -> ${r.statusCode} ${r.body}');
      }
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'ok': false, 'error': 'Respuesta inesperada'};
    } catch (e) {
      rethrow;
    }
  }
}