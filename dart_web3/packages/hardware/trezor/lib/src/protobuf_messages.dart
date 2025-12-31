import 'dart:typed_data';
import 'trezor_types.dart';

/// Simplified protobuf message encoder/decoder for Trezor communication
/// In a real implementation, you would use proper protobuf code generation
class ProtobufMessages {
  
  /// Encode Initialize message
  static Uint8List encodeInitialize() {
    // Empty message for Initialize
    return Uint8List(0);
  }
  
  /// Encode EthereumGetAddress message
  static Uint8List encodeEthereumGetAddress({
    required String derivationPath,
    bool showDisplay = false,
  }) {
    final pathComponents = parseDerivationPath(derivationPath);
    
    // Simplified protobuf encoding
    final buffer = <int>[];
    
    // Field 1: address_n (repeated uint32)
    for (final component in pathComponents) {
      buffer.addAll([0x08]); // Tag for uint32
      buffer.addAll(encodeVarint(component));
    }
    
    // Field 2: show_display (bool)
    if (showDisplay) {
      buffer.addAll([0x10, 0x01]); // Tag + true
    }
    
    return Uint8List.fromList(buffer);
  }
  
  /// Encode EthereumSignTx message
  static Uint8List encodeEthereumSignTx({
    required String derivationPath,
    required Uint8List nonce,
    required Uint8List gasPrice,
    required Uint8List gasLimit,
    required String to,
    required Uint8List value,
    Uint8List? data,
    int? chainId,
  }) {
    final pathComponents = parseDerivationPath(derivationPath);
    
    final buffer = <int>[];
    
    // Field 1: address_n (repeated uint32)
    for (final component in pathComponents) {
      buffer.addAll([0x08]);
      buffer.addAll(encodeVarint(component));
    }
    
    // Field 2: nonce (bytes)
    if (nonce.isNotEmpty) {
      buffer.addAll([0x12]);
      buffer.addAll(encodeVarint(nonce.length));
      buffer.addAll(nonce);
    }
    
    // Field 3: gas_price (bytes)
    if (gasPrice.isNotEmpty) {
      buffer.addAll([0x1A]);
      buffer.addAll(encodeVarint(gasPrice.length));
      buffer.addAll(gasPrice);
    }
    
    // Field 4: gas_limit (bytes)
    if (gasLimit.isNotEmpty) {
      buffer.addAll([0x22]);
      buffer.addAll(encodeVarint(gasLimit.length));
      buffer.addAll(gasLimit);
    }
    
    // Field 5: to (bytes)
    if (to.isNotEmpty) {
      final toBytes = _hexToBytes(to);
      buffer.addAll([0x2A]);
      buffer.addAll(encodeVarint(toBytes.length));
      buffer.addAll(toBytes);
    }
    
    // Field 6: value (bytes)
    if (value.isNotEmpty) {
      buffer.addAll([0x32]);
      buffer.addAll(encodeVarint(value.length));
      buffer.addAll(value);
    }
    
    // Field 7: data_initial_chunk (bytes)
    if (data != null && data.isNotEmpty) {
      buffer.addAll([0x3A]);
      buffer.addAll(encodeVarint(data.length));
      buffer.addAll(data);
    }
    
    // Field 11: chain_id (uint64)
    if (chainId != null) {
      buffer.addAll([0x58]);
      buffer.addAll(encodeVarint(chainId));
    }
    
    return Uint8List.fromList(buffer);
  }
  
  /// Encode EthereumSignMessage message
  static Uint8List encodeEthereumSignMessage({
    required String derivationPath,
    required Uint8List message,
  }) {
    final pathComponents = parseDerivationPath(derivationPath);
    
    final buffer = <int>[];
    
    // Field 1: address_n (repeated uint32)
    for (final component in pathComponents) {
      buffer.addAll([0x08]);
      buffer.addAll(encodeVarint(component));
    }
    
    // Field 2: message (bytes)
    buffer.addAll([0x12]);
    buffer.addAll(encodeVarint(message.length));
    buffer.addAll(message);
    
    return Uint8List.fromList(buffer);
  }
  
