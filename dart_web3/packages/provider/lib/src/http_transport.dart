import 'dart:convert';

import 'package:http/http.dart' as http;

import 'transport.dart';

/// HTTP transport for JSON-RPC communication.
class HttpTransport implements Transport {
  /// The RPC endpoint URL.
  final String url;

  /// Custom HTTP headers.
  final Map<String, String> headers;

  /// Request timeout.
  final Duration timeout;

  final http.Client _client;
  int _requestId = 0;

  HttpTransport(
    this.url, {
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    final requestId = ++_requestId;
    final body = json.encode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params,
    });

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw RpcError(-32000, 'HTTP error: ${response.statusCode}');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;

    if (result.containsKey('error')) {
      throw RpcError.fromJson(result['error'] as Map<String, dynamic>);
    }

    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    final batch = requests.map((r) => r.toJson(++_requestId)).toList();
    final body = json.encode(batch);

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw RpcError(-32000, 'HTTP error: ${response.statusCode}');
    }

    final results = json.decode(response.body) as List;
    return results.cast<Map<String, dynamic>>();
  }

  @override
  void dispose() {
    _client.close();
  }
}
