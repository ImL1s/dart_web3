/// Abstract transport interface for RPC communication.
abstract class Transport {
  /// Sends a single RPC request.
  Future<Map<String, dynamic>> request(String method, List<dynamic> params);

  /// Sends multiple RPC requests in a batch.
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests);

  /// Disposes of the transport resources.
  void dispose();
}

/// Represents a single RPC request.
class RpcRequest {
  /// The RPC method name.
  final String method;

  /// The method parameters.
  final List<dynamic> params;

  /// Optional request ID.
  final String? id;

  RpcRequest(this.method, this.params, [this.id]);

  /// Converts to JSON-RPC format.
  Map<String, dynamic> toJson(int requestId) => {
        'jsonrpc': '2.0',
        'id': id ?? requestId,
        'method': method,
        'params': params,
      };
}

/// RPC error response.
class RpcError implements Exception {
  /// Error code.
  final int code;

  /// Error message.
  final String message;

  /// Optional error data.
  final dynamic data;

  RpcError(this.code, this.message, [this.data]);

  @override
  String toString() => 'RpcError($code): $message';

  factory RpcError.fromJson(Map<String, dynamic> json) {
    return RpcError(
      json['code'] as int,
      json['message'] as String,
      json['data'],
    );
  }
}