  /// Encode ButtonAck message
  static Uint8List encodeButtonAck() {
    return Uint8List(0); // Empty message
  }
  
  /// Encode PinMatrixAck message
  static Uint8List encodePinMatrixAck(String pin) {
    final buffer = <int>[];
    
    // Field 1: pin (string)
    final pinBytes = pin.codeUnits;
    buffer.addAll([0x0A]);
    buffer.addAll(encodeVarint(pinBytes.length));
    buffer.addAll(pinBytes);
    
    return Uint8List.fromList(buffer);
  }
  
  /// Encode PassphraseAck message
  static Uint8List encodePassphraseAck(String passphrase) {
    final buffer = <int>[];
    
    // Field 1: passphrase (string)
    final passphraseBytes = passphrase.codeUnits;
    buffer.addAll([0x0A]);
    buffer.addAll(encodeVarint(passphraseBytes.length));
    buffer.addAll(passphraseBytes);
    
    return Uint8List.fromList(buffer);
  }
  
  /// Decode Features message
  static TrezorFeatures decodeFeatures(Uint8List data) {
    // Simplified protobuf decoding
    // In a real implementation, use proper protobuf library
    
    return TrezorFeatures(
      vendor: 'trezor.io',
      majorVersion: 2,
      minorVersion: 1,
      patchVersion: 0,
      bootloaderMode: false,
      deviceId: 'mock-device-id',
      pinProtection: true,
      passphraseProtection: false,
      language: 'en-US',
      label: 'My Trezor',
      initialized: true,
      coins: [0, 60], // Bitcoin and Ethereum
    );
  }
  
  /// Decode EthereumAddress message
  static Map<String, dynamic> decodeEthereumAddress(Uint8List data) {
    // Simplified decoding - return mock data
    return {
      'address': '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
      'publicKey': Uint8List.fromList(List.filled(64, 0x12)),
    };
  }
  
  /// Decode EthereumMessageSignature message
  static TrezorSignResponse decodeEthereumMessageSignature(Uint8List data) {
    // Simplified decoding - return mock signature
    final signature = Uint8List.fromList([
      ...List.filled(32, 0xAA), // r
      ...List.filled(32, 0xBB), // s
      0x1B, // v
    ]);
    
    return TrezorSignResponse(
      signature: signature,
      address: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
    );
  }
  
  /// Decode ButtonRequest message
  static ButtonRequest decodeButtonRequest(Uint8List data) {
    // Simplified decoding
    return ButtonRequest(
      type: ButtonRequestType.confirmAction,
      message: 'Confirm action on device',
    );
  }
  
  /// Decode PinMatrixRequest message
  static PinMatrixRequest decodePinMatrixRequest(Uint8List data) {
    return PinMatrixRequest(
      message: 'Enter PIN on device',
    );
  }
  
  /// Decode PassphraseRequest message
  static PassphraseRequest decodePassphraseRequest(Uint8List data) {
    return PassphraseRequest(onDevice: false);
  }
  
  /// Decode Failure message
  static String decodeFailure(Uint8List data) {
    // Simplified decoding
    return 'Operation failed';
  }
  
  /// Parse derivation path string to components
  static List<int> parseDerivationPath(String path) {
    final cleanPath = path.startsWith('m/') ? path.substring(2) : path;
    final parts = cleanPath.split('/');
    
    final components = <int>[];
    for (final part in parts) {
      int value;
      bool hardened = false;
      
      if (part.endsWith("'") || part.endsWith('h')) {
        hardened = true;
        value = int.parse(part.substring(0, part.length - 1));
      } else {
        value = int.parse(part);
      }
      
      if (hardened) {
        value += 0x80000000;
      }
      
      components.add(value);
    }
    
    return components;
  }
  
  /// Encode varint (variable-length integer)
  static List<int> encodeVarint(int value) {
    final result = <int>[];
    
    while (value >= 0x80) {
      result.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    result.add(value & 0x7F);
    
    return result;
  }
  
  /// Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = <int>[];
    
    for (int i = 0; i < cleanHex.length; i += 2) {
      final hexByte = cleanHex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    
    return Uint8List.fromList(bytes);
  }
}