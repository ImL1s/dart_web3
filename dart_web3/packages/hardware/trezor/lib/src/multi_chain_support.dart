import 'dart:typed_data';

import 'protobuf_messages.dart';
import 'trezor_client.dart';
import 'trezor_types.dart';

/// Multi-chain signing support for Trezor
class TrezorMultiChainSigner {
  
  TrezorMultiChainSigner(this._client);
  final TrezorClient _client;
  
  /// Sign Bitcoin transaction
  Future<String> signBitcoinTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Bitcoin signing uses different message types
    final requestData = _encodeBitcoinSignTx(
      derivationPath: derivationPath,
      transactionData: transactionData,
    );
    
    final request = TrezorMessage(
      type: TrezorMessageType.ethereumSignTx, // Would be BitcoinSignTx in real implementation
      data: requestData,
    );
    
    final response = await _client.sendMessage(request);
    
    if (response.type != TrezorMessageType.ethereumMessageSignature) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Unexpected response type: ${response.type}',
      );
    }
    
    return _parseBitcoinSignature(response.data);
  }
  
  /// Sign Solana transaction
  Future<String> signSolanaTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Solana signing would use different message types
    final requestData = _encodeSolanaSignTx(
      derivationPath: derivationPath,
      transactionData: transactionData,
    );
    
    final request = TrezorMessage(
      type: TrezorMessageType.ethereumSignTx, // Would be SolanaSignTx in real implementation
      data: requestData,
    );
    
    final response = await _client.sendMessage(request);
    
    return _parseSolanaSignature(response.data);
  }
  
  /// Sign Polkadot transaction
  Future<String> signPolkadotTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Polkadot signing would use different message types
    final requestData = _encodePolkadotSignTx(
      derivationPath: derivationPath,
      transactionData: transactionData,
    );
    
    final request = TrezorMessage(
      type: TrezorMessageType.ethereumSignTx, // Would be PolkadotSignTx in real implementation
      data: requestData,
    );
    
    final response = await _client.sendMessage(request);
    
    return _parsePolkadotSignature(response.data);
  }
  
  /// Get address for different chains
  Future<String> getAddress(String derivationPath, ChainType chainType) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    TrezorMessage request;
    
    switch (chainType) {
      case ChainType.bitcoin:
        request = TrezorMessage(
          type: TrezorMessageType.ethereumGetAddress, // Would be BitcoinGetAddress
          data: _encodeBitcoinGetAddress(derivationPath),
        );
        break;
        
      case ChainType.solana:
        request = TrezorMessage(
          type: TrezorMessageType.ethereumGetAddress, // Would be SolanaGetAddress
          data: _encodeSolanaGetAddress(derivationPath),
        );
        break;
        
      case ChainType.polkadot:
        request = TrezorMessage(
          type: TrezorMessageType.ethereumGetAddress, // Would be PolkadotGetAddress
          data: _encodePolkadotGetAddress(derivationPath),
        );
        break;
        
      case ChainType.ethereum:
        // Use existing Ethereum implementation
        final account = await _client.getAccount(derivationPath);
        return account.address;
    }
    
    final response = await _client.sendMessage(request);
    
    if (response.type != TrezorMessageType.ethereumAddress) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Unexpected response type: ${response.type}',
      );
    }
    
    return _parseAddressResponse(response.data, chainType);
  }
  
  Uint8List _encodeBitcoinSignTx({
    required String derivationPath,
    required Uint8List transactionData,
  }) {
    // Simplified Bitcoin transaction signing encoding
    final pathComponents = ProtobufMessages.parseDerivationPath(derivationPath);
    final buffer = <int>[];
    
    // Add derivation path
    for (final component in pathComponents) {
      buffer.addAll([0x08]);
      buffer.addAll(ProtobufMessages.encodeVarint(component));
    }
    
    // Add transaction data
    buffer.addAll([0x12]);
    buffer.addAll(ProtobufMessages.encodeVarint(transactionData.length));
    buffer.addAll(transactionData);
    
    return Uint8List.fromList(buffer);
  }
  
  Uint8List _encodeSolanaSignTx({
    required String derivationPath,
    required Uint8List transactionData,
  }) {
    // Simplified Solana transaction signing encoding
    final pathComponents = ProtobufMessages.parseDerivationPath(derivationPath);
    final buffer = <int>[];
    
    // Add derivation path
    for (final component in pathComponents) {
      buffer.addAll([0x08]);
      buffer.addAll(ProtobufMessages.encodeVarint(component));
    }
    
    // Add transaction data
    buffer.addAll([0x12]);
    buffer.addAll(ProtobufMessages.encodeVarint(transactionData.length));
    buffer.addAll(transactionData);
    
    return Uint8List.fromList(buffer);
  }
  
  Uint8List _encodePolkadotSignTx({
    required String derivationPath,
    required Uint8List transactionData,
  }) {
    // Simplified Polkadot transaction signing encoding
    final pathComponents = ProtobufMessages.parseDerivationPath(derivationPath);
    final buffer = <int>[];
    
    // Add derivation path
    for (final component in pathComponents) {
      buffer.addAll([0x08]);
      buffer.addAll(ProtobufMessages.encodeVarint(component));
    }
    
    // Add transaction data
    buffer.addAll([0x12]);
    buffer.addAll(ProtobufMessages.encodeVarint(transactionData.length));
    buffer.addAll(transactionData);
    
    return Uint8List.fromList(buffer);
  }
  
  Uint8List _encodeBitcoinGetAddress(String derivationPath) {
    return ProtobufMessages.encodeEthereumGetAddress(
      derivationPath: derivationPath,
    );
  }
  
  Uint8List _encodeSolanaGetAddress(String derivationPath) {
    return ProtobufMessages.encodeEthereumGetAddress(
      derivationPath: derivationPath,
    );
  }
  
  Uint8List _encodePolkadotGetAddress(String derivationPath) {
    return ProtobufMessages.encodeEthereumGetAddress(
      derivationPath: derivationPath,
    );
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
        return 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'; // Mock Bitcoin address
      case ChainType.solana:
        return '11111111111111111111111111111112'; // Mock Solana address
      case ChainType.polkadot:
        return '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY'; // Mock Polkadot address
      case ChainType.ethereum:
        // Use existing Ethereum parsing
        final result = ProtobufMessages.decodeEthereumAddress(data);
        return result['address'] as String;
    }
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
