import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'ledger_client.dart';
import 'ledger_types.dart';

/// Ledger hardware wallet signer implementation
class LedgerSigner implements HardwareWalletSigner {
  
  LedgerSigner(this._client, this._derivationPath);
  final LedgerClient _client;
  final String _derivationPath;
  LedgerAccount? _account;
  
  /// Create a Ledger signer for a specific account
  static Future<LedgerSigner> create({
    required LedgerClient client,
    String derivationPath = "m/44'/60'/0'/0/0",
  }) async {
    final signer = LedgerSigner(client, derivationPath);
    await signer._loadAccount();
    return signer;
  }
  
  @override
  EthereumAddress get address {
    if (_account == null) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Account not loaded',
      );
    }
    return EthereumAddress.fromHex(_account!.address);
  }
  
  @override
  Future<bool> isConnected() async {
    return _client.isReady;
  }
  
  @override
  Future<void> connect() async {
    if (!_client.isReady) {
      await _client.connect();
    }
    await _loadAccount();
  }
  
  @override
  Future<void> disconnect() async {
    await _client.disconnect();
    _account = null;
  }
  
  @override
  Future<List<EthereumAddress>> getAddresses({int count = 5, int offset = 0}) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Extract base path from derivation path
    final pathParts = _derivationPath.split('/');
    final basePath = pathParts.take(pathParts.length - 1).join('/');
    
    final accounts = await _client.getAccounts(
      count: count,
      offset: offset,
      basePath: basePath,
    );
    
    return accounts.map((account) => EthereumAddress.fromHex(account.address)).toList();
  }
  
  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Encode transaction for signing
    final encodedTx = _encodeTransaction(transaction);
    
    try {
      final response = await _client.signTransaction(encodedTx, _derivationPath);
      return HexUtils.decode(response.signatureHex);
      
    } catch (e) {
      if (e is LedgerException && e.type == LedgerErrorType.userDenied) {
        throw LedgerException(
          LedgerErrorType.userDenied,
          'User denied transaction signing on device',
        );
      }
      rethrow;
    }
  }
  
  @override
  Future<Uint8List> signMessage(String message) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Convert message to bytes
    final messageBytes = Uint8List.fromList(message.codeUnits);
    
    try {
      final response = await _client.signPersonalMessage(messageBytes, _derivationPath);
      return HexUtils.decode(response.signatureHex);
      
    } catch (e) {
      if (e is LedgerException && e.type == LedgerErrorType.userDenied) {
        throw LedgerException(
          LedgerErrorType.userDenied,
          'User denied message signing on device',
        );
      }
      rethrow;
    }
  }
  
  @override
  Future<Uint8List> signTypedData(TypedData typedData) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Get domain and message hashes
    final domainHash = _hashTypedDataDomain(typedData);
    final messageHash = _hashTypedDataMessage(typedData);
    
    try {
      final response = await _client.signTypedData(domainHash, messageHash, _derivationPath);
      return HexUtils.decode(response.signatureHex);
      
    } catch (e) {
      if (e is LedgerException && e.type == LedgerErrorType.userDenied) {
        throw LedgerException(
          LedgerErrorType.userDenied,
          'User denied typed data signing on device',
        );
      }
      rethrow;
    }
  }
  
  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    try {
      // Ledger doesn't have a direct signHash for Ethereum app usually, 
      // but we can use the message signing or transaction signing path if appropriate.
      // For generic 32-byte hash, we'll use the typed data path with a dummy domain if needed,
      // or if the client supports it directly.
      final response = await _client.signPersonalMessage(hash, _derivationPath);
      return HexUtils.decode(response.signatureHex);
      
    } catch (e) {
      if (e is LedgerException && e.type == LedgerErrorType.userDenied) {
        throw LedgerException(
          LedgerErrorType.userDenied,
          'User denied hash signing on device',
        );
      }
      rethrow;
    }
  }
  
  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    // EIP-7702 authorization signing
    if (!_client.isReady) {
      throw LedgerException(
        LedgerErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Encode authorization for signing
    final encodedAuth = _encodeAuthorization(authorization);
    
    try {
      final response = await _client.signTransaction(encodedAuth, _derivationPath);
      return HexUtils.decode(response.signatureHex);
      
    } catch (e) {
      if (e is LedgerException && e.type == LedgerErrorType.userDenied) {
        throw LedgerException(
          LedgerErrorType.userDenied,
          'User denied authorization signing on device',
        );
      }
      rethrow;
    }
  }
  
  /// Get the current account information
  LedgerAccount? get account => _account;
  
  /// Get the derivation path
  String get derivationPath => _derivationPath;
  
  /// Get the Ledger client
  LedgerClient get client => _client;
  
  Future<void> _loadAccount() async {
    _account = await _client.getAccount(_derivationPath);
  }
  
  Uint8List _encodeTransaction(TransactionRequest transaction) {
    // This is a simplified encoding - in practice, you'd use proper RLP encoding
    // based on the transaction type (Legacy, EIP-1559, etc.)
    
    final fields = <dynamic>[];
    
    // Add transaction fields based on type
    switch (transaction.type) {
      case TransactionType.legacy:
        fields.addAll([
          transaction.nonce ?? BigInt.zero,
          transaction.gasPrice ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
        ]);
        break;
        
      case TransactionType.eip1559:
        fields.addAll([
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.maxPriorityFeePerGas ?? BigInt.zero,
          transaction.maxFeePerGas ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList ?? [],
        ]);
        break;
        
      case TransactionType.eip2930:
        fields.addAll([
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.gasPrice ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList ?? [],
        ]);
        break;
        
      default:
        throw LedgerException(
          LedgerErrorType.unsupportedOperation,
          'Unsupported transaction type: ${transaction.type}',
        );
    }
    
    // For now, return a simple encoding - replace with proper RLP encoding
    return Uint8List.fromList(fields.toString().codeUnits);
  }
  
  Uint8List _encodeAuthorization(Authorization authorization) {
    // Encode EIP-7702 authorization for signing
    final fields = [
      authorization.chainId,
      authorization.address,
      authorization.nonce,
    ];
    
    // For now, return a simple encoding - replace with proper encoding
    return Uint8List.fromList(fields.toString().codeUnits);
  }
  
  Uint8List _hashTypedDataDomain(TypedData typedData) {
    // Simplified domain hash - in practice, use proper EIP-712 hashing
    final domainString = typedData.domain.toString();
    return Uint8List.fromList(domainString.codeUnits);
  }
  
  Uint8List _hashTypedDataMessage(TypedData typedData) {
    // Simplified message hash - in practice, use proper EIP-712 hashing
    final messageString = typedData.message.toString();
    return Uint8List.fromList(messageString.codeUnits);
  }
}
