import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

class ApiClient {
  final http.Client _client = http.Client();
  final String base = AppEnv.baseUrl;

  Uri _u(String p, [Map<String, dynamic>? q]) => Uri.parse('$base$p').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final r = await _client.get(_u(path, query), headers: {'Accept': 'application/json'});
    if (r.statusCode >= 400) {
      throw Exception('GET $path -> ${r.statusCode} ${r.body}');
    }
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final r = await _client.post(_u(path),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body ?? {}));
    if (r.statusCode >= 400) {
      throw Exception('POST $path -> ${r.statusCode} ${r.body}');
    }
    return jsonDecode(r.body);
  }
}