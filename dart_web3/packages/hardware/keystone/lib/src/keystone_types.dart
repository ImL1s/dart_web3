import 'dart:typed_data';

/// Keystone device information
class KeystoneDevice {
  
  KeystoneDevice({
    required this.deviceId,
    required this.name,
    required this.version,
    required this.supportedCurves,
  });
  final String deviceId;
  final String name;
  final String version;
  final List<String> supportedCurves;
}

/// Keystone account information
class KeystoneAccount {
  
  KeystoneAccount({
    required this.address,
    required this.derivationPath,
    required this.publicKey,
    this.name,
  });
  final String address;
  final String derivationPath;
  final Uint8List publicKey;
  final String? name;
}

/// Keystone signing request
class KeystoneSignRequest {
  
  KeystoneSignRequest({
    required this.requestId,
    required this.data,
    required this.dataType,
    required this.derivationPath,
    this.chainId,
  });
  final Uint8List requestId;
  final Uint8List data;
  final KeystoneDataType dataType;
  final String derivationPath;
  final int? chainId;
}

/// Keystone signing response
class KeystoneSignResponse {
  
  KeystoneSignResponse({
    required this.requestId,
    required this.signature,
    this.error,
  });
  final Uint8List requestId;
  final Uint8List signature;
  final String? error;
  
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
  
  QRScanResult({
    required this.data,
    required this.timestamp,
  });
  final String data;
  final DateTime timestamp;
}

/// Multi-part QR progress
class QRProgress {
  
  QRProgress({
    required this.currentPart,
    required this.totalParts,
  }) : percentage = totalParts > 0 ? currentPart / totalParts : 0.0;
  final int currentPart;
  final int totalParts;
  final double percentage;
  
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
  
  KeystoneException(this.type, this.message, [this.originalError]);
  final KeystoneErrorType type;
  final String message;
  final dynamic originalError;
  
  @override
  String toString() {
    return 'KeystoneException: $message (type: $type)';
  }
}
