import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'aptos_types.dart';
import 'aptos_transaction.dart';
import 'aptos_chains.dart';

/// Aptos REST API client.
class AptosClient {
  /// Creates an AptosClient with a custom RPC URL.
  AptosClient(this.rpcUrl) : _client = http.Client();

  /// Creates an AptosClient from a chain configuration.
  factory AptosClient.fromChain(AptosChainConfig chain) {
    return AptosClient(chain.rpcUrl);
  }

  /// Creates an AptosClient for mainnet.
  factory AptosClient.mainnet() => AptosClient.fromChain(AptosChains.mainnet);

  /// Creates an AptosClient for testnet.
  factory AptosClient.testnet() => AptosClient.fromChain(AptosChains.testnet);

  /// Creates an AptosClient for devnet.
  factory AptosClient.devnet() => AptosClient.fromChain(AptosChains.devnet);

  /// The RPC endpoint URL.
  final String rpcUrl;

  final http.Client _client;

  /// Closes the client.
  void close() {
    _client.close();
  }

  /// Sends a GET request.
  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$rpcUrl$path').replace(queryParameters: queryParams);
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 400) {
      throw AptosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  /// Sends a POST request.
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$rpcUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      throw AptosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  // === General API ===

  /// Gets the ledger information.
  Future<AptosLedgerInfo> getLedgerInfo() async {
    final result = await _get('/');
    return AptosLedgerInfo.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the estimated gas price.
  Future<AptosGasEstimation> estimateGasPrice() async {
    final result = await _get('/estimate_gas_price');
    return AptosGasEstimation.fromJson(result as Map<String, dynamic>);
  }

  // === Account API ===

  /// Gets account information.
  Future<AptosAccount> getAccount(AptosAddress address) async {
    final result = await _get('/accounts/${address.toHex()}');
    return AptosAccount.fromJson(result as Map<String, dynamic>);
  }

  /// Gets account resources.
  Future<List<AptosAccountResource>> getAccountResources(
    AptosAddress address, {
    BigInt? ledgerVersion,
  }) async {
    final result = await _get(
      '/accounts/${address.toHex()}/resources',
      ledgerVersion != null ? {'ledger_version': ledgerVersion.toString()} : null,
    );
    return (result as List)
        .map((e) => AptosAccountResource.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific account resource.
  Future<AptosAccountResource> getAccountResource(
    AptosAddress address,
    String resourceType, {
    BigInt? ledgerVersion,
  }) async {
    final result = await _get(
      '/accounts/${address.toHex()}/resource/$resourceType',
      ledgerVersion != null ? {'ledger_version': ledgerVersion.toString()} : null,
    );
    return AptosAccountResource.fromJson(result as Map<String, dynamic>);
  }

  /// Gets account modules.
  Future<List<Map<String, dynamic>>> getAccountModules(
    AptosAddress address, {
    BigInt? ledgerVersion,
  }) async {
    final result = await _get(
      '/accounts/${address.toHex()}/modules',
      ledgerVersion != null ? {'ledger_version': ledgerVersion.toString()} : null,
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Gets the account balance in APT.
  Future<BigInt> getAccountBalance(AptosAddress address) async {
    try {
      final resource = await getAccountResource(
        address,
        '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
      );
      final coinStore = AptosCoinStore.fromJson(resource.data);
      return coinStore.coin.value;
    } catch (e) {
      // Account might not have the coin store registered
      return BigInt.zero;
    }
  }

  // === Block API ===

  /// Gets a block by height.
  Future<AptosBlock> getBlockByHeight(
    BigInt blockHeight, {
    bool withTransactions = false,
  }) async {
    final result = await _get(
      '/blocks/by_height/$blockHeight',
      {'with_transactions': withTransactions.toString()},
    );
    return AptosBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Gets a block by version.
  Future<AptosBlock> getBlockByVersion(
    BigInt version, {
    bool withTransactions = false,
  }) async {
    final result = await _get(
      '/blocks/by_version/$version',
      {'with_transactions': withTransactions.toString()},
    );
    return AptosBlock.fromJson(result as Map<String, dynamic>);
  }

  // === Transaction API ===

  /// Gets transactions.
  Future<List<AptosTransactionResponse>> getTransactions({
    int? limit,
    BigInt? start,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (start != null) params['start'] = start.toString();

    final result = await _get('/transactions', params.isNotEmpty ? params : null);
    return (result as List)
        .map((e) => AptosTransactionResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a transaction by hash.
  Future<AptosTransactionResponse> getTransactionByHash(String hash) async {
    final result = await _get('/transactions/by_hash/$hash');
    return AptosTransactionResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Gets a transaction by version.
  Future<AptosTransactionResponse> getTransactionByVersion(
    BigInt version,
  ) async {
    final result = await _get('/transactions/by_version/$version');
    return AptosTransactionResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Gets account transactions.
  Future<List<AptosTransactionResponse>> getAccountTransactions(
    AptosAddress address, {
    int? limit,
    BigInt? start,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (start != null) params['start'] = start.toString();

    final result = await _get(
      '/accounts/${address.toHex()}/transactions',
      params.isNotEmpty ? params : null,
    );
    return (result as List)
        .map((e) => AptosTransactionResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submits a transaction.
  Future<AptosPendingTransactionResponse> submitTransaction(
    Map<String, dynamic> signedTransaction,
  ) async {
    final result = await _post('/transactions', signedTransaction);
    return AptosPendingTransactionResponse.fromJson(
      result as Map<String, dynamic>,
    );
  }

  /// Submits a BCS-encoded transaction.
  Future<AptosPendingTransactionResponse> submitBcsTransaction(
    String bcsHex,
  ) async {
    final response = await _client.post(
      Uri.parse('$rpcUrl/transactions'),
      headers: {'Content-Type': 'application/x.aptos.signed_transaction+bcs'},
      body: _hexToBytes(bcsHex),
    );

    if (response.statusCode >= 400) {
      throw AptosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return AptosPendingTransactionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Simulates a transaction.
  Future<List<AptosTransactionResponse>> simulateTransaction(
    Map<String, dynamic> transaction, {
    bool estimateGasUnitPrice = false,
    bool estimateMaxGasAmount = false,
    bool estimatePrioritizedGasUnitPrice = false,
  }) async {
    final params = <String, String>{};
    if (estimateGasUnitPrice) params['estimate_gas_unit_price'] = 'true';
    if (estimateMaxGasAmount) params['estimate_max_gas_amount'] = 'true';
    if (estimatePrioritizedGasUnitPrice) {
      params['estimate_prioritized_gas_unit_price'] = 'true';
    }

    final uri = Uri.parse('$rpcUrl/transactions/simulate')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction),
    );

    if (response.statusCode >= 400) {
      throw AptosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final result = jsonDecode(response.body);
    return (result as List)
        .map((e) => AptosTransactionResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Encodes a transaction for signing.
  Future<String> encodeSubmission(Map<String, dynamic> request) async {
    final result = await _post('/transactions/encode_submission', request);
    return result as String;
  }

  // === Events API ===

  /// Gets events by creation number.
  Future<List<AptosEvent>> getEventsByCreationNumber(
    AptosAddress address,
    BigInt creationNumber, {
    int? limit,
    BigInt? start,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (start != null) params['start'] = start.toString();

    final result = await _get(
      '/accounts/${address.toHex()}/events/$creationNumber',
      params.isNotEmpty ? params : null,
    );
    return (result as List)
        .map((e) => AptosEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets events by event handle.
  Future<List<AptosEvent>> getEventsByEventHandle(
    AptosAddress address,
    String eventHandleStruct,
    String fieldName, {
    int? limit,
    BigInt? start,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (start != null) params['start'] = start.toString();

    final result = await _get(
      '/accounts/${address.toHex()}/events/$eventHandleStruct/$fieldName',
      params.isNotEmpty ? params : null,
    );
    return (result as List)
        .map((e) => AptosEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // === View API ===

  /// Executes a view function.
  Future<List<dynamic>> view({
    required String function,
    List<String> typeArguments = const [],
    List<dynamic> arguments = const [],
  }) async {
    final result = await _post('/view', {
      'function': function,
      'type_arguments': typeArguments,
      'arguments': arguments,
    });
    return result as List<dynamic>;
  }

  // === Table API ===

  /// Gets a table item.
  Future<dynamic> getTableItem(
    String tableHandle,
    String keyType,
    String valueType,
    dynamic key, {
    BigInt? ledgerVersion,
  }) async {
    final path = '/tables/$tableHandle/item';
    final params = ledgerVersion != null
        ? {'ledger_version': ledgerVersion.toString()}
        : null;

    final uri = Uri.parse('$rpcUrl$path').replace(queryParameters: params);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'key_type': keyType,
        'value_type': valueType,
        'key': key,
      }),
    );

    if (response.statusCode >= 400) {
      throw AptosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  /// Waits for a transaction to be confirmed.
  Future<AptosTransactionResponse> waitForTransaction(
    String hash, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final tx = await getTransactionByHash(hash);
        return tx;
      } catch (e) {
        if (e is AptosApiException && e.statusCode == 404) {
          // Transaction not yet confirmed, keep polling
          await Future<void>.delayed(pollInterval);
        } else {
          rethrow;
        }
      }
    }

    throw AptosApiException(
      'Transaction $hash not confirmed within timeout',
      statusCode: 408,
    );
  }
}

/// Aptos API exception.
class AptosApiException implements Exception {
  /// Creates an AptosApiException.
  const AptosApiException(this.message, {this.statusCode});

  /// Error message.
  final String message;

  /// HTTP status code.
  final int? statusCode;

  @override
  String toString() => 'AptosApiException: $message (status: $statusCode)';
}

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
