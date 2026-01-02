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

  RpcRequest(this.method, this.params, [this.id]);
  /// The RPC method name.
  final String method;

  /// The method parameters.
  final List<dynamic> params;

  /// Optional request ID.
  final String? id;

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

  RpcError(this.code, this.message, [this.data]);

  factory RpcError.fromJson(Map<String, dynamic> json) {
    return RpcError(
      json['code'] as int,
      json['message'] as String,
      json['data'],
    );
  }
  /// Error code.
  final int code;

  /// Error message.
  final String message;

  /// Optional error data.
  final dynamic data;

  @override
  String toString() => 'RpcError($code): $message';
}
