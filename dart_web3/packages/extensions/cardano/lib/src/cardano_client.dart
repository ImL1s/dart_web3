import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cardano_types.dart';
import 'cardano_chains.dart';

/// Cardano API client (supports Blockfrost and Koios).
class CardanoClient {
  /// Creates a CardanoClient with Blockfrost.
  CardanoClient.blockfrost({
    required String baseUrl,
    required this.apiKey,
  }) : _baseUrl = baseUrl,
       _client = http.Client(),
       _apiType = _ApiType.blockfrost;

  /// Creates a CardanoClient with Koios.
  CardanoClient.koios({required String baseUrl})
      : _baseUrl = baseUrl,
        apiKey = null,
        _client = http.Client(),
        _apiType = _ApiType.koios;

  /// Creates a CardanoClient from a chain configuration.
  factory CardanoClient.fromChain(
    CardanoChainConfig chain, {
    String? blockfrostApiKey,
  }) {
    if (blockfrostApiKey != null) {
      return CardanoClient.blockfrost(
        baseUrl: chain.blockfrostUrl,
        apiKey: blockfrostApiKey,
      );
    }
    return CardanoClient.koios(baseUrl: chain.koiosUrl);
  }

  final String _baseUrl;
  final String? apiKey;
  final http.Client _client;
  final _ApiType _apiType;

  /// Closes the client.
  void close() {
    _client.close();
  }

