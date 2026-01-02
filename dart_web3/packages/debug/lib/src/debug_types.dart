import 'package:dart_web3_core/dart_web3_core.dart';

/// Trace configuration
class TraceConfig {

  const TraceConfig({
    this.disableStorage = false,
    this.disableMemory = false,
    this.disableStack = false,
    this.tracer,
    this.tracerConfig,
  });
  final bool disableStorage;
  final bool disableMemory;
  final bool disableStack;
  final String? tracer;
  final Map<String, dynamic>? tracerConfig;

  Map<String, dynamic> toJson() {
    return {
      if (disableStorage) 'disableStorage': true,
      if (disableMemory) 'disableMemory': true,
      if (disableStack) 'disableStack': true,
      if (tracer != null) 'tracer': tracer,
      if (tracerConfig != null) 'tracerConfig': tracerConfig,
    };
  }
}

/// State override set
class StateOverride {

  const StateOverride({
    this.balance,
    this.nonce,
    this.code,
    this.state,
    this.stateDiff,
  });
  final BigInt? balance;
  final BigInt? nonce;
  final String? code;
  final Map<String, String>? state;
  final Map<String, String>? stateDiff;

  Map<String, dynamic> toJson() {
    return {
      if (balance != null) 'balance': HexUtils.encode(BytesUtils.bigIntToBytes(balance!)),
      if (nonce != null) 'nonce': HexUtils.encode(BytesUtils.bigIntToBytes(nonce!)),
      if (code != null) 'code': code,
      if (state != null) 'state': state,
      if (stateDiff != null) 'stateDiff': stateDiff,
    };
  }
}

/// Trace result
class TraceResult {

  const TraceResult({
    this.output,
    this.error,
  });

  factory TraceResult.fromJson(Map<String, dynamic> json) {
    return TraceResult(
      output: json['output'] ?? json['result'],
      error: json['error'] != null ? TraceResultError.fromJson(json['error'] as String) : null,
    );
  }
  final dynamic output;
  final TraceResultError? error;
}

class TraceResultError {

  const TraceResultError(this.message);

  factory TraceResultError.fromJson(String message) {
    return TraceResultError(message);
  }
  final String message;
}
