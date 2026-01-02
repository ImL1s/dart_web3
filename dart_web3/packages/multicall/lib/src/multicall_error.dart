import 'dart:typed_data';

/// Base class for multicall-related errors.
abstract class MulticallError implements Exception {
  
  const MulticallError(this.message);
  /// Error message.
  final String message;
  
  @override
  String toString() => 'MulticallError: $message';
}

/// Error thrown when a multicall operation is not supported.
class UnsupportedMulticallError extends MulticallError {
  
  const UnsupportedMulticallError({
    required this.chainId,
    required this.operation,
  }) : super('$operation is not supported on chain $chainId');
  /// The chain ID that doesn't support the operation.
  final int chainId;
  
  /// The operation that is not supported.
  final String operation;
}

/// Error thrown when individual calls in a multicall batch fail.
class MulticallExecutionError extends MulticallError {
  
  const MulticallExecutionError(this.failures)
      : super('${failures.length} call(s) failed in multicall batch');
  /// The failed call results.
  final List<CallFailure> failures;
}

/// Represents a failed call in a multicall batch.
class CallFailure {
  
  const CallFailure({
    required this.index,
    required this.target,
    required this.callData,
    required this.errorData,
    this.errorMessage,
  });
  /// The index of the failed call in the batch.
  final int index;
  
  /// The target contract address.
  final String target;
  
  /// The call data that failed.
  final Uint8List callData;
  
  /// The error data returned by the call.
  final Uint8List errorData;
  
  /// The decoded error message, if available.
  final String? errorMessage;
  
  @override
  String toString() {
    final msg = errorMessage ?? 'Unknown error';
    return 'Call $index to $target failed: $msg';
  }
}

/// Error thrown when multicall encoding/decoding fails.
class MulticallEncodingError extends MulticallError {
  
  const MulticallEncodingError({
    required this.operation,
    this.cause,
  }) : super('Failed to $operation multicall data');
  /// The operation that failed (encode/decode).
  final String operation;
  
  /// The underlying error, if any.
  final Object? cause;
  
  @override
  String toString() {
    final causeStr = cause != null ? ': $cause' : '';
    return 'MulticallEncodingError: $message$causeStr';
  }
}

/// Error thrown when multicall contract is not found or not deployed.
class MulticallContractError extends MulticallError {
  
  const MulticallContractError({
    required this.chainId,
    required this.contractAddress,
  }) : super('Multicall contract not found at $contractAddress on chain $chainId');
  /// The chain ID where the contract was not found.
  final int chainId;
  
  /// The contract address that was not found.
  final String contractAddress;
}
