import 'package:web3_universal_provider/web3_universal_provider.dart';

import 'user_operation.dart';

/// Bundler client for ERC-4337 UserOperation submission and management.
/// 
/// The Bundler is responsible for:
/// - Accepting UserOperations from users
/// - Validating UserOperations
/// - Estimating gas for UserOperations
/// - Bundling UserOperations into transactions
/// - Submitting bundles to the EntryPoint contract
class BundlerClient {

  BundlerClient({
    required String bundlerUrl,
    RpcProvider? provider,
    this.entryPointVersion = EntryPointVersion.v07,
  }) : _bundlerUrl = bundlerUrl,
       _provider = provider ?? RpcProvider(HttpTransport(bundlerUrl));
  final RpcProvider _provider;
  final String _bundlerUrl;
  final EntryPointVersion entryPointVersion;

  /// Gets the bundler URL for testing purposes.
  String get bundlerUrl => _bundlerUrl;

  /// Sends a UserOperation to the bundler.
  /// 
  /// Returns the userOpHash that can be used to track the operation.
  Future<String> sendUserOperation(UserOperation userOp) async {
    final result = await _provider.call<String>(
      'eth_sendUserOperation',
      [userOp.toJson(entryPointVersion), _getEntryPointAddress()],
    );
    return result;
  }

  /// Estimates gas for a UserOperation.
  /// 
  /// Returns gas estimates for different parts of the operation:
  /// - preVerificationGas: Gas for pre-verification
  /// - verificationGasLimit: Gas for verification
  /// - callGasLimit: Gas for execution
  /// - paymasterVerificationGasLimit: Gas for paymaster verification (if applicable)
  /// - paymasterPostOpGasLimit: Gas for paymaster post-operation (if applicable)
  Future<UserOperationGasEstimate> estimateUserOperationGas(
    UserOperation userOp, {
    String? entryPoint,
  }) async {
    final result = await _provider.call<Map<String, dynamic>>(
      'eth_estimateUserOperationGas',
      [userOp.toJson(entryPointVersion), entryPoint ?? _getEntryPointAddress()],
    );
    return UserOperationGasEstimate.fromJson(result);
  }

  /// Gets a UserOperation by its hash.
  /// 
  /// Returns null if the UserOperation is not found.
  Future<UserOperationByHashResult?> getUserOperationByHash(String userOpHash) async {
    try {
      final result = await _provider.call<Map<String, dynamic>?>(
        'eth_getUserOperationByHash',
        [userOpHash],
      );
      
      if (result == null) return null;
      return UserOperationByHashResult.fromJson(result);
    } on Exception catch (_) {
      // UserOperation not found
      return null;
    }
  }

  /// Gets the receipt for a UserOperation.
  /// 
  /// Returns null if the UserOperation has not been included in a block yet.
  Future<UserOperationReceipt?> getUserOperationReceipt(String userOpHash) async {
    try {
      final result = await _provider.call<Map<String, dynamic>?>(
        'eth_getUserOperationReceipt',
        [userOpHash],
      );
      
      if (result == null) return null;
      return UserOperationReceipt.fromJson(result);
    } on Exception catch (_) {
      // Receipt not available yet
      return null;
    }
  }

  /// Waits for a UserOperation receipt.
  /// 
  /// Polls the bundler until the UserOperation is included in a block.
  /// Throws a [TimeoutException] if the timeout is reached.
  Future<UserOperationReceipt> waitForUserOperationReceipt(
    String userOpHash, {
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < timeout) {
      final receipt = await getUserOperationReceipt(userOpHash);
      if (receipt != null) {
        return receipt;
      }
      
      await Future<void>.delayed(pollInterval);
    }
    
    throw TimeoutException(
      'UserOperation receipt not received within timeout',
      timeout,
    );
  }

  /// Gets the supported EntryPoint addresses by this bundler.
  Future<List<String>> getSupportedEntryPoints() async {
    final result = await _provider.call<List<dynamic>>(
      'eth_supportedEntryPoints',
      [],
    );
    return result.cast<String>();
  }

  /// Gets the chain ID supported by this bundler.
  Future<int> getChainId() async {
    final result = await _provider.call<String>('eth_chainId', []);
    return int.parse(result);
  }

  /// Estimates gas for multiple UserOperations in a batch.
  /// 
  /// This is useful for optimizing gas costs when submitting multiple operations.
  Future<List<UserOperationGasEstimate>> batchEstimateUserOperationGas(
    List<UserOperation> userOps, {
    String? entryPoint,
  }) async {
    final requests = userOps.map((userOp) => RpcRequest(
      'eth_estimateUserOperationGas',
      [userOp.toJson(), entryPoint ?? _getEntryPointAddress()],
    ),).toList();

    final results = await _provider.batchCall<Map<String, dynamic>>(requests);
    return results.map(UserOperationGasEstimate.fromJson).toList();
  }

