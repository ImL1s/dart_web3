/// Base exception for all Dart Web3 SDK errors.
abstract class Web3Exception implements Exception {
  /// Human-readable error message.
  String get message;

  /// Optional error code for programmatic handling.
  String? get code;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

/// Exception thrown when an invalid address is encountered.
class InvalidAddressException extends Web3Exception {
  /// The invalid address string.
  final String address;

  /// Optional reason for invalidity.
  final String? reason;

  InvalidAddressException(this.address, [this.reason]);

  @override
  String get message =>
      reason != null ? 'Invalid address "$address": $reason' : 'Invalid address: $address';

  @override
  String get code => 'INVALID_ADDRESS';
}

/// Exception thrown when hex encoding/decoding fails.
class HexException extends Web3Exception {
  @override
  final String message;

  HexException(this.message);

  @override
  String get code => 'HEX_ERROR';
}

/// Exception thrown when RLP encoding/decoding fails.
class RlpException extends Web3Exception {
  @override
  final String message;

  RlpException(this.message);

  @override
  String get code => 'RLP_ERROR';
}

/// Exception thrown when unit conversion fails.
class UnitConversionException extends Web3Exception {
  @override
  final String message;

  UnitConversionException(this.message);

  @override
  String get code => 'UNIT_CONVERSION_ERROR';
}
