import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account.dart';
import '../models/address.dart';
import '../models/transaction.dart';

/// Aptos REST API client.
class AptosClient {
  AptosClient(this.nodeUrl, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String nodeUrl;
  final http.Client _httpClient;

  /// Get account information.
  Future<Map<String, dynamic>> getAccount(AptosAddress address) async {
    final response = await _get('/v1/accounts/${address.toHex()}');
    return response;
  }

  /// Get account resources.
  Future<List<dynamic>> getAccountResources(String address) async {
    final response = await _get('/v1/accounts/$address/resources');
    return response is List ? (response as List).cast<dynamic>() : <dynamic>[];
  }

  /// Get account balance (APT in Octas).
  Future<BigInt> getBalance(AptosAddress address) async {
    try {
      final response = await _get(
        '/v1/accounts/${address.toHex()}/resource/0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
      );
      final coin = response['data']['coin']['value'] as String;
      return BigInt.parse(coin);
    } catch (e) {
      return BigInt.zero;
    }
  }

  /// Get account sequence number.
  Future<BigInt> getSequenceNumber(AptosAddress address) async {
    final account = await getAccount(address);
    return BigInt.parse(account['sequence_number'] as String);
  }

  /// Simulate transaction.
  Future<List<dynamic>> simulateTransaction(
    RawTransaction transaction,
    AptosAccount account,
  ) async {
    final response = await _post(
      '/v1/transactions/simulate',
      body: {
        ...transaction.toJson(),
        'signature': {
          'type': 'ed25519_signature',
          'public_key': account.publicKeyHex,
          'signature': '0x${'00' * 64}', // Empty signature for simulation
        },
      },
    );
    return response is List ? response : [response];
  }

  /// Submit signed transaction.
  Future<Map<String, dynamic>> submitTransaction(
    SignedTransaction signedTx,
  ) async {
    final result = await _post('/v1/transactions', body: signedTx.toJson());
    return result as Map<String, dynamic>;
  }

  /// Get chain ID.
  Future<int> getChainId() async {
    final response = await _get('/v1');
    return response['chain_id'] as int;
  }

  /// Get gas price estimate.
  Future<BigInt> estimateGasPrice() async {
    final response = await _get('/v1/estimate_gas_price');
    return BigInt.parse(response['gas_estimate'].toString());
  }

  /// Get transaction by hash.
  Future<Map<String, dynamic>> getTransaction(String txHash) async {
    return await _get('/v1/transactions/by_hash/$txHash');
  }

  /// Wait for transaction completion.
  Future<Map<String, dynamic>> waitForTransaction(
    String txHash, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      try {
        final tx = await getTransaction(txHash);
        if (tx['type'] == 'user_transaction') {
          return tx;
        }
      } catch (_) {
        // Transaction not found yet
      }
      await Future.delayed(pollInterval);
    }

    throw Exception('Transaction $txHash not found within timeout');
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _httpClient.get(Uri.parse('$nodeUrl$path'));
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$nodeUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Common Aptos endpoints.
class AptosEndpoints {
  static const mainnet = 'https://fullnode.mainnet.aptoslabs.com';
  static const testnet = 'https://fullnode.testnet.aptoslabs.com';
  static const devnet = 'https://fullnode.devnet.aptoslabs.com';
}
