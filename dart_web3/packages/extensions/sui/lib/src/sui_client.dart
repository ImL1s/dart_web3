import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sui_chains.dart';
import 'sui_types.dart';

/// Sui JSON-RPC client.
class SuiClient {
  /// Creates a SuiClient with a custom RPC URL.
  SuiClient(this.rpcUrl) : _client = http.Client();

  /// Creates a SuiClient from a chain configuration.
  factory SuiClient.fromChain(SuiChainConfig chain) {
    return SuiClient(chain.rpcUrl);
  }

  /// Creates a SuiClient for mainnet.
  factory SuiClient.mainnet() => SuiClient.fromChain(SuiChains.mainnet);

  /// Creates a SuiClient for testnet.
  factory SuiClient.testnet() => SuiClient.fromChain(SuiChains.testnet);

  /// Creates a SuiClient for devnet.
  factory SuiClient.devnet() => SuiClient.fromChain(SuiChains.devnet);

  /// The RPC endpoint URL.
  final String rpcUrl;

  final http.Client _client;

  int _requestId = 0;

  /// Closes the client.
  void close() {
    _client.close();
  }

  /// Sends a JSON-RPC request.
  Future<dynamic> _rpcCall(String method, [List<dynamic>? params]) async {
    final requestId = ++_requestId;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params ?? [],
    });

    final response = await _client.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw SuiRpcException('HTTP ${response.statusCode}: ${response.body}');
    }

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      throw SuiRpcException(
        result['error']['message'] as String,
        code: result['error']['code'] as int?,
      );
    }

    return result['result'];
  }

  // === Read API ===

  /// Gets an object by ID.
  Future<SuiObjectResponse> getObject(
    SuiObjectId objectId, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await _rpcCall('sui_getObject', [
      objectId.toHex(),
      options?.toJson() ?? {},
    ]);
    return SuiObjectResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Gets multiple objects by IDs.
  Future<List<SuiObjectResponse>> getMultipleObjects(
    List<SuiObjectId> objectIds, {
    SuiObjectDataOptions? options,
  }) async {
    final result = await _rpcCall('sui_multiGetObjects', [
      objectIds.map((id) => id.toHex()).toList(),
      options?.toJson() ?? {},
    ]);
    return (result as List)
        .map((e) => SuiObjectResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets objects owned by an address.
  Future<SuiPaginatedResponse<SuiObjectResponse>> getOwnedObjects(
    SuiAddress address, {
    SuiObjectDataOptions? options,
    String? cursor,
    int? limit,
  }) async {
    final result = await _rpcCall('suix_getOwnedObjects', [
      address.toHex(),
      {'options': options?.toJson() ?? {}},
      cursor,
      limit,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (e) => SuiObjectResponse.fromJson(e as Map<String, dynamic>),
    );
  }

  /// Gets the coins owned by an address.
  Future<SuiPaginatedResponse<SuiCoin>> getCoins(
    SuiAddress address, {
    String? coinType,
    String? cursor,
    int? limit,
  }) async {
    final result = await _rpcCall('suix_getCoins', [
      address.toHex(),
      coinType,
      cursor,
      limit,
    ]);
    return SuiPaginatedResponse.fromJson(
      result as Map<String, dynamic>,
      (e) => SuiCoin.fromJson(e as Map<String, dynamic>),
    );
  }

  /// Gets the total balance for a coin type.
  Future<SuiBalance> getBalance(
    SuiAddress address, {
    String? coinType,
  }) async {
    final result = await _rpcCall('suix_getBalance', [
      address.toHex(),
      coinType,
    ]);
    return SuiBalance.fromJson(result as Map<String, dynamic>);
  }

  /// Gets all balances for an address.
  Future<List<SuiBalance>> getAllBalances(SuiAddress address) async {
    final result = await _rpcCall('suix_getAllBalances', [address.toHex()]);
    return (result as List)
        .map((e) => SuiBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // === System State API ===

  /// Gets the reference gas price for the current epoch.
  Future<BigInt> getReferenceGasPrice() async {
    final result = await _rpcCall('suix_getReferenceGasPrice');
    return BigInt.parse(result as String);
  }

  /// Gets the latest Sui system state.
  Future<SuiSystemState> getLatestSuiSystemState() async {
    final result = await _rpcCall('suix_getLatestSuiSystemState');
    return SuiSystemState.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the total supply of a coin type.
  Future<SuiCoinSupply> getTotalSupply(String coinType) async {
    final result = await _rpcCall('suix_getTotalSupply', [coinType]);
    return SuiCoinSupply.fromJson(result as Map<String, dynamic>);
  }

  // === Transaction API ===

  /// Gets a transaction block by digest.
  Future<SuiTransactionBlockResponse> getTransactionBlock(
    SuiDigest digest, {
    SuiTransactionBlockResponseOptions? options,
  }) async {
    final result = await _rpcCall('sui_getTransactionBlock', [
      digest.toString(),
      options?.toJson() ?? {},
    ]);
    return SuiTransactionBlockResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Executes a transaction block.
  Future<SuiTransactionBlockResponse> executeTransactionBlock({
    required String txBytes,
    required List<String> signatures,
    SuiTransactionBlockResponseOptions? options,
  }) async {
    final result = await _rpcCall('sui_executeTransactionBlock', [
      txBytes,
      signatures,
      options?.toJson() ?? {},
      'WaitForLocalExecution',
    ]);
    return SuiTransactionBlockResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Dry runs a transaction block.
  Future<SuiDryRunResult> dryRunTransactionBlock(String txBytes) async {
    final result = await _rpcCall('sui_dryRunTransactionBlock', [txBytes]);
    return SuiDryRunResult.fromJson(result as Map<String, dynamic>);
  }

  // === Move API ===

  /// Gets the normalized Move function.
  Future<SuiMoveNormalizedFunction> getNormalizedMoveFunction({
    required String package,
    required String module,
    required String function,
  }) async {
    final result = await _rpcCall('sui_getNormalizedMoveFunction', [
      package,
      module,
      function,
    ]);
    return SuiMoveNormalizedFunction.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the normalized Move module.
  Future<SuiMoveNormalizedModule> getNormalizedMoveModule({
    required String package,
    required String module,
  }) async {
    final result = await _rpcCall('sui_getNormalizedMoveModule', [
      package,
      module,
    ]);
    return SuiMoveNormalizedModule.fromJson(result as Map<String, dynamic>);
  }
}

/// Sui RPC exception.
class SuiRpcException implements Exception {
  /// Creates a SuiRpcException.
  const SuiRpcException(this.message, {this.code});

  /// Error message.
  final String message;

  /// Error code.
  final int? code;

  @override
  String toString() => 'SuiRpcException: $message (code: $code)';
}

/// Options for object data retrieval.
class SuiObjectDataOptions {
  /// Creates SuiObjectDataOptions.
  const SuiObjectDataOptions({
    this.showType = false,
    this.showContent = false,
    this.showBcs = false,
    this.showOwner = false,
    this.showPreviousTransaction = false,
    this.showStorageRebate = false,
    this.showDisplay = false,
  });

  /// Full options.
  static const full = SuiObjectDataOptions(
    showType: true,
    showContent: true,
    showBcs: true,
    showOwner: true,
    showPreviousTransaction: true,
    showStorageRebate: true,
    showDisplay: true,
  );

  final bool showType;
  final bool showContent;
  final bool showBcs;
  final bool showOwner;
  final bool showPreviousTransaction;
  final bool showStorageRebate;
  final bool showDisplay;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'showType': showType,
    'showContent': showContent,
    'showBcs': showBcs,
    'showOwner': showOwner,
    'showPreviousTransaction': showPreviousTransaction,
    'showStorageRebate': showStorageRebate,
    'showDisplay': showDisplay,
  };
}

/// Sui object response.
class SuiObjectResponse {
  /// Creates a SuiObjectResponse.
  const SuiObjectResponse({this.data, this.error});

  /// Creates from JSON.
  factory SuiObjectResponse.fromJson(Map<String, dynamic> json) {
    return SuiObjectResponse(
      data: json['data'] != null
          ? SuiObjectData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as Map<String, dynamic>?,
    );
  }

  /// Object data (if successful).
  final SuiObjectData? data;

  /// Error (if failed).
  final Map<String, dynamic>? error;
}

/// Sui object data.
class SuiObjectData {
  /// Creates SuiObjectData.
  const SuiObjectData({
    required this.objectId,
    required this.version,
    this.digest,
    this.type,
    this.owner,
    this.content,
  });

  /// Creates from JSON.
  factory SuiObjectData.fromJson(Map<String, dynamic> json) {
    return SuiObjectData(
      objectId: SuiObjectId.fromHex(json['objectId'] as String),
      version: BigInt.parse(json['version'] as String),
      digest: json['digest'] != null
          ? SuiDigest.fromBase58(json['digest'] as String)
          : null,
      type: json['type'] as String?,
      owner: json['owner'] as Map<String, dynamic>?,
      content: json['content'] as Map<String, dynamic>?,
    );
  }

  final SuiObjectId objectId;
  final BigInt version;
  final SuiDigest? digest;
  final String? type;
  final Map<String, dynamic>? owner;
  final Map<String, dynamic>? content;
}

/// Paginated response.
class SuiPaginatedResponse<T> {
  /// Creates a SuiPaginatedResponse.
  const SuiPaginatedResponse({
    required this.data,
    this.nextCursor,
    required this.hasNextPage,
  });

  /// Creates from JSON.
  factory SuiPaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return SuiPaginatedResponse(
      data: (json['data'] as List).map(fromJsonT).toList(),
      nextCursor: json['nextCursor'] as String?,
      hasNextPage: json['hasNextPage'] as bool,
    );
  }

  final List<T> data;
  final String? nextCursor;
  final bool hasNextPage;
}

/// Sui coin.
class SuiCoin {
  /// Creates a SuiCoin.
  const SuiCoin({
    required this.coinType,
    required this.coinObjectId,
    required this.version,
    required this.digest,
    required this.balance,
  });

  /// Creates from JSON.
  factory SuiCoin.fromJson(Map<String, dynamic> json) {
    return SuiCoin(
      coinType: json['coinType'] as String,
      coinObjectId: SuiObjectId.fromHex(json['coinObjectId'] as String),
      version: BigInt.parse(json['version'] as String),
      digest: SuiDigest.fromBase58(json['digest'] as String),
      balance: BigInt.parse(json['balance'] as String),
    );
  }

  final String coinType;
  final SuiObjectId coinObjectId;
  final BigInt version;
  final SuiDigest digest;
  final BigInt balance;
}

/// Sui balance.
class SuiBalance {
  /// Creates a SuiBalance.
  const SuiBalance({
    required this.coinType,
    required this.coinObjectCount,
    required this.totalBalance,
  });

  /// Creates from JSON.
  factory SuiBalance.fromJson(Map<String, dynamic> json) {
    return SuiBalance(
      coinType: json['coinType'] as String,
      coinObjectCount: json['coinObjectCount'] as int,
      totalBalance: BigInt.parse(json['totalBalance'] as String),
    );
  }

  final String coinType;
  final int coinObjectCount;
  final BigInt totalBalance;
}

/// Sui system state.
class SuiSystemState {
  /// Creates a SuiSystemState.
  const SuiSystemState({
    required this.epoch,
    required this.protocolVersion,
    required this.systemStateVersion,
    required this.referenceGasPrice,
  });

  /// Creates from JSON.
  factory SuiSystemState.fromJson(Map<String, dynamic> json) {
    return SuiSystemState(
      epoch: BigInt.parse(json['epoch'] as String),
      protocolVersion: BigInt.parse(json['protocolVersion'] as String),
      systemStateVersion: BigInt.parse(json['systemStateVersion'] as String),
      referenceGasPrice: BigInt.parse(json['referenceGasPrice'] as String),
    );
  }

  final BigInt epoch;
  final BigInt protocolVersion;
  final BigInt systemStateVersion;
  final BigInt referenceGasPrice;
}

/// Sui coin supply.
class SuiCoinSupply {
  /// Creates a SuiCoinSupply.
  const SuiCoinSupply({required this.value});

  /// Creates from JSON.
  factory SuiCoinSupply.fromJson(Map<String, dynamic> json) {
    return SuiCoinSupply(value: BigInt.parse(json['value'] as String));
  }

  final BigInt value;
}

/// Transaction block response options.
class SuiTransactionBlockResponseOptions {
  /// Creates SuiTransactionBlockResponseOptions.
  const SuiTransactionBlockResponseOptions({
    this.showInput = false,
    this.showEffects = false,
    this.showEvents = false,
    this.showObjectChanges = false,
    this.showBalanceChanges = false,
    this.showRawInput = false,
  });

  /// Full options.
  static const full = SuiTransactionBlockResponseOptions(
    showInput: true,
    showEffects: true,
    showEvents: true,
    showObjectChanges: true,
    showBalanceChanges: true,
  );

  final bool showInput;
  final bool showEffects;
  final bool showEvents;
  final bool showObjectChanges;
  final bool showBalanceChanges;
  final bool showRawInput;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'showInput': showInput,
    'showEffects': showEffects,
    'showEvents': showEvents,
    'showObjectChanges': showObjectChanges,
    'showBalanceChanges': showBalanceChanges,
    'showRawInput': showRawInput,
  };
}

/// Transaction block response.
class SuiTransactionBlockResponse {
  /// Creates a SuiTransactionBlockResponse.
  const SuiTransactionBlockResponse({
    required this.digest,
    this.transaction,
    this.effects,
    this.events,
    this.objectChanges,
    this.balanceChanges,
    this.timestampMs,
    this.errors,
  });

  /// Creates from JSON.
  factory SuiTransactionBlockResponse.fromJson(Map<String, dynamic> json) {
    return SuiTransactionBlockResponse(
      digest: SuiDigest.fromBase58(json['digest'] as String),
      transaction: json['transaction'] as Map<String, dynamic>?,
      effects: json['effects'] as Map<String, dynamic>?,
      events: json['events'] as List?,
      objectChanges: json['objectChanges'] as List?,
      balanceChanges: json['balanceChanges'] as List?,
      timestampMs: json['timestampMs'] != null
          ? BigInt.parse(json['timestampMs'] as String)
          : null,
      errors: json['errors'] as List?,
    );
  }

  final SuiDigest digest;
  final Map<String, dynamic>? transaction;
  final Map<String, dynamic>? effects;
  final List? events;
  final List? objectChanges;
  final List? balanceChanges;
  final BigInt? timestampMs;
  final List? errors;
}

/// Dry run result.
class SuiDryRunResult {
  /// Creates a SuiDryRunResult.
  const SuiDryRunResult({
    required this.effects,
    this.events,
    this.objectChanges,
    this.balanceChanges,
  });

  /// Creates from JSON.
  factory SuiDryRunResult.fromJson(Map<String, dynamic> json) {
    return SuiDryRunResult(
      effects: json['effects'] as Map<String, dynamic>,
      events: json['events'] as List?,
      objectChanges: json['objectChanges'] as List?,
      balanceChanges: json['balanceChanges'] as List?,
    );
  }

  final Map<String, dynamic> effects;
  final List? events;
  final List? objectChanges;
  final List? balanceChanges;
}

/// Normalized Move function.
class SuiMoveNormalizedFunction {
  /// Creates a SuiMoveNormalizedFunction.
  const SuiMoveNormalizedFunction({
    required this.visibility,
    required this.isEntry,
    required this.typeParameters,
    required this.parameters,
    required this.return_,
  });

  /// Creates from JSON.
  factory SuiMoveNormalizedFunction.fromJson(Map<String, dynamic> json) {
    return SuiMoveNormalizedFunction(
      visibility: json['visibility'] as String,
      isEntry: json['isEntry'] as bool,
      typeParameters: json['typeParameters'] as List,
      parameters: json['parameters'] as List,
      return_: json['return'] as List,
    );
  }

  final String visibility;
  final bool isEntry;
  final List typeParameters;
  final List parameters;
  final List return_;
}

/// Normalized Move module.
class SuiMoveNormalizedModule {
  /// Creates a SuiMoveNormalizedModule.
  const SuiMoveNormalizedModule({
    required this.fileFormatVersion,
    required this.address,
    required this.name,
    required this.friends,
    required this.structs,
    required this.exposedFunctions,
  });

  /// Creates from JSON.
  factory SuiMoveNormalizedModule.fromJson(Map<String, dynamic> json) {
    return SuiMoveNormalizedModule(
      fileFormatVersion: json['fileFormatVersion'] as int,
      address: json['address'] as String,
      name: json['name'] as String,
      friends: json['friends'] as List,
      structs: json['structs'] as Map<String, dynamic>,
      exposedFunctions: json['exposedFunctions'] as Map<String, dynamic>,
    );
  }

  final int fileFormatVersion;
  final String address;
  final String name;
  final List friends;
  final Map<String, dynamic> structs;
  final Map<String, dynamic> exposedFunctions;
}
