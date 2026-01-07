import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for interacting with JSON-RPC endpoints
class RpcService {
  final String _nodeUrl;
  final http.Client _client;

  /// Creates a new [RpcService] instance.
  /// 
  /// [nodeUrl] is the RPC endpoint URL.
  /// [client] is an optional http client for testing or custom configuration.
  RpcService(this._nodeUrl, {http.Client? client})
      : _client = client ?? http.Client();

  /// Performs a JSON-RPC call.
  /// 
  /// [method] is the RPC method name (e.g., 'eth_getBalance').
  /// [params] is a list of parameters for the method.
  /// 
  /// Returns the 'result' field of the response.
  /// Throws [Exception] on HTTP error or RPC error.
  Future<dynamic> call(String method, [List<dynamic>? params]) async {
    final payload = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': method,
      'params': params ?? [],
    };

    final response = await _client.post(
      Uri.parse(_nodeUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('RPC call failed with status: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data.containsKey('error')) {
      final error = data['error'];
      throw Exception('RPC Error: ${error['code']} - ${error['message']}');
    }

    return data['result'];
  }

  /// Helper to get balance for an address
  Future<BigInt> getBalance(String address) async {
    final result = await call('eth_getBalance', [address, 'latest']);
    return BigInt.parse(result as String);
  }

  /// Helper to get block number
  Future<int> getBlockNumber() async {
    final result = await call('eth_blockNumber');
    return int.parse(result as String);
  }
}