  /// Sends multiple UserOperations in a batch.
  /// 
  /// Returns a list of userOpHashes for tracking the operations.
  Future<List<String>> batchSendUserOperation(List<UserOperation> userOps) async {
    final requests = userOps.map((userOp) => RpcRequest(
      'eth_sendUserOperation',
      [userOp.toJson(), _getEntryPointAddress()],
    ),).toList();

    final results = await _provider.batchCall<String>(requests);
    return results;
  }

  /// Gets the default EntryPoint address for this bundler.
  /// 
  /// This is typically the latest EntryPoint version supported.
  String getEntryPointAddress() {
    // Note: This should be configurable or fetched from the bundler
    // For now, return EntryPoint v0.7 address
    return '0x0000000071727De22E5E9d8BAf0edAc6f37da032';
  }

  /// Gets the default EntryPoint address for this bundler (internal).
  String _getEntryPointAddress() => getEntryPointAddress();

  /// Disposes of the bundler client and cleans up resources.
  void dispose() {
    _provider.dispose();
  }
}

/// Result from getUserOperationByHash
class UserOperationByHashResult {

  UserOperationByHashResult({
    required this.blockHash,
    required this.blockNumber,
    required this.entryPoint,
    required this.transactionHash,
    required this.userOperation,
  });

  factory UserOperationByHashResult.fromJson(Map<String, dynamic> json) {
    return UserOperationByHashResult(
      blockHash: json['blockHash'] as String,
      blockNumber: BigInt.parse(json['blockNumber'] as String),
      entryPoint: json['entryPoint'] as String,
      transactionHash: json['transactionHash'] as String,
      userOperation: UserOperation.fromJson(json['userOperation'] as Map<String, dynamic>),
    );
  }
  final String blockHash;
  final BigInt blockNumber;
  final String entryPoint;
  final String transactionHash;
  final UserOperation userOperation;

  Map<String, dynamic> toJson() {
    return {
      'blockHash': blockHash,
      'blockNumber': '0x${blockNumber.toRadixString(16)}',
      'entryPoint': entryPoint,
      'transactionHash': transactionHash,
      'userOperation': userOperation.toJson(),
    };
  }
}

/// Exception thrown when a bundler operation times out.
class TimeoutException implements Exception {

  TimeoutException(this.message, this.timeout);
  final String message;
  final Duration timeout;

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}

/// Bundler error codes according to ERC-4337
enum BundlerErrorCode {
  /// UserOperation validation failed
  validationFailed(-32602),
  
  /// UserOperation simulation failed
  simulationFailed(-32500),
  
  /// UserOperation rejected by paymaster
  paymasterRejected(-32501),
  
  /// UserOperation rejected due to opcode validation
  opcodeValidationFailed(-32502),
  
  /// UserOperation rejected due to time range validation
  timeRangeValidationFailed(-32503),
  
  /// UserOperation rejected due to paymaster validation
  paymasterValidationFailed(-32504),
  
  /// UserOperation rejected due to paymaster deposit too low
  paymasterDepositTooLow(-32505),
  
  /// UserOperation rejected due to unsupported signature aggregator
  unsupportedSignatureAggregator(-32506),
  
  /// UserOperation rejected due to invalid signature aggregator
  invalidSignatureAggregator(-32507);

  const BundlerErrorCode(this.code);
  final int code;
}

/// Exception thrown by bundler operations
class BundlerException implements Exception {

  BundlerException({
    required this.errorCode,
    required this.message,
    this.data,
  });

  factory BundlerException.fromRpcError(Map<String, dynamic> error) {
    final code = error['code'] as int;
    final message = error['message'] as String;
    final data = error['data'] as Map<String, dynamic>?;

    // Find matching error code
    BundlerErrorCode? errorCode;
    for (final bundlerError in BundlerErrorCode.values) {
      if (bundlerError.code == code) {
        errorCode = bundlerError;
        break;
      }
    }

    return BundlerException(
      errorCode: errorCode ?? BundlerErrorCode.validationFailed,
      message: message,
      data: data,
    );
  }
  final BundlerErrorCode errorCode;
  final String message;
  final Map<String, dynamic>? data;

  @override
  String toString() {
    final buffer = StringBuffer('BundlerException: ${errorCode.name} ($message)');
    if (data != null) {
      buffer.write(' - Data: $data');
    }
    return buffer.toString();
  }
}
