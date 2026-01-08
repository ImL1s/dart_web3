import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'near_types.dart';
import 'near_transaction.dart';
import 'near_chains.dart';

/// NEAR JSON-RPC client.
class NearClient {
  /// Creates a NearClient with a custom RPC URL.
  NearClient(this.rpcUrl) : _client = http.Client();

  /// Creates a NearClient from a chain configuration.
  factory NearClient.fromChain(NearChainConfig chain) {
    return NearClient(chain.rpcUrl);
  }

  /// Creates a NearClient for mainnet.
  factory NearClient.mainnet() => NearClient.fromChain(NearChains.mainnet);

  /// Creates a NearClient for testnet.
  factory NearClient.testnet() => NearClient.fromChain(NearChains.testnet);

  /// The RPC endpoint URL.
  final String rpcUrl;

  final http.Client _client;

  int _requestId = 0;

  /// Closes the client.
  void close() {
    _client.close();
  }

  /// Sends a JSON-RPC request.
  Future<dynamic> _rpcCall(String method, dynamic params) async {
    final requestId = ++_requestId;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params,
    });

    final response = await _client.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw NearRpcException('HTTP ${response.statusCode}: ${response.body}');
    }

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      throw NearRpcException(
        result['error']['message'] as String? ?? 'Unknown error',
        code: result['error']['code'] as int?,
        data: result['error']['data'],
      );
    }

    return result['result'];
  }

  // === Network ===

  /// Gets node status.
  Future<Map<String, dynamic>> getStatus() async {
    final result = await _rpcCall('status', {});
    return result as Map<String, dynamic>;
  }

  /// Gets protocol config.
  Future<NearProtocolConfig> getProtocolConfig({String? blockId}) async {
    final result = await _rpcCall('EXPERIMENTAL_protocol_config', {
      'finality': blockId ?? 'final',
    });
    return NearProtocolConfig.fromJson(result as Map<String, dynamic>);
  }

  /// Gets gas price.
  Future<NearGasPrice> getGasPrice({String? blockId}) async {
    final result = await _rpcCall('gas_price', [blockId]);
    return NearGasPrice.fromJson(result as Map<String, dynamic>);
  }

  /// Gets validators.
  Future<Map<String, dynamic>> getValidators({String? epochId}) async {
    final result = await _rpcCall('validators', [epochId]);
    return result as Map<String, dynamic>;
  }

  // === Block ===

  /// Gets a block by ID.
  Future<NearBlock> getBlock({String? blockId, BigInt? blockHeight}) async {
    final params = <String, dynamic>{};
    if (blockId != null) {
      params['block_id'] = blockId;
    } else if (blockHeight != null) {
      params['block_id'] = blockHeight.toInt();
    } else {
      params['finality'] = 'final';
    }

    final result = await _rpcCall('block', params);
    return NearBlock.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the latest finalized block.
  Future<NearBlock> getLatestBlock() async {
    return getBlock();
  }

  /// Gets a chunk.
  Future<Map<String, dynamic>> getChunk({
    String? chunkId,
    String? blockId,
    int? shardId,
  }) async {
    final params = <String, dynamic>{};
    if (chunkId != null) {
      params['chunk_id'] = chunkId;
    } else if (blockId != null && shardId != null) {
      params['block_id'] = blockId;
      params['shard_id'] = shardId;
    }

    final result = await _rpcCall('chunk', params);
    return result as Map<String, dynamic>;
  }

  // === Account ===

  /// Gets account information.
  Future<NearAccount> getAccount(
    String accountId, {
    String? blockId,
  }) async {
    final result = await _rpcCall('query', {
      'request_type': 'view_account',
      'finality': blockId ?? 'final',
      'account_id': accountId,
    });
    return NearAccount.fromJson(result as Map<String, dynamic>);
  }

  /// Checks if an account exists.
  Future<bool> accountExists(String accountId) async {
    try {
      await getAccount(accountId);
      return true;
    } on NearRpcException catch (e) {
      if (e.data?.toString().contains('UNKNOWN_ACCOUNT') == true) {
        return false;
      }
      rethrow;
    }
  }

  /// Gets access key information.
  Future<NearAccessKey> getAccessKey(
    String accountId,
    String publicKey, {
    String? blockId,
  }) async {
    final result = await _rpcCall('query', {
      'request_type': 'view_access_key',
      'finality': blockId ?? 'final',
      'account_id': accountId,
      'public_key': publicKey,
    });
    return NearAccessKey.fromJson(result as Map<String, dynamic>);
  }

  /// Gets all access keys for an account.
  Future<List<Map<String, dynamic>>> getAccessKeyList(
    String accountId, {
    String? blockId,
  }) async {
    final result = await _rpcCall('query', {
      'request_type': 'view_access_key_list',
      'finality': blockId ?? 'final',
      'account_id': accountId,
    });
    return ((result as Map<String, dynamic>)['keys'] as List)
        .cast<Map<String, dynamic>>();
  }

  // === Contract ===

  /// Views contract state.
  Future<Map<String, dynamic>> viewContractState(
    String accountId, {
    String? prefix,
    String? blockId,
  }) async {
    final result = await _rpcCall('query', {
      'request_type': 'view_state',
      'finality': blockId ?? 'final',
      'account_id': accountId,
      'prefix_base64': prefix ?? '',
    });
    return result as Map<String, dynamic>;
  }

  /// Calls a view function.
  Future<Map<String, dynamic>> viewFunction({
    required String accountId,
    required String methodName,
    Map<String, dynamic>? args,
    String? blockId,
  }) async {
    final argsBase64 = args != null
        ? base64Encode(utf8.encode(jsonEncode(args)))
        : '';

    final result = await _rpcCall('query', {
      'request_type': 'call_function',
      'finality': blockId ?? 'final',
      'account_id': accountId,
      'method_name': methodName,
      'args_base64': argsBase64,
    });
    return result as Map<String, dynamic>;
  }

  /// Decodes view function result.
  dynamic decodeViewResult(Map<String, dynamic> result) {
    final resultBytes = (result['result'] as List).cast<int>();
    final jsonString = utf8.decode(resultBytes);
    return jsonDecode(jsonString);
  }

  /// Gets contract code.
  Future<Map<String, dynamic>> getContractCode(
    String accountId, {
    String? blockId,
  }) async {
    final result = await _rpcCall('query', {
      'request_type': 'view_code',
      'finality': blockId ?? 'final',
      'account_id': accountId,
    });
    return result as Map<String, dynamic>;
  }

  // === Transaction ===

  /// Sends a signed transaction and waits for result.
  Future<NearTransactionOutcome> sendTransaction(
    SignedNearTransaction signedTx,
  ) async {
    final result = await _rpcCall('broadcast_tx_commit', signedTx.toRpcParams());
    return NearTransactionOutcome.fromJson(result as Map<String, dynamic>);
  }

  /// Sends a signed transaction asynchronously.
  Future<String> sendTransactionAsync(SignedNearTransaction signedTx) async {
    final result = await _rpcCall('broadcast_tx_async', signedTx.toRpcParams());
    return result as String;
  }

  /// Gets transaction status.
  Future<NearTransactionOutcome> getTransactionStatus(
    String txHash,
    String senderId,
  ) async {
    final result = await _rpcCall('tx', [txHash, senderId]);
    return NearTransactionOutcome.fromJson(result as Map<String, dynamic>);
  }

  /// Gets transaction status with receipts.
  Future<NearTransactionOutcome> getTransactionStatusWithReceipts(
    String txHash,
    String senderId,
  ) async {
    final result = await _rpcCall('EXPERIMENTAL_tx_status', [txHash, senderId]);
    return NearTransactionOutcome.fromJson(result as Map<String, dynamic>);
  }

  /// Waits for a transaction to complete.
  Future<NearTransactionOutcome> waitForTransaction(
    String txHash,
    String senderId, {
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final outcome = await getTransactionStatus(txHash, senderId);
        return outcome;
      } on NearRpcException catch (e) {
        if (e.data?.toString().contains('UNKNOWN_TRANSACTION') == true) {
          await Future<void>.delayed(pollInterval);
        } else {
          rethrow;
        }
      }
    }

    throw NearRpcException('Transaction $txHash not found within timeout');
  }

  // === Light Client ===

  /// Gets light client proof.
  Future<Map<String, dynamic>> getLightClientProof({
    required String type,
    required String accountId,
    String? publicKey,
    String? blockId,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      'account_id': accountId,
    };
    if (publicKey != null) params['public_key'] = publicKey;
    if (blockId != null) {
      params['light_client_head'] = blockId;
    }

    final result = await _rpcCall('EXPERIMENTAL_light_client_proof', params);
    return result as Map<String, dynamic>;
  }
}

/// NEAR RPC exception.
class NearRpcException implements Exception {
  /// Creates a NearRpcException.
  const NearRpcException(this.message, {this.code, this.data});

  /// Error message.
  final String message;

  /// Error code.
  final int? code;

  /// Error data.
  final dynamic data;

  @override
  String toString() => 'NearRpcException: $message (code: $code, data: $data)';
}
