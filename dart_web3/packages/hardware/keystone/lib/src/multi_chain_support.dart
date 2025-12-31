import 'dart:typed_data';
import 'package:dart_web3_bc_ur/dart_web3_bc_ur.dart';
import 'keystone_types.dart';
import 'keystone_client.dart';

/// Multi-chain signing support for Keystone
class KeystoneMultiChainSigner {
  final KeystoneClient _client;
  
  KeystoneMultiChainSigner(this._client);
  
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
    
    final requestId = _generateRequestId();
    
    // Create BC-UR PSBT request
    final urData = BCUREncoder.encodeSingle('crypto-psbt', psbtData);
    
    // For now, return mock signature
    // In real implementation, this would go through QR communication
    await Future.delayed(const Duration(milliseconds: 500));
    return '0x' + List.filled(130, 'a').join(); // Mock signature
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
    return await _performSigning(request, CurveType.ed25519);
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
    return await _performSigning(request, CurveType.sr25519);
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
      default:
        return '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8';
    }
  }
  
  Future<String> _performSigning(KeystoneSignRequest request, CurveType curveType) async {
    // Mock signing with different curves
    await Future.delayed(const Duration(milliseconds: 1000));
    
    switch (curveType) {
      case CurveType.secp256k1:
        return '0x' + List.filled(130, 'a').join(); // 65 bytes * 2 hex chars
      case CurveType.ed25519:
        return '0x' + List.filled(128, 'b').join(); // 64 bytes * 2 hex chars
      case CurveType.sr25519:
        return '0x' + List.filled(128, 'c').join(); // 64 bytes * 2 hex chars
    }
  }
  
  Uint8List _generateRequestId() {
    return Uint8List.fromList(List.generate(16, (i) => i));
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
  static String ethereum(int account, int index) => "m/44'/60'/$account'/0/$index";
  
  /// Standard Bitcoin path (BIP-84 native segwit)
  static String bitcoin(int account, int index) => "m/84'/0'/$account'/0/$index";
  
  /// Standard Solana path
  static String solana(int account, int index) => "m/44'/501'/$account'/$index'";
  
  /// Standard Polkadot path
  static String polkadot(int account, int index) => "m/44'/354'/$account'/0'/$index'";
  
  /// Get chain type from derivation path
  static ChainType? getChainType(String path) {
    if (path.contains("44'/60'")) return ChainType.ethereum;
    if (path.contains("44'/0'") || path.contains("84'/0'")) return ChainType.bitcoin;
    if (path.contains("44'/501'")) return ChainType.solana;
    if (path.contains("44'/354'")) return ChainType.polkadot;
    return null;
  }
}