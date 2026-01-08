import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cosmos_types.dart';
import 'cosmos_transaction.dart';
import 'cosmos_chains.dart';

/// Cosmos LCD/REST API client.
class CosmosClient {
  /// Creates a CosmosClient with a custom REST URL.
  CosmosClient(this.restUrl) : _client = http.Client();

  /// Creates a CosmosClient from a chain configuration.
  factory CosmosClient.fromChain(CosmosChainConfig chain) {
    return CosmosClient(chain.restUrl);
  }

  /// Creates a CosmosClient for Cosmos Hub.
  factory CosmosClient.cosmosHub() => CosmosClient.fromChain(CosmosChains.cosmosHub);

  /// Creates a CosmosClient for Osmosis.
  factory CosmosClient.osmosis() => CosmosClient.fromChain(CosmosChains.osmosis);

  /// The REST API endpoint URL.
  final String restUrl;

  final http.Client _client;

  /// Closes the client.
  void close() {
    _client.close();
  }

  /// Sends a GET request.
  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$restUrl$path').replace(queryParameters: queryParams);
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 400) {
      throw CosmosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  /// Sends a POST request.
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$restUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      throw CosmosApiException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  // === Node Info ===

  /// Gets node info.
  Future<Map<String, dynamic>> getNodeInfo() async {
    final result = await _get('/cosmos/base/tendermint/v1beta1/node_info');
    return result as Map<String, dynamic>;
  }

  /// Gets the latest block.
  Future<CosmosBlock> getLatestBlock() async {
    final result = await _get('/cosmos/base/tendermint/v1beta1/blocks/latest');
    return CosmosBlock.fromJson(result['block'] as Map<String, dynamic>);
  }

  /// Gets a block by height.
  Future<CosmosBlock> getBlockByHeight(BigInt height) async {
    final result = await _get('/cosmos/base/tendermint/v1beta1/blocks/$height');
    return CosmosBlock.fromJson(result['block'] as Map<String, dynamic>);
  }

  // === Auth ===

  /// Gets account information.
  Future<CosmosAccount> getAccount(String address) async {
    final result = await _get('/cosmos/auth/v1beta1/accounts/$address');
    final account = result['account'] as Map<String, dynamic>;
    return CosmosAccount.fromJson(account);
  }

  // === Bank ===

  /// Gets all balances for an address.
  Future<List<CosmosCoin>> getBalances(String address) async {
    final result = await _get('/cosmos/bank/v1beta1/balances/$address');
    return (result['balances'] as List)
        .map((e) => CosmosCoin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets balance for a specific denomination.
  Future<CosmosCoin> getBalance(String address, String denom) async {
    final result = await _get('/cosmos/bank/v1beta1/balances/$address/by_denom', {
      'denom': denom,
    });
    return CosmosCoin.fromJson(result['balance'] as Map<String, dynamic>);
  }

  /// Gets the total supply of a denomination.
  Future<CosmosCoin> getTotalSupply(String denom) async {
    final result = await _get('/cosmos/bank/v1beta1/supply/by_denom', {
      'denom': denom,
    });
    return CosmosCoin.fromJson(result['amount'] as Map<String, dynamic>);
  }

  // === Staking ===

  /// Gets all validators.
  Future<List<CosmosValidator>> getValidators({
    String? status,
    String? paginationKey,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (paginationKey != null) params['pagination.key'] = paginationKey;

    final result = await _get(
      '/cosmos/staking/v1beta1/validators',
      params.isNotEmpty ? params : null,
    );
    return (result['validators'] as List)
        .map((e) => CosmosValidator.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a validator by address.
  Future<CosmosValidator> getValidator(String validatorAddress) async {
    final result = await _get(
      '/cosmos/staking/v1beta1/validators/$validatorAddress',
    );
    return CosmosValidator.fromJson(result['validator'] as Map<String, dynamic>);
  }

  /// Gets delegations for an address.
  Future<List<CosmosDelegation>> getDelegations(String delegatorAddress) async {
    final result = await _get(
      '/cosmos/staking/v1beta1/delegations/$delegatorAddress',
    );
    return (result['delegation_responses'] as List)
        .map((e) => CosmosDelegation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific delegation.
  Future<CosmosDelegation> getDelegation(
    String delegatorAddress,
    String validatorAddress,
  ) async {
    final result = await _get(
      '/cosmos/staking/v1beta1/validators/$validatorAddress/delegations/$delegatorAddress',
    );
    return CosmosDelegation.fromJson(
      result['delegation_response'] as Map<String, dynamic>,
    );
  }

  // === Distribution ===

  /// Gets delegation rewards.
  Future<List<CosmosCoin>> getDelegationRewards(
    String delegatorAddress,
    String validatorAddress,
  ) async {
    final result = await _get(
      '/cosmos/distribution/v1beta1/delegators/$delegatorAddress/rewards/$validatorAddress',
    );
    return (result['rewards'] as List)
        .map((e) => CosmosCoin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets all delegation rewards.
  Future<Map<String, List<CosmosCoin>>> getAllDelegationRewards(
    String delegatorAddress,
  ) async {
    final result = await _get(
      '/cosmos/distribution/v1beta1/delegators/$delegatorAddress/rewards',
    );
    final rewards = <String, List<CosmosCoin>>{};
    for (final entry in result['rewards'] as List) {
      final validatorAddress = entry['validator_address'] as String;
      rewards[validatorAddress] = (entry['reward'] as List)
          .map((e) => CosmosCoin.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return rewards;
  }

  // === Governance ===

  /// Gets proposals.
  Future<List<Map<String, dynamic>>> getProposals({
    String? status,
    String? paginationKey,
  }) async {
    final params = <String, String>{};
    if (status != null) params['proposal_status'] = status;
    if (paginationKey != null) params['pagination.key'] = paginationKey;

    final result = await _get(
      '/cosmos/gov/v1beta1/proposals',
      params.isNotEmpty ? params : null,
    );
    return (result['proposals'] as List).cast<Map<String, dynamic>>();
  }

  /// Gets a proposal by ID.
  Future<Map<String, dynamic>> getProposal(BigInt proposalId) async {
    final result = await _get('/cosmos/gov/v1beta1/proposals/$proposalId');
    return result['proposal'] as Map<String, dynamic>;
  }

  // === IBC ===

  /// Gets IBC channels.
  Future<List<Map<String, dynamic>>> getIbcChannels() async {
    final result = await _get('/ibc/core/channel/v1/channels');
    return (result['channels'] as List).cast<Map<String, dynamic>>();
  }

  /// Gets an IBC channel.
  Future<IbcChannel> getIbcChannel(String portId, String channelId) async {
    final result = await _get('/ibc/core/channel/v1/channels/$channelId/ports/$portId');
    return IbcChannel.fromJson(result['channel'] as Map<String, dynamic>);
  }

  /// Gets IBC denom traces.
  Future<List<Map<String, dynamic>>> getIbcDenomTraces() async {
    final result = await _get('/ibc/apps/transfer/v1/denom_traces');
    return (result['denom_traces'] as List).cast<Map<String, dynamic>>();
  }

  /// Gets an IBC denom trace.
  Future<Map<String, dynamic>> getIbcDenomTrace(String hash) async {
    final result = await _get('/ibc/apps/transfer/v1/denom_traces/$hash');
    return result['denom_trace'] as Map<String, dynamic>;
  }

  // === Transactions ===

  /// Gets a transaction by hash.
  Future<CosmosTxResult> getTx(String txHash) async {
    final result = await _get('/cosmos/tx/v1beta1/txs/$txHash');
    return CosmosTxResult.fromJson(result as Map<String, dynamic>);
  }

  /// Searches for transactions.
  Future<List<CosmosTxResult>> searchTxs({
    required String query,
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{'events': query};
    if (limit != null) params['pagination.limit'] = limit.toString();
    if (offset != null) params['pagination.offset'] = offset.toString();

    final result = await _get('/cosmos/tx/v1beta1/txs', params);
    return (result['tx_responses'] as List)
        .map((e) => CosmosTxResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Broadcasts a transaction.
  Future<CosmosTxResult> broadcastTx(
    CosmosTx tx, {
    BroadcastMode mode = BroadcastMode.sync,
  }) async {
    final result = await _post('/cosmos/tx/v1beta1/txs', {
      'tx_bytes': _encodeTxToBase64(tx),
      'mode': mode.value,
    });
    return CosmosTxResult.fromJson(result as Map<String, dynamic>);
  }

  /// Simulates a transaction.
  Future<SimulationResult> simulateTx(CosmosTx tx) async {
    final result = await _post('/cosmos/tx/v1beta1/simulate', {
      'tx_bytes': _encodeTxToBase64(tx),
    });
    return SimulationResult.fromJson(result as Map<String, dynamic>);
  }

  /// Waits for a transaction to be included in a block.
  Future<CosmosTxResult> waitForTx(
    String txHash, {
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final tx = await getTx(txHash);
        return tx;
      } catch (e) {
        if (e is CosmosApiException && e.statusCode == 404) {
          await Future<void>.delayed(pollInterval);
        } else {
          rethrow;
        }
      }
    }

    throw CosmosApiException(
      'Transaction $txHash not found within timeout',
      statusCode: 408,
    );
  }
}

/// Cosmos API exception.
class CosmosApiException implements Exception {
  /// Creates a CosmosApiException.
  const CosmosApiException(this.message, {this.statusCode});

  /// Error message.
  final String message;

  /// HTTP status code.
  final int? statusCode;

  @override
  String toString() => 'CosmosApiException: $message (status: $statusCode)';
}

/// Broadcast modes.
enum BroadcastMode {
  /// Block mode - wait for tx to be committed.
  block('BROADCAST_MODE_BLOCK'),

  /// Sync mode - wait for CheckTx.
  sync('BROADCAST_MODE_SYNC'),

  /// Async mode - return immediately.
  async_('BROADCAST_MODE_ASYNC');

  const BroadcastMode(this.value);
  final String value;
}

/// Simulation result.
class SimulationResult {
  /// Creates a SimulationResult.
  const SimulationResult({required this.gasInfo, this.result});

  /// Creates from JSON.
  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      gasInfo: GasInfo.fromJson(json['gas_info'] as Map<String, dynamic>),
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  /// Gas information.
  final GasInfo gasInfo;

  /// Execution result.
  final Map<String, dynamic>? result;
}

/// Gas information.
class GasInfo {
  /// Creates a GasInfo.
  const GasInfo({required this.gasWanted, required this.gasUsed});

  /// Creates from JSON.
  factory GasInfo.fromJson(Map<String, dynamic> json) {
    return GasInfo(
      gasWanted: BigInt.parse(json['gas_wanted'] as String),
      gasUsed: BigInt.parse(json['gas_used'] as String),
    );
  }

  /// Gas wanted.
  final BigInt gasWanted;

  /// Gas used.
  final BigInt gasUsed;
}

/// Helper to encode transaction to Base64.
String _encodeTxToBase64(CosmosTx tx) {
  // Placeholder - would use proper Protobuf encoding
  return jsonEncode(tx.toJson());
}
