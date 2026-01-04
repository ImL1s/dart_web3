/// Reown signer implementation for WalletConnect v2 protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'namespace_config.dart';
import 'session_manager.dart';

/// Signer implementation that uses Reown/WalletConnect v2 for signing.
class ReownSigner implements Signer {
  ReownSigner({
    required this.sessionManager,
    required this.sessionTopic,
    required String address,
  }) : _address = address;
  final SessionManager sessionManager;
  final String sessionTopic;
  final String _address;

  @override
  EthereumAddress get address => EthereumAddress.fromHex(_address);

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports eth_sign
    final hasSigningMethod = session.namespaces.any(
      (ns) => ns.supportsMethod('eth_sign'),
    );

    if (!hasSigningMethod) {
      throw Exception('Session does not support raw hash signing (eth_sign)');
    }

    try {
      // Send signing request to wallet
      final response = await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'eth_sign',
        params: {
          'message': HexUtils.encode(hash),
          'address': _address,
        },
        timeout: const Duration(minutes: 5),
      );

      final signature = response['result'] as String;
      return HexUtils.decode(signature);
    } on Object catch (e) {
      throw SigningException('Failed to sign hash: $e');
    }
  }

  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports transaction signing
    final hasSigningMethod = session.namespaces.any(
      (ns) =>
          ns.supportsMethod('eth_signTransaction') ||
          ns.supportsMethod('eth_sendTransaction'),
    );

    if (!hasSigningMethod) {
      throw Exception('Session does not support transaction signing');
    }

    // Prepare transaction parameters
    final params = _prepareTransactionParams(transaction);

    try {
      // Send signing request to wallet
      final response = await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'eth_signTransaction',
        params: params,
        timeout: const Duration(minutes: 5),
      );

      final signedTx = response['result'] as String;
      return HexUtils.decode(signedTx);
    } on Object catch (e) {
      throw SigningException('Failed to sign transaction: $e');
    }
  }

  @override
  Future<Uint8List> signMessage(String message) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports message signing
    final hasSigningMethod = session.namespaces.any(
      (ns) =>
          ns.supportsMethod('personal_sign') || ns.supportsMethod('eth_sign'),
    );

    if (!hasSigningMethod) {
      throw Exception('Session does not support message signing');
    }

    try {
      // Use personal_sign method (EIP-191)
      final response = await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'personal_sign',
        params: {
          'message': HexUtils.encode(utf8.encode(message)),
          'address': _address,
        },
        timeout: const Duration(minutes: 5),
      );

      final signature = response['result'] as String;
      return HexUtils.decode(signature);
    } catch (e) {
      throw SigningException('Failed to sign message: $e');
    }
  }

  @override
  Future<Uint8List> signTypedData(EIP712TypedData typedData) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports typed data signing
    final hasSigningMethod = session.namespaces.any(
      (ns) =>
          ns.supportsMethod('eth_signTypedData') ||
          ns.supportsMethod('eth_signTypedData_v3') ||
          ns.supportsMethod('eth_signTypedData_v4'),
    );

    if (!hasSigningMethod) {
      throw Exception('Session does not support typed data signing');
    }

    try {
      // Use eth_signTypedData_v4 method (EIP-712)
      final response = await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'eth_signTypedData_v4',
        params: {
          'address': _address,
          'data': jsonEncode(typedData.toJson()),
        },
        timeout: const Duration(minutes: 5),
      );

      final signature = response['result'] as String;
      return HexUtils.decode(signature);
    } catch (e) {
      throw SigningException('Failed to sign typed data: $e');
    }
  }

  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports EIP-7702 authorization signing
    final hasSigningMethod = session.namespaces.any(
      (ns) =>
          ns.supportsMethod('eth_signAuthorization') ||
          ns.supportsMethod('eth_signTypedData_v4'),
    ); // Fallback to typed data

    if (!hasSigningMethod) {
      throw Exception('Session does not support authorization signing');
    }

    try {
      // Try EIP-7702 specific method first
      if (session.namespaces
          .any((ns) => ns.supportsMethod('eth_signAuthorization'))) {
        final response = await sessionManager.sendRequest(
          topic: sessionTopic,
          method: 'eth_signAuthorization',
          params: authorization.toJson(),
          timeout: const Duration(minutes: 5),
        );

        final signature = response['result'] as String;
        return HexUtils.decode(signature);
      } else {
        // Fallback to typed data signing - create a simple EIP712TypedData for authorization
        final typedData = EIP712TypedData(
          domain: {
            'name': 'EIP-7702 Authorization',
            'version': '1',
            'chainId': authorization.chainId,
          },
          types: {
            'Authorization': [
              TypedDataField(name: 'chainId', type: 'uint256'),
              TypedDataField(name: 'address', type: 'address'),
              TypedDataField(name: 'nonce', type: 'uint256'),
            ],
          },
          primaryType: 'Authorization',
          message: {
            'chainId': authorization.chainId,
            'address': authorization.address,
            'nonce': authorization.nonce,
          },
        );
        return await signTypedData(typedData);
      }
    } catch (e) {
      throw SigningException('Failed to sign authorization: $e');
    }
  }

  /// Sends a transaction (sign and send in one call).
  Future<String> sendTransaction(TransactionRequest transaction) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports sending transactions
    final hasMethod = session.namespaces.any(
      (ns) => ns.supportsMethod('eth_sendTransaction'),
    );

    if (!hasMethod) {
      throw Exception('Session does not support sending transactions');
    }

    // Prepare transaction parameters
    final params = _prepareTransactionParams(transaction);

    try {
      // Send transaction request to wallet
      final response = await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'eth_sendTransaction',
        params: params,
        timeout: const Duration(minutes: 5),
      );

      return response['result'] as String;
    } catch (e) {
      throw SigningException('Failed to send transaction: $e');
    }
  }

  /// Requests account switching.
  Future<void> switchAccount(String newAddress) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    try {
      await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'wallet_requestPermissions',
        params: <String, dynamic>{
          'eth_accounts': <String, dynamic>{},
        },
        timeout: const Duration(minutes: 5),
      );
    } catch (e) {
      throw Exception('Failed to switch account: $e');
    }
  }

  /// Requests chain switching.
  Future<void> switchChain(String chainId) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports chain switching
    final hasMethod = session.namespaces.any(
      (ns) => ns.supportsMethod('wallet_switchEthereumChain'),
    );

    if (!hasMethod) {
      throw Exception('Session does not support chain switching');
    }

    try {
      await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'wallet_switchEthereumChain',
        params: {
          'chainId': '0x${int.parse(chainId).toRadixString(16)}',
        },
        timeout: const Duration(minutes: 5),
      );
    } catch (e) {
      throw Exception('Failed to switch chain: $e');
    }
  }

  /// Adds a custom token to the wallet.
  Future<void> watchAsset({
    required String address,
    required String symbol,
    required int decimals,
    String? image,
  }) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Check if the session supports adding assets
    final hasMethod = session.namespaces.any(
      (ns) => ns.supportsMethod('wallet_watchAsset'),
    );

    if (!hasMethod) {
      throw Exception('Session does not support adding assets');
    }

    try {
      await sessionManager.sendRequest(
        topic: sessionTopic,
        method: 'wallet_watchAsset',
        params: {
          'type': 'ERC20',
          'options': {
            'address': address,
            'symbol': symbol,
            'decimals': decimals,
            if (image != null) 'image': image,
          },
        },
        timeout: const Duration(minutes: 5),
      );
    } catch (e) {
      throw Exception('Failed to add asset: $e');
    }
  }

  /// Checks if the session is still active.
  bool get isSessionActive {
    final session = sessionManager.getSession(sessionTopic);
    return session != null && !session.isExpired;
  }

  /// Gets the current session.
  Session? get session => sessionManager.getSession(sessionTopic);

  /// Prepares transaction parameters for RPC calls.
  Map<String, dynamic> _prepareTransactionParams(
      TransactionRequest transaction) {
    final params = <String, dynamic>{
      'from': _address,
    };

    if (transaction.to != null) {
      params['to'] = transaction.to;
    }

    if (transaction.value != null) {
      params['value'] = '0x${transaction.value!.toRadixString(16)}';
    }

    if (transaction.data != null && transaction.data!.isNotEmpty) {
      params['data'] = HexUtils.encode(transaction.data!);
    }

    if (transaction.gasLimit != null) {
      params['gas'] = '0x${transaction.gasLimit!.toRadixString(16)}';
    }

    // Handle different transaction types
    switch (transaction.type) {
      case TransactionType.legacy:
        if (transaction.gasPrice != null) {
          params['gasPrice'] = '0x${transaction.gasPrice!.toRadixString(16)}';
        }
        break;

      case TransactionType.eip1559:
      case TransactionType.eip4844:
      case TransactionType.eip7702:
        if (transaction.maxFeePerGas != null) {
          params['maxFeePerGas'] =
              '0x${transaction.maxFeePerGas!.toRadixString(16)}';
        }
        if (transaction.maxPriorityFeePerGas != null) {
          params['maxPriorityFeePerGas'] =
              '0x${transaction.maxPriorityFeePerGas!.toRadixString(16)}';
        }
        break;

      case TransactionType.eip2930:
        if (transaction.gasPrice != null) {
          params['gasPrice'] = '0x${transaction.gasPrice!.toRadixString(16)}';
        }
        if (transaction.accessList != null) {
          params['accessList'] = transaction.accessList!
              .map(
                (entry) => {
                  'address': entry.address,
                  'storageKeys': entry.storageKeys,
                },
              )
              .toList();
        }
        break;
    }

    if (transaction.nonce != null) {
      params['nonce'] = '0x${transaction.nonce!.toRadixString(16)}';
    }

    // Add type for typed transactions
    if (transaction.type != TransactionType.legacy) {
      params['type'] = '0x${transaction.type.value.toRadixString(16)}';
    }

    return params;
  }
}

