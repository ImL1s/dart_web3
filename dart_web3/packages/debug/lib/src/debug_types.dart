import 'package:dart_web3_core/dart_web3_core.dart';

/// Trace configuration
class TraceConfig {
  final bool disableStorage;
  final bool disableMemory;
  final bool disableStack;
  final String? tracer;
  final Map<String, dynamic>? tracerConfig;

  const TraceConfig({
    this.disableStorage = false,
    this.disableMemory = false,
    this.disableStack = false,
    this.tracer,
    this.tracerConfig,
  });

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
  final BigInt? balance;
  final BigInt? nonce;
  final String? code;
  final Map<String, String>? state;
  final Map<String, String>? stateDiff;

  const StateOverride({
    this.balance,
    this.nonce,
    this.code,
    this.state,
    this.stateDiff,
  });

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
  final dynamic output;
  final TraceResultError? error;

  const TraceResult({
    this.output,
    this.error,
  });

  factory TraceResult.fromJson(Map<String, dynamic> json) {
    return TraceResult(
      output: json['output'] ?? json['result'],
      error: json['error'] != null ? TraceResultError.fromJson(json['error']) : null,
    );
  }
}

class TraceResultError {
  final String message;

  const TraceResultError(this.message);

  factory TraceResultError.fromJson(String message) {
    return TraceResultError(message);
  }
}
