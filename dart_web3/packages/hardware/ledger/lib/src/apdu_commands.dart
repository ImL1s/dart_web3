import 'dart:typed_data';
import 'ledger_types.dart';

/// APDU commands for Ledger Ethereum app
class EthereumAPDU {
  // Class byte for Ethereum app
  static const int cla = 0xE0;
  
  // Instruction codes
  static const int insGetConfiguration = 0x01;
  static const int insGetPublicKey = 0x02;
  static const int insSignTransaction = 0x04;
  static const int insGetAppName = 0x06;
  static const int insSignPersonalMessage = 0x08;
  static const int insSignTypedData = 0x0C;
  
  // Parameter values
  static const int p1Display = 0x00;
  static const int p1NoDisplay = 0x01;
  static const int p1FirstChunk = 0x00;
  static const int p1MoreChunks = 0x80;
  
  /// Get Ethereum app configuration
  static APDUCommand getConfiguration() {
    return APDUCommand(
      cla: cla,
      ins: insGetConfiguration,
      p1: 0x00,
      p2: 0x00,
    );
  }
  
  /// Get public key for derivation path
  static APDUCommand getPublicKey(String derivationPath, {bool display = false}) {
    final pathData = _encodeDerivationPath(derivationPath);
    
    return APDUCommand(
      cla: cla,
      ins: insGetPublicKey,
      p1: display ? p1Display : p1NoDisplay,
      p2: 0x00,
      data: pathData,
    );
  }
  
  /// Sign transaction (first chunk)
  static APDUCommand signTransactionFirst(String derivationPath, Uint8List transactionData) {
    final pathData = _encodeDerivationPath(derivationPath);
    final data = Uint8List.fromList([...pathData, ...transactionData]);
    
    return APDUCommand(
      cla: cla,
      ins: insSignTransaction,
      p1: p1FirstChunk,
      p2: 0x00,
      data: data,
    );
  }
  
  /// Sign transaction (continuation chunk)
  static APDUCommand signTransactionContinue(Uint8List transactionData) {
    return APDUCommand(
      cla: cla,
      ins: insSignTransaction,
      p1: p1MoreChunks,
      p2: 0x00,
      data: transactionData,
    );
  }
  
  /// Sign personal message
  static APDUCommand signPersonalMessage(String derivationPath, Uint8List messageData) {
    final pathData = _encodeDerivationPath(derivationPath);
    final messageLength = _encodeLength(messageData.length);
    final data = Uint8List.fromList([...pathData, ...messageLength, ...messageData]);
    
    return APDUCommand(
      cla: cla,
      ins: insSignPersonalMessage,
      p1: p1FirstChunk,
      p2: 0x00,
      data: data,
    );
  }
  
  /// Sign EIP-712 typed data
  static APDUCommand signTypedData(String derivationPath, Uint8List domainHash, Uint8List messageHash) {
    final pathData = _encodeDerivationPath(derivationPath);
    final data = Uint8List.fromList([...pathData, ...domainHash, ...messageHash]);
    
    return APDUCommand(
      cla: cla,
      ins: insSignTypedData,
      p1: p1FirstChunk,
      p2: 0x00,
      data: data,
    );
  }
  
  /// Get app name and version
  static APDUCommand getAppName() {
    return APDUCommand(
      cla: cla,
      ins: insGetAppName,
      p1: 0x00,
      p2: 0x00,
    );
  }
  
  /// Encode derivation path to bytes
  static Uint8List _encodeDerivationPath(String path) {
    // Remove 'm/' prefix if present
    final cleanPath = path.startsWith('m/') ? path.substring(2) : path;
    final parts = cleanPath.split('/');
    
    final buffer = <int>[];
    buffer.add(parts.length); // Number of path components
    
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
      
      // Add as 4-byte big-endian
      buffer.addAll([
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);
    }
    
    return Uint8List.fromList(buffer);
  }
  
  /// Encode length as 4-byte big-endian
  static Uint8List _encodeLength(int length) {
    return Uint8List.fromList([
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ]);
  }
}

/// Response parsers for Ethereum app
class EthereumResponseParser {
  /// Parse public key response
  static Map<String, dynamic> parsePublicKey(APDUResponse response) {
    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Failed to get public key: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }
    
    final data = response.data;
    if (data.length < 65) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Invalid public key response length',
      );
    }
    
    final publicKeyLength = data[0];
    final publicKey = data.sublist(1, 1 + publicKeyLength);
    
    int offset = 1 + publicKeyLength;
    final addressLength = data[offset];
    offset++;
    final address = data.sublist(offset, offset + addressLength);
    
    return {
      'publicKey': publicKey,
      'address': '0x${address.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    };
  }
  
  /// Parse signature response
  static LedgerSignResponse parseSignature(APDUResponse response) {
    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Failed to get signature: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }
    
    final data = response.data;
    if (data.length < 65) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Invalid signature response length',
      );
    }
    
    final v = data[0];
    final r = data.sublist(1, 33);
    final s = data.sublist(33, 65);
    final signature = Uint8List.fromList([...r, ...s, v]);
    
    return LedgerSignResponse(
      signature: signature,
      v: v,
      r: r,
      s: s,
    );
  }
  
  /// Parse configuration response
  static EthereumAppConfig parseConfiguration(APDUResponse response) {
    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Failed to get configuration: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }
    
    final data = response.data;
    if (data.length < 4) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Invalid configuration response length',
      );
    }
    
    final arbitraryDataEnabled = data[0] == 0x01;
    final erc20ProvisioningNecessary = data[1] == 0x01;
    final majorVersion = data[2];
    final minorVersion = data[3];
    final patchVersion = data.length > 4 ? data[4] : 0;
    
    return EthereumAppConfig(
      arbitraryDataEnabled: arbitraryDataEnabled,
      erc20ProvisioningNecessary: erc20ProvisioningNecessary,
      version: '$majorVersion.$minorVersion.$patchVersion',
    );
  }
  
  /// Parse app name response
  static LedgerApp parseAppName(APDUResponse response) {
    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Failed to get app name: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }
    
    final data = response.data;
    if (data.isEmpty) {
      throw LedgerException(
        LedgerErrorType.invalidResponse,
        'Empty app name response',
      );
    }
    
    final nameLength = data[0];
    final name = String.fromCharCodes(data.sublist(1, 1 + nameLength));
    
    int offset = 1 + nameLength;
    final versionLength = data[offset];
    offset++;
    final version = String.fromCharCodes(data.sublist(offset, offset + versionLength));
    
    return LedgerApp(
      name: name,
      version: version,
      isOpen: true,
    );
  }
}