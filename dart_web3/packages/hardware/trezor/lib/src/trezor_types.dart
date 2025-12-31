import 'dart:typed_data';

/// Trezor device information
class TrezorDevice {
  final String deviceId;
  final String model;
  final String label;
  final String firmwareVersion;
  final bool isBootloader;
  final bool isConnected;
  
  TrezorDevice({
    required this.deviceId,
    required this.model,
    required this.label,
    required this.firmwareVersion,
    this.isBootloader = false,
    this.isConnected = false,
  });
  
  @override
  String toString() {
    return 'TrezorDevice(model: $model, label: $label, firmware: $firmwareVersion)';
  }
}

/// Trezor device models
enum TrezorModel {
  trezorOne('Trezor One'),
  trezorT('Trezor Model T'),
  trezorSafe3('Trezor Safe 3'),
  unknown('Unknown');
  
  const TrezorModel(this.displayName);
  final String displayName;
}

/// Trezor account information
class TrezorAccount {
  final String address;
  final String derivationPath;
  final Uint8List publicKey;
  final int index;
  final String? label;
  
  TrezorAccount({
    required this.address,
    required this.derivationPath,
    required this.publicKey,
    required this.index,
    this.label,
  });
}

/// Trezor connection state
enum TrezorConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Trezor message types (simplified subset)
enum TrezorMessageType {
  // Management messages
  initialize(0),
  getFeatures(55),
  features(17),
  
  // Ethereum messages
  ethereumGetAddress(56),
  ethereumAddress(57),
  ethereumSignTx(58),
  ethereumTxRequest(59),
  ethereumTxAck(60),
  ethereumSignMessage(64),
  ethereumMessageSignature(65),
  ethereumSignTypedData(464),
  ethereumTypedDataSignature(465),
  
  // Common messages
  success(2),
  failure(3),
  buttonRequest(26),
  buttonAck(27),
  pinMatrixRequest(18),
  pinMatrixAck(19),
  passphraseRequest(41),
  passphraseAck(42);
  
  const TrezorMessageType(this.value);
  final int value;
  
  static TrezorMessageType? fromValue(int value) {
    for (final type in TrezorMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Trezor message structure
class TrezorMessage {
  final TrezorMessageType type;
  final Uint8List data;
  
  TrezorMessage({
    required this.type,
    required this.data,
  });
  
  /// Serialize message to wire format
  Uint8List toWireFormat() {
    final header = Uint8List(9);
    
    // Magic bytes
    header[0] = 0x23;
    header[1] = 0x23;
    
    // Message type (2 bytes, big endian)
    header[2] = (type.value >> 8) & 0xFF;
    header[3] = type.value & 0xFF;
    
    // Data length (4 bytes, big endian)
    final length = data.length;
    header[4] = (length >> 24) & 0xFF;
    header[5] = (length >> 16) & 0xFF;
    header[6] = (length >> 8) & 0xFF;
    header[7] = length & 0xFF;
    
    // Session ID (1 byte)
    header[8] = 0x00;
    
    return Uint8List.fromList([...header, ...data]);
  }
  
  /// Parse message from wire format
  static TrezorMessage fromWireFormat(Uint8List wireData) {
    if (wireData.length < 9) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Invalid wire format: too short',
      );
    }
    
    // Check magic bytes
    if (wireData[0] != 0x23 || wireData[1] != 0x23) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Invalid magic bytes',
      );
    }
    
    // Parse message type
    final typeValue = (wireData[2] << 8) | wireData[3];
    final type = TrezorMessageType.fromValue(typeValue);
    if (type == null) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Unknown message type: $typeValue',
      );
    }
    
    // Parse data length
    final length = (wireData[4] << 24) | 
                   (wireData[5] << 16) | 
                   (wireData[6] << 8) | 
                   wireData[7];
    
    if (wireData.length < 9 + length) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Invalid wire format: data too short',
      );
    }
    
    final data = wireData.sublist(9, 9 + length);
    
    return TrezorMessage(type: type, data: data);
  }
}

/// Trezor signing request
class TrezorSignRequest {
  final Uint8List data;
  final String derivationPath;
  final TrezorSignType signType;
  final int? chainId;
  
  TrezorSignRequest({
    required this.data,
    required this.derivationPath,
    required this.signType,
    this.chainId,
  });
}

/// Types of signing operations
enum TrezorSignType {
  transaction,
  message,
  typedData,
}

/// Trezor signing response
class TrezorSignResponse {
  final Uint8List signature;
  final String address;
  
  TrezorSignResponse({
    required this.signature,
    required this.address,
  });
  
  /// Get signature as hex string
  String get signatureHex => '0x${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

/// Trezor error types
enum TrezorErrorType {
  deviceNotFound,
  connectionFailed,
  communicationError,
  userCancelled,
  pinRequired,
  passphraseRequired,
  firmwareError,
  protocolError,
  unsupportedOperation,
  timeout,
}

/// Trezor exception
class TrezorException implements Exception {
  final TrezorErrorType type;
  final String message;
  final int? code;
  final dynamic originalError;
  
  TrezorException(
    this.type,
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() {
    final codeStr = code != null ? ' (code: $code)' : '';
    return 'TrezorException: $message$codeStr (type: $type)';
  }
}

/// Trezor features (device capabilities)
class TrezorFeatures {
  final String vendor;
  final int majorVersion;
  final int minorVersion;
  final int patchVersion;
  final bool bootloaderMode;
  final String? deviceId;
  final bool pinProtection;
  final bool passphraseProtection;
  final String? language;
  final String? label;
  final bool initialized;
  final List<int> coins;
  
  TrezorFeatures({
    required this.vendor,
    required this.majorVersion,
    required this.minorVersion,
    required this.patchVersion,
    required this.bootloaderMode,
    this.deviceId,
    required this.pinProtection,
    required this.passphraseProtection,
    this.language,
    this.label,
    required this.initialized,
    required this.coins,
  });
  
  String get firmwareVersion => '$majorVersion.$minorVersion.$patchVersion';
  
  bool get supportsEthereum => coins.contains(60); // Ethereum coin type
}

/// Button request types
enum ButtonRequestType {
  other(1),
  feeOverThreshold(2),
  confirmOutput(3),
  resetDevice(4),
  confirmWord(5),
  wipeDevice(6),
  protectCall(7),
  signTx(8),
  firmwareCheck(9),
  address(10),
  publicKey(11),
  mnemonic(12),
  passphrase(13),
  confirmAction(14),
  unknown(0);
  
  const ButtonRequestType(this.value);
  final int value;
  
  static ButtonRequestType fromValue(int value) {
    for (final type in ButtonRequestType.values) {
      if (type.value == value) return type;
    }
    return ButtonRequestType.unknown;
  }
}

/// PIN matrix request
class PinMatrixRequest {
  final String? message;
  
  PinMatrixRequest({this.message});
}

/// Passphrase request
class PassphraseRequest {
  final bool onDevice;
  
  PassphraseRequest({required this.onDevice});
}

/// Button request
class ButtonRequest {
  final ButtonRequestType type;
  final String? message;
  
  ButtonRequest({
    required this.type,
    this.message,
  });
}