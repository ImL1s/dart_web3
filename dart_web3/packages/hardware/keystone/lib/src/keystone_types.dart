import 'dart:typed_data';

/// Keystone device information
class KeystoneDevice {
  final String deviceId;
  final String name;
  final String version;
  final List<String> supportedCurves;
  
  KeystoneDevice({
    required this.deviceId,
    required this.name,
    required this.version,
    required this.supportedCurves,
  });
}

/// Keystone account information
class KeystoneAccount {
  final String address;
  final String derivationPath;
  final Uint8List publicKey;
  final String? name;
  
  KeystoneAccount({
    required this.address,
    required this.derivationPath,
    required this.publicKey,
    this.name,
  });
}

/// Keystone signing request
class KeystoneSignRequest {
  final Uint8List requestId;
  final Uint8List data;
  final KeystoneDataType dataType;
  final String derivationPath;
  final int? chainId;
  
  KeystoneSignRequest({
    required this.requestId,
    required this.data,
    required this.dataType,
    required this.derivationPath,
    this.chainId,
  });
}

/// Keystone signing response
class KeystoneSignResponse {
  final Uint8List requestId;
  final Uint8List signature;
  final String? error;
  
  KeystoneSignResponse({
    required this.requestId,
    required this.signature,
    this.error,
  });
  
  bool get isSuccess => error == null;
}

/// Types of data that can be signed
enum KeystoneDataType {
  transaction(1),
  typedData(2),
  personalMessage(3);
  
  const KeystoneDataType(this.value);
  final int value;
}

/// QR communication state
enum QRCommunicationState {
  idle,
  displayingRequest,
  waitingForResponse,
  scanningResponse,
  completed,
  error,
}

/// QR scan result
class QRScanResult {
  final String data;
  final DateTime timestamp;
  
  QRScanResult({
    required this.data,
    required this.timestamp,
  });
}

/// Multi-part QR progress
class QRProgress {
  final int currentPart;
  final int totalParts;
  final double percentage;
  
  QRProgress({
    required this.currentPart,
    required this.totalParts,
  }) : percentage = totalParts > 0 ? currentPart / totalParts : 0.0;
  
  bool get isComplete => currentPart >= totalParts;
}

/// Keystone error types
enum KeystoneErrorType {
  deviceNotFound,
  communicationTimeout,
  userCancelled,
  invalidRequest,
  signingFailed,
  unsupportedOperation,
  qrCodeError,
}

/// Keystone exception
class KeystoneException implements Exception {
  final KeystoneErrorType type;
  final String message;
  final dynamic originalError;
  
  KeystoneException(this.type, this.message, [this.originalError]);
  
  @override
  String toString() {
    return 'KeystoneException: $message (type: $type)';
  }
}