/// Exception thrown when signing operations fail.
class SigningException implements Exception {
  SigningException(this.message);
  final String message;

  @override
  String toString() => 'SigningException: $message';
}

/// Factory for creating Reown signers from sessions.
class ReownSignerFactory {
  ReownSignerFactory._();

  /// Creates a signer from an active session.
  static ReownSigner fromSession(
      SessionManager sessionManager, Session session) {
    if (session.account.isEmpty) {
      throw ArgumentError('Session must have at least one account');
    }

    // Extract address from CAIP-10 account format
    final address = CaipUtils.getAddressFromAccount(session.account);

    return ReownSigner(
      sessionManager: sessionManager,
      sessionTopic: session.topic,
      address: address,
    );
  }

  /// Creates signers for all accounts in a session.
  static List<ReownSigner> fromSessionAccounts(
      SessionManager sessionManager, Session session) {
    if (session.namespaces.isEmpty) {
      return [];
    }

    final signers = <ReownSigner>[];

    // Get all accounts from all namespaces
    for (final namespace in session.namespaces) {
      for (final account in namespace.accounts) {
        final address = CaipUtils.getAddressFromAccount(account);
        signers.add(
          ReownSigner(
            sessionManager: sessionManager,
            sessionTopic: session.topic,
            address: address,
          ),
        );
      }
    }

    return signers;
  }
}
