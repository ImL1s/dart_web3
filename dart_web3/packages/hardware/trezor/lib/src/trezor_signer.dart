import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'trezor_client.dart';
import 'trezor_types.dart';

/// Trezor hardware wallet signer implementation
class TrezorSigner implements HardwareWalletSigner {
  TrezorSigner(this._client, this._derivationPath);
  final TrezorClient _client;
  final String _derivationPath;
  TrezorAccount? _account;

  /// Create a Trezor signer for a specific account
  static Future<TrezorSigner> create({
    required TrezorClient client,
    String derivationPath = "m/44'/60'/0'/0/0",
  }) async {
    final signer = TrezorSigner(client, derivationPath);
    await signer._loadAccount();
    return signer;
  }

  @override
  EthereumAddress get address {
    final acc = _account;
    if (acc == null) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Account not loaded',
      );
    }
    return EthereumAddress.fromHex(acc.address);
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
  Future<List<EthereumAddress>> getAddresses(
      {int count = 5, int offset = 0}) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
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

    return accounts
        .map((account) => EthereumAddress.fromHex(account.address))
        .toList();
  }

  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    try {
      // Convert transaction fields to bytes
      final nonce = _bigIntToBytes(transaction.nonce ?? BigInt.zero);
      final gasPrice = _bigIntToBytes(transaction.gasPrice ?? BigInt.zero);
      final gasLimit = _bigIntToBytes(transaction.gasLimit ?? BigInt.zero);
      final value = _bigIntToBytes(transaction.value ?? BigInt.zero);

      final response = await _client.signTransaction(
        derivationPath: _derivationPath,
        nonce: nonce,
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        to: transaction.to ?? '',
        value: value,
        data: transaction.data,
        chainId: transaction.chainId,
      );

      return HexUtils.decode(response.signatureHex);
    } catch (e) {
      if (e is TrezorException && e.type == TrezorErrorType.userCancelled) {
        throw TrezorException(
          TrezorErrorType.userCancelled,
          'User cancelled transaction signing on device',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> signMessage(String message) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    // Convert message to bytes
    final messageBytes = Uint8List.fromList(message.codeUnits);

    try {
      final response = await _client.signMessage(
        derivationPath: _derivationPath,
        message: messageBytes,
      );

      return HexUtils.decode(response.signatureHex);
    } catch (e) {
      if (e is TrezorException && e.type == TrezorErrorType.userCancelled) {
        throw TrezorException(
          TrezorErrorType.userCancelled,
          'User cancelled message signing on device',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    try {
      // Trezor doesn't have a direct signHash that avoids prefixes.
      // Use signMessage as a fallback, but note that it adds EIP-191 prefix.
      final response = await _client.signMessage(
        derivationPath: _derivationPath,
        message: hash,
      );

      return HexUtils.decode(response.signatureHex);
    } catch (e) {
      if (e is TrezorException && e.type == TrezorErrorType.userCancelled) {
        throw TrezorException(
          TrezorErrorType.userCancelled,
          'User cancelled hash signing on device',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> signTypedData(EIP712TypedData typedData) async {
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    // For EIP-712 typed data, we need to implement the full protocol
    // For now, throw unsupported operation
    throw TrezorException(
      TrezorErrorType.unsupportedOperation,
      'EIP-712 typed data signing not yet implemented for Trezor',
    );
  }

  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    // EIP-7702 authorization signing
    if (!_client.isReady) {
      throw TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not connected',
      );
    }

    // For EIP-7702, we would need to implement the authorization signing protocol
    // For now, throw unsupported operation
    throw TrezorException(
      TrezorErrorType.unsupportedOperation,
      'EIP-7702 authorization signing not yet implemented for Trezor',
    );
  }

  /// Get the current account information
  TrezorAccount? get account => _account;

  /// Get the derivation path
  String get derivationPath => _derivationPath;

  /// Get the Trezor client
  TrezorClient get client => _client;

  Future<void> _loadAccount() async {
    _account = await _client.getAccount(_derivationPath);
  }

  /// Convert BigInt to bytes (big-endian, minimal length)
  Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List.fromList([0]);
    }

    final bytes = <int>[];
    var temp = value;

    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xFF)).toInt());
      temp >>= 8;
    }

    return Uint8List.fromList(bytes);
  }
}
