import 'dart:typed_data';

import 'keystone_client.dart';
import 'keystone_types.dart';

/// Multi-chain signing support for Keystone
class KeystoneMultiChainSigner {
  KeystoneMultiChainSigner(this._client);
  final KeystoneClient _client;

  /// Sign Bitcoin transaction (PSBT format)
  Future<String> signBitcoinTransaction(
    Uint8List psbtData,
    String derivationPath,
  ) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    // In real implementation, requestId and PSBT encoding would be used
    // For now, return mock signature
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return '0x${List.filled(130, 'a').join()}'; // Mock signature
  }

  /// Sign Solana transaction
  Future<String> signSolanaTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    final requestId = _generateRequestId();

    final request = KeystoneSignRequest(
      requestId: requestId,
      data: transactionData,
      dataType: KeystoneDataType.transaction,
      derivationPath: derivationPath,
    );

    // Use Ed25519 curve for Solana
    return _performSigning(request, CurveType.ed25519);
  }

  /// Sign Polkadot transaction
  Future<String> signPolkadotTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    final requestId = _generateRequestId();

    final request = KeystoneSignRequest(
      requestId: requestId,
      data: transactionData,
      dataType: KeystoneDataType.transaction,
      derivationPath: derivationPath,
    );

    // Use Sr25519 curve for Polkadot
    return _performSigning(request, CurveType.sr25519);
  }

  /// Get address for different chains
  Future<String> getAddress(String derivationPath, ChainType chainType) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    // Mock address generation based on chain type
    switch (chainType) {
      case ChainType.bitcoin:
        return 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
      case ChainType.solana:
        return '11111111111111111111111111111112';
      case ChainType.polkadot:
        return '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
      case ChainType.ethereum:
        return '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8';
    }
  }

  Future<String> _performSigning(
      KeystoneSignRequest request, CurveType curveType) async {
    // Mock signing with different curves
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    switch (curveType) {
      case CurveType.secp256k1:
        return '0x${List.filled(130, 'a').join()}'; // 65 bytes * 2 hex chars
      case CurveType.ed25519:
        return '0x${List.filled(128, 'b').join()}'; // 64 bytes * 2 hex chars
      case CurveType.sr25519:
        return '0x${List.filled(128, 'c').join()}'; // 64 bytes * 2 hex chars
    }
  }

  Uint8List _generateRequestId() {
    final bytes = Uint8List(16);
    // Fill with some data
    for (var i = 0; i < 16; i++) {
      bytes[i] = i;
    }
    return bytes;
  }
}

/// Supported blockchain types
enum ChainType {
  ethereum,
  bitcoin,
  solana,
  polkadot,
}

/// Supported cryptographic curves
enum CurveType {
  secp256k1,
  ed25519,
  sr25519,
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
}
