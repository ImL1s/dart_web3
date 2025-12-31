import 'dart:typed_data';

/// Ledger device information
class LedgerDevice {
  final String deviceId;
  final String name;
  final String version;
  final LedgerTransportType transportType;
  final bool isConnected;
  
  LedgerDevice({
    required this.deviceId,
    required this.name,
    required this.version,
    required this.transportType,
    this.isConnected = false,
  });
  
  @override
  String toString() {
    return 'LedgerDevice(id: $deviceId, name: $name, transport: $transportType)';
  }
}

/// Ledger transport types
enum LedgerTransportType {
  usb,
  ble,
  webusb,
}

/// Ledger application information
class LedgerApp {
  final String name;
  final String version;
  final bool isOpen;
  
  LedgerApp({
    required this.name,
    required this.version,
    this.isOpen = false,
  });
}

/// Ledger account information
class LedgerAccount {
  final String address;
  final String derivationPath;
  final Uint8List publicKey;
  final int index;
  
  LedgerAccount({
    required this.address,
    required this.derivationPath,
    required this.publicKey,
    required this.index,
  });
}

/// APDU command structure
class APDUCommand {
  final int cla; // Class byte
  final int ins; // Instruction byte
  final int p1;  // Parameter 1
  final int p2;  // Parameter 2
  final Uint8List? data; // Command data
  final int? le; // Expected response length
  
  APDUCommand({
    required this.cla,
    required this.ins,
    required this.p1,
    required this.p2,
    this.data,
    this.le,
  });
  
  /// Serialize APDU command to bytes
  Uint8List toBytes() {
    final buffer = <int>[];
    
    // Header
    buffer.addAll([cla, ins, p1, p2]);
    
    // Data length and data
    if (data != null && data!.isNotEmpty) {
      buffer.add(data!.length);
      buffer.addAll(data!);
    } else {
      buffer.add(0);
    }
    
    // Expected response length
    if (le != null) {
      buffer.add(le!);
    }
    
    return Uint8List.fromList(buffer);
  }
}

/// APDU response structure
class APDUResponse {
  final Uint8List data;
  final int statusWord;
  
  APDUResponse({
    required this.data,
    required this.statusWord,
  });
  
  /// Check if response indicates success
  bool get isSuccess => statusWord == 0x9000;
  
  /// Get status word as two bytes
  List<int> get statusBytes => [
    (statusWord >> 8) & 0xFF,
    statusWord & 0xFF,
  ];
  
  /// Get error message for status word
  String? get errorMessage {
    switch (statusWord) {
      case 0x9000:
        return null; // Success
      case 0x6985:
        return 'User denied the request';
      case 0x6A80:
        return 'Invalid data';
      case 0x6A82:
        return 'File not found';
      case 0x6A86:
        return 'Incorrect parameters P1-P2';
      case 0x6D00:
        return 'Instruction not supported';
      case 0x6E00:
        return 'Class not supported';
      case 0x6F00:
        return 'Technical problem';
      default:
        return 'Unknown error: 0x${statusWord.toRadixString(16).padLeft(4, '0')}';
    }
  }
}

/// Ledger connection state
enum LedgerConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Ledger error types
enum LedgerErrorType {
  deviceNotFound,
  connectionFailed,
  communicationError,
  userDenied,
  appNotOpen,
  invalidResponse,
  unsupportedOperation,
  timeout,
}

/// Ledger exception
class LedgerException implements Exception {
  final LedgerErrorType type;
  final String message;
  final int? statusWord;
  final dynamic originalError;
  
  LedgerException(
    this.type,
    this.message, {
    this.statusWord,
    this.originalError,
  });
  
  @override
  String toString() {
    final sw = statusWord != null ? ' (SW: 0x${statusWord!.toRadixString(16)})' : '';
    return 'LedgerException: $message$sw (type: $type)';
  }
}

/// Ethereum app configuration
class EthereumAppConfig {
  final bool arbitraryDataEnabled;
  final bool erc20ProvisioningNecessary;
  final String version;
  
  EthereumAppConfig({
    required this.arbitraryDataEnabled,
    required this.erc20ProvisioningNecessary,
    required this.version,
  });
}

/// Signing request for Ledger
class LedgerSignRequest {
  final Uint8List data;
  final String derivationPath;
  final LedgerSignType signType;
  
  LedgerSignRequest({
    required this.data,
    required this.derivationPath,
    required this.signType,
  });
}

/// Types of signing operations
enum LedgerSignType {
  transaction,
  message,
  typedData,
}

/// Ledger signing response
class LedgerSignResponse {
  final Uint8List signature;
  final int v;
  final Uint8List r;
  final Uint8List s;
  
  LedgerSignResponse({
    required this.signature,
    required this.v,
    required this.r,
    required this.s,
  });
  
  /// Get signature as hex string
  String get signatureHex => '0x${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}