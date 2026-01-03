import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'keystone_client.dart';
import 'keystone_types.dart';

/// Keystone hardware wallet signer implementation
class KeystoneSigner implements HardwareWalletSigner {
  
  KeystoneSigner(this._client, this._derivationPath);
  final KeystoneClient _client;
  final String _derivationPath;
  KeystoneAccount? _account;
  
  /// Create a Keystone signer for a specific account
  static Future<KeystoneSigner> create({
    required KeystoneClient client,
    String derivationPath = "m/44'/60'/0'/0/0",
  }) async {
    final signer = KeystoneSigner(client, derivationPath);
    await signer._loadAccount();
    return signer;
  }
  
  @override
  EthereumAddress get address {
    if (_account == null) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Account not loaded',
      );
    }
    return EthereumAddress.fromHex(_account!.address);
  }
  
  @override
  Future<bool> isConnected() async {
    return _client.isConnected;
  }
  
  @override
  Future<void> connect() async {
    if (!_client.isConnected) {
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
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Extract base path from derivation path
    final pathParts = _derivationPath.split('/');
    final basePath = pathParts.take(pathParts.length - 1).join('/');
    
    final accounts = await _client.getAccounts(
      count: count,
      offset: offset,
      derivationPath: basePath,
    );
    
    return accounts.map((account) => EthereumAddress.fromHex(account.address)).toList();
  }
  
  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Encode transaction for signing
    final encodedTx = _encodeTransaction(transaction);
    
    final signature = await _client.signTransaction(
      encodedTx,
      _derivationPath,
      chainId: transaction.chainId,
    );
    
    // Convert hex signature to bytes
    return HexUtils.decode(signature);
  }
  
  @override
  Future<Uint8List> signMessage(String message) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Create Ethereum personal message hash
    final messageBytes = Uint8List.fromList(message.codeUnits);
    final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);
    
    final combined = Uint8List.fromList([...prefixBytes, ...messageBytes]);
    
    final signature = await _client.signPersonalMessage(combined, _derivationPath);
    return HexUtils.decode(signature);
  }
  
  @override
  Future<Uint8List> signTypedData(TypedData typedData) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Get the hash of the typed data
    final hash = typedData.hash();
    
    final signature = await _client.signTypedData(hash, _derivationPath);
    return HexUtils.decode(signature);
  }
  
  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    final signature = await _client.signTypedData(hash, _derivationPath);
    return HexUtils.decode(signature);
  }
  
  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    // EIP-7702 authorization signing
    if (!_client.isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    // Encode authorization for signing
    final encodedAuth = _encodeAuthorization(authorization);
    
    final signature = await _client.signTransaction(
      encodedAuth,
      _derivationPath,
      chainId: authorization.chainId,
    );
    
    return HexUtils.decode(signature);
  }
  
  /// Get the current account information
  KeystoneAccount? get account => _account;
  
  /// Get the derivation path
  String get derivationPath => _derivationPath;
  
  /// Get the Keystone client
  KeystoneClient get client => _client;
  
  /// Manually process a QR response (for UI integration)
  Future<String?> processQRResponse(String qrData) async {
    return _client.processQRResponse(qrData);
  }
  
  Future<void> _loadAccount() async {
    final accounts = await _client.getAccounts(count: 1, derivationPath: _derivationPath);
    if (accounts.isNotEmpty) {
      _account = accounts.first;
    } else {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'No account found at derivation path: $_derivationPath',
      );
    }
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
        
      default:
        throw KeystoneException(
          KeystoneErrorType.unsupportedOperation,
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
}
