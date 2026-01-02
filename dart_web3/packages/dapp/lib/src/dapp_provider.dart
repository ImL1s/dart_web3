import 'dart:async';

import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

/// Injected Web3 Provider following EIP-1193
class DAppProvider {

  DAppProvider({
    required PublicClient publicClient,
    WalletClient? walletClient,
  })  : _publicClient = publicClient,
        _walletClient = walletClient;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

  /// EIP-1193 request method
  Future<dynamic> request(Map<String, dynamic> args) async {
    final method = args['method'] as String;
    final params = args['params'] as List<dynamic>? ?? [];

    switch (method) {
      case 'eth_accounts':
      case 'eth_requestAccounts':
        return _walletClient != null ? [_walletClient.address.hex] : [];
      
      case 'eth_chainId':
        return '0x${_publicClient.chain.chainId.toRadixString(16)}';

      case 'eth_sendTransaction':
        if (_walletClient == null) throw Exception('Wallet not connected');
        // Handle transaction sending (would involve UI confirmation)
        return _walletClient.sendTransaction(_parseTransaction(params[0] as Map<String, dynamic>));

      default:
        // Forward other requests to public client (RPC)
        return _publicClient.provider.call(method, params);
    }
  }

  TransactionRequest _parseTransaction(Map<String, dynamic> tx) {
    // Basic mapping from JS transaction object to TransactionRequest
    return TransactionRequest(
      to: tx['to'] as String?,
      value: tx['value'] != null ? BigInt.parse(tx['value'] as String) : null,
      data: tx['data'] != null ? HexUtils.decode(tx['data'] as String) : null,
    );
  }
}
