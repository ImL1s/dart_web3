import 'dart:async';
import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'debug_types.dart';

/// Service for Debug and Trace API
class DebugService {
  DebugService(this._provider);
  final RpcProvider _provider;

  /// Trace a transaction execution
  Future<TraceResult> traceTransaction(
    String txHash, {
    TraceConfig? config,
  }) async {
    final result = await _provider.call<Map<String, dynamic>>(
      'debug_traceTransaction',
      [txHash, if (config != null) config.toJson()],
    );
    return TraceResult.fromJson(result);
  }

  /// Trace a call
  Future<TraceResult> traceCall(
    Map<String, dynamic> call,
    String blockNumber, {
    TraceConfig? config,
  }) async {
    final result = await _provider.call<Map<String, dynamic>>(
      'debug_traceCall',
      [call, blockNumber, if (config != null) config.toJson()],
    );
    return TraceResult.fromJson(result);
  }
}
