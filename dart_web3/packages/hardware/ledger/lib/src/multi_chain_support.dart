import 'dart:typed_data';

import 'ledger_client.dart';
import 'ledger_types.dart';

/// Multi-chain signing support for Ledger
class LedgerMultiChainSigner {
  LedgerMultiChainSigner(this._client);
  final LedgerClient _client;

  /// Sign Bitcoin transaction using Bitcoin app
  Future<String> signBitcoinTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected or Bitcoin app not open',
      );
    }

    // Bitcoin app uses different APDU commands
    final command = APDUCommand(
      cla: 0xE1, // Bitcoin app class
      ins: 0x04, // Sign transaction
      p1: 0x00,
      p2: 0x00,
      data: _encodeBitcoinSignRequest(derivationPath, transactionData),
    );

    final response = await _client.sendCommand(command);

    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Bitcoin signing failed: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }

    return _parseBitcoinSignature(response.data);
  }

  /// Sign Solana transaction using Solana app
  Future<String> signSolanaTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected or Solana app not open',
      );
    }

    // Solana app uses different APDU commands
    final command = APDUCommand(
      cla: 0xE0,
      ins: 0x06, // Sign transaction (Solana)
      p1: 0x00,
      p2: 0x00,
      data: _encodeSolanaSignRequest(derivationPath, transactionData),
    );

    final response = await _client.sendCommand(command);

    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Solana signing failed: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }

    return _parseSolanaSignature(response.data);
  }

  /// Sign Polkadot transaction using Polkadot app
  Future<String> signPolkadotTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected or Polkadot app not open',
      );
    }

    // Polkadot app uses different APDU commands
    final command = APDUCommand(
      cla: 0x90, // Polkadot app class
      ins: 0x03, // Sign transaction
      p1: 0x00,
      p2: 0x00,
      data: _encodePolkadotSignRequest(derivationPath, transactionData),
    );

    final response = await _client.sendCommand(command);

    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Polkadot signing failed: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }

    return _parsePolkadotSignature(response.data);
  }

  /// Get address for different chains
  Future<String> getAddress(String derivationPath, ChainType chainType) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    APDUCommand command;

    switch (chainType) {
      case ChainType.bitcoin:
        command = APDUCommand(
          cla: 0xE1, // Bitcoin app
          ins: 0x02, // Get address
          p1: 0x00,
          p2: 0x00,
          data: _encodeBitcoinAddressRequest(derivationPath),
        );
        break;

      case ChainType.solana:
        command = APDUCommand(
          cla: 0xE0,
          ins: 0x05, // Get address (Solana)
          p1: 0x00,
          p2: 0x00,
          data: _encodeSolanaAddressRequest(derivationPath),
        );
        break;

      case ChainType.polkadot:
        command = APDUCommand(
          cla: 0x90, // Polkadot app
          ins: 0x01, // Get address
          p1: 0x00,
          p2: 0x00,
          data: _encodePolkadotAddressRequest(derivationPath),
        );
        break;

      case ChainType.ethereum:
        // Use existing Ethereum implementation
        final account = await _client.getAccount(derivationPath);
        return account.address;
    }

    final response = await _client.sendCommand(command);

    if (!response.isSuccess) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Failed to get ${chainType.name} address: ${response.errorMessage}',
        statusWord: response.statusWord,
      );
    }

    return _parseAddressResponse(response.data, chainType);
  }

  Uint8List _encodeBitcoinSignRequest(
      String derivationPath, Uint8List transactionData) {
    // Simplified Bitcoin signing request encoding
    final pathData = _encodeDerivationPath(derivationPath);
    return Uint8List.fromList([...pathData, ...transactionData]);
  }

  Uint8List _encodeSolanaSignRequest(
      String derivationPath, Uint8List transactionData) {
    // Simplified Solana signing request encoding
    final pathData = _encodeDerivationPath(derivationPath);
    return Uint8List.fromList([...pathData, ...transactionData]);
  }

  Uint8List _encodePolkadotSignRequest(
      String derivationPath, Uint8List transactionData) {
    // Simplified Polkadot signing request encoding
    final pathData = _encodeDerivationPath(derivationPath);
    return Uint8List.fromList([...pathData, ...transactionData]);
  }

  Uint8List _encodeBitcoinAddressRequest(String derivationPath) {
    return _encodeDerivationPath(derivationPath);
  }

  Uint8List _encodeSolanaAddressRequest(String derivationPath) {
    return _encodeDerivationPath(derivationPath);
  }

  Uint8List _encodePolkadotAddressRequest(String derivationPath) {
    return _encodeDerivationPath(derivationPath);
  }

  String _parseBitcoinSignature(Uint8List data) {
    // Parse Bitcoin signature from response
    return '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  String _parseSolanaSignature(Uint8List data) {
    // Parse Solana signature from response
    return '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  String _parsePolkadotSignature(Uint8List data) {
    // Parse Polkadot signature from response
    return '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  String _parseAddressResponse(Uint8List data, ChainType chainType) {
    // Parse address from response based on chain type
    switch (chainType) {
      case ChainType.bitcoin:
        // Bitcoin addresses are typically base58 encoded
        return 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'; // Mock
      case ChainType.solana:
        // Solana addresses are base58 encoded
        return '11111111111111111111111111111112'; // Mock
      case ChainType.polkadot:
        // Polkadot addresses are SS58 encoded
        return '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY'; // Mock
      case ChainType.ethereum:
        // Ethereum addresses are hex encoded
        return '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }
  }

  Uint8List _encodeDerivationPath(String path) {
    // Reuse the existing derivation path encoding from EthereumAPDU
    final cleanPath = path.startsWith('m/') ? path.substring(2) : path;
    final parts = cleanPath.split('/');

    final buffer = <int>[];
    buffer.add(parts.length);

    for (final part in parts) {
      int value;
      var hardened = false;

      if (part.endsWith("'") || part.endsWith('h')) {
        hardened = true;
        value = int.parse(part.substring(0, part.length - 1));
      } else {
        value = int.parse(part);
      }

      if (hardened) {
        value += 0x80000000;
      }

      buffer.addAll([
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);
    }

    return Uint8List.fromList(buffer);
  }
}

/// Supported blockchain types
enum ChainType {
  ethereum,
  bitcoin,
  solana,
  polkadot,
}

/// Multi-chain derivation path utilities
class MultiChainDerivationPaths {
  /// Standard Ethereum path
  static String ethereum(int account, int index) =>
      "m/44'/60'/$account'/0/$index";

  /// Standard Bitcoin path (BIP-84 native segwit)
  static String bitcoin(int account, int index) =>
      "m/84'/0'/$account'/0/$index";

  /// Standard Solana path
  static String solana(int account, int index) =>
      "m/44'/501'/$account'/$index'";

  /// Standard Polkadot path
  static String polkadot(int account, int index) =>
      "m/44'/354'/$account'/0'/$index'";

  /// Get chain type from derivation path
  static ChainType? getChainType(String path) {
    if (path.contains("44'/60'")) {
      return ChainType.ethereum;
    }
    if (path.contains("44'/0'") || path.contains("84'/0'")) {
      return ChainType.bitcoin;
    }
    if (path.contains("44'/501'")) {
      return ChainType.solana;
    }
    if (path.contains("44'/354'")) {
      return ChainType.polkadot;
    }
    return null;
  }
}
