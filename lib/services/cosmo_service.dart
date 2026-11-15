import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CosmoException implements Exception {
  final String code;
  const CosmoException(this.code);
}

class CosmoService {
  final http.Client _client;
  final Uri? proxyUrl;
  final Duration timeout;
  CosmoService({
    http.Client? client,
    Uri? proxyUrl,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       proxyUrl = proxyUrl ?? _configuredUrl();

  static Uri? _configuredUrl() {
    const value = String.fromEnvironment('COSMO_PROXY_URL');
    return value.isEmpty ? null : Uri.tryParse(value);
  }

  bool get configured {
    final url = proxyUrl;
    if (url == null ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        url.hasQuery)
      return false;
    return url.scheme == 'https' ||
        (url.scheme == 'http' &&
            ['localhost', '127.0.0.1', '::1'].contains(url.host));
  }

  Future<String> ask(String question, {required bool arabic}) async {
    final message = question.trim();
    if (message.isEmpty) throw const CosmoException('empty_question');
    if (message.length > 2000) throw const CosmoException('question_too_long');
    if (!configured) throw const CosmoException('not_configured');
    try {
      final response = await _client
          .post(
            proxyUrl!,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'language': arabic ? 'ar' : 'en',
            }),
          )
          .timeout(timeout);
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const CosmoException('invalid_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = data is Map ? data['error'] : null;
        const allowed = {
          'not_configured',
          'rate_limited',
          'timeout',
          'provider_auth',
          'question_too_long',
          'upstream_error',
        };
        throw CosmoException(
          allowed.contains(code) ? code as String : 'connection',
        );
      }
      final answer = data is Map ? data['answer'] : null;
      if (answer is! String || answer.trim().isEmpty || answer.length > 16000)
        throw const CosmoException('invalid_response');
      return answer.trim();
    } on TimeoutException {
      throw const CosmoException('timeout');
    } on http.ClientException {
      throw const CosmoException('connection');
    }
  }

  void close() => _client.close();
}