  /// Sends a GET request.
  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != null) {
      headers['project_id'] = apiKey!;
    }

    final response = await _client.get(uri, headers: headers);

    if (response.statusCode >= 400) {
      throw CardanoApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  /// Sends a POST request.
  Future<dynamic> _post(String path, dynamic body, {String? contentType}) async {
    final headers = <String, String>{
      'Content-Type': contentType ?? 'application/json',
    };
    if (apiKey != null) {
      headers['project_id'] = apiKey!;
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: headers,
      body: contentType == 'application/cbor' ? body : jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      throw CardanoApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  // === Network ===

  /// Gets protocol parameters.
  Future<CardanoProtocolParams> getProtocolParams() async {
    final path = _apiType == _ApiType.blockfrost
        ? '/epochs/latest/parameters'
        : '/epoch_params';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoProtocolParams.fromJson(
        (result as List).first as Map<String, dynamic>,
      );
    }
    return CardanoProtocolParams.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the latest block.
  Future<CardanoBlock> getLatestBlock() async {
    final path = _apiType == _ApiType.blockfrost ? '/blocks/latest' : '/tip';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoBlock.fromJson((result as List).first as Map<String, dynamic>);
    }
    return CardanoBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Gets a block by hash or height.
  Future<CardanoBlock> getBlock(String hashOrHeight) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/blocks/$hashOrHeight'
        : '/blocks?block_hash=$hashOrHeight';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoBlock.fromJson((result as List).first as Map<String, dynamic>);
    }
    return CardanoBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Gets current epoch.
  Future<CardanoEpoch> getCurrentEpoch() async {
    final path = _apiType == _ApiType.blockfrost ? '/epochs/latest' : '/epoch_info';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoEpoch.fromJson((result as List).first as Map<String, dynamic>);
    }
    return CardanoEpoch.fromJson(result as Map<String, dynamic>);
  }

  // === Address ===

  /// Gets address UTxOs.
  Future<List<CardanoUtxo>> getAddressUtxos(String address) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/addresses/$address/utxos'
        : '/address_utxos?_address=$address';
    final result = await _get(path);
    return (result as List)
        .map((e) => CardanoUtxo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets address balance.
  Future<List<CardanoValue>> getAddressBalance(String address) async {
    if (_apiType == _ApiType.blockfrost) {
      final result = await _get('/addresses/$address');
      return (result['amount'] as List)
          .map((e) => CardanoValue.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      final result = await _get('/address_info?_address=$address');
      final info = (result as List).first as Map<String, dynamic>;
      return [
        CardanoValue(unit: 'lovelace', quantity: BigInt.parse(info['balance'] as String)),
      ];
    }
  }

  /// Gets address transactions.
  Future<List<String>> getAddressTransactions(
    String address, {
    int? page,
    int? count,
  }) async {
    if (_apiType == _ApiType.blockfrost) {
      final params = <String, String>{};
      if (page != null) params['page'] = page.toString();
      if (count != null) params['count'] = count.toString();
      final result = await _get('/addresses/$address/transactions', params);
      return (result as List).map((e) => e['tx_hash'] as String).toList();
    } else {
      final result = await _get('/address_txs?_address=$address');
      return (result as List).map((e) => e['tx_hash'] as String).toList();
    }
  }

  // === Assets ===

  /// Gets asset information.
  Future<CardanoAsset> getAsset(String asset) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/assets/$asset'
        : '/asset_info?_asset_policy=${asset.substring(0, 56)}&_asset_name=${asset.substring(56)}';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoAsset.fromJson((result as List).first as Map<String, dynamic>);
    }
    return CardanoAsset.fromJson(result as Map<String, dynamic>);
  }

  /// Gets assets owned by an address.
  Future<List<CardanoAsset>> getAddressAssets(String address) async {
    if (_apiType == _ApiType.blockfrost) {
      final result = await _get('/addresses/$address');
      final amounts = result['amount'] as List;
      return amounts
          .where((a) => a['unit'] != 'lovelace')
          .map((a) => CardanoAsset(
                policyId: (a['unit'] as String).substring(0, 56),
                assetName: (a['unit'] as String).substring(56),
                quantity: BigInt.parse(a['quantity'] as String),
              ))
          .toList();
    } else {
      final result = await _get('/address_assets?_address=$address');
      return (result as List)
          .map((e) => CardanoAsset.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // === Pools ===

  /// Gets pool information.
  Future<CardanoPool> getPool(String poolId) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/pools/$poolId'
        : '/pool_info?_pool_bech32_ids=$poolId';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return CardanoPool.fromJson((result as List).first as Map<String, dynamic>);
    }
    return CardanoPool.fromJson(result as Map<String, dynamic>);
  }

  /// Gets all pools.
  Future<List<String>> getPools({int? page, int? count}) async {
    if (_apiType == _ApiType.blockfrost) {
      final params = <String, String>{};
      if (page != null) params['page'] = page.toString();
      if (count != null) params['count'] = count.toString();
      final result = await _get('/pools', params);
      return (result as List).cast<String>();
    } else {
      final result = await _get('/pool_list');
      return (result as List).map((e) => e['pool_id_bech32'] as String).toList();
    }
  }

  // === Transactions ===

  /// Gets a transaction by hash.
  Future<Map<String, dynamic>> getTransaction(String txHash) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/txs/$txHash'
        : '/tx_info?_tx_hashes=$txHash';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return (result as List).first as Map<String, dynamic>;
    }
    return result as Map<String, dynamic>;
  }

  /// Gets transaction UTxOs.
  Future<Map<String, dynamic>> getTransactionUtxos(String txHash) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/txs/$txHash/utxos'
        : '/tx_utxos?_tx_hashes=$txHash';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return (result as List).first as Map<String, dynamic>;
    }
    return result as Map<String, dynamic>;
  }

  /// Submits a signed transaction.
  Future<String> submitTransaction(String cborHex) async {
    if (_apiType == _ApiType.blockfrost) {
      final bytes = _hexToBytes(cborHex);
      final result = await _post('/tx/submit', bytes, contentType: 'application/cbor');
      return result as String;
    } else {
      final result = await _post('/submittx', {'tx': cborHex});
      return result as String;
    }
  }

  /// Evaluates a transaction (for Plutus).
  Future<Map<String, dynamic>> evaluateTransaction(String cborHex) async {
    if (_apiType == _ApiType.blockfrost) {
      final bytes = _hexToBytes(cborHex);
      final result = await _post('/utils/txs/evaluate', bytes, contentType: 'application/cbor');
      return result as Map<String, dynamic>;
    } else {
      final result = await _post('/ogmios', {
        'jsonrpc': '2.0',
        'method': 'evaluateTransaction',
        'params': {'transaction': {'cbor': cborHex}},
      });
      return result as Map<String, dynamic>;
    }
  }

  /// Waits for a transaction to be confirmed.
  Future<Map<String, dynamic>> waitForTransaction(
    String txHash, {
    Duration timeout = const Duration(seconds: 120),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final tx = await getTransaction(txHash);
        return tx;
      } catch (e) {
        if (e is CardanoApiException && e.statusCode == 404) {
          await Future<void>.delayed(pollInterval);
        } else {
          rethrow;
        }
      }
    }

    throw CardanoApiException(
      'Transaction $txHash not confirmed within timeout',
      statusCode: 408,
    );
  }

  // === Account (Stake) ===

  /// Gets stake account information.
  Future<Map<String, dynamic>> getStakeAccount(String stakeAddress) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/accounts/$stakeAddress'
        : '/account_info?_stake_addresses=$stakeAddress';
    final result = await _get(path);
    if (_apiType == _ApiType.koios) {
      return (result as List).first as Map<String, dynamic>;
    }
    return result as Map<String, dynamic>;
  }

  /// Gets stake account rewards.
  Future<List<Map<String, dynamic>>> getStakeRewards(String stakeAddress) async {
    final path = _apiType == _ApiType.blockfrost
        ? '/accounts/$stakeAddress/rewards'
        : '/account_rewards?_stake_addresses=$stakeAddress';
    final result = await _get(path);
    return (result as List).cast<Map<String, dynamic>>();
  }
}

/// Cardano API exception.
class CardanoApiException implements Exception {
  /// Creates a CardanoApiException.
  const CardanoApiException(this.message, {this.statusCode});

  /// Error message.
  final String message;

  /// HTTP status code.
  final int? statusCode;

  @override
  String toString() => 'CardanoApiException: $message (status: $statusCode)';
}

enum _ApiType { blockfrost, koios }

/// Helper to convert hex to bytes.
List<int> _hexToBytes(String hex) {
  var cleanHex = hex;
  if (cleanHex.startsWith('0x')) {
    cleanHex = cleanHex.substring(2);
  }
  final result = <int>[];
  for (var i = 0; i < cleanHex.length; i += 2) {
    result.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
  }
  return result;
}
