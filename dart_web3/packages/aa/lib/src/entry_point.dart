import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

import 'user_operation.dart';

/// EntryPoint contract interface for ERC-4337.
/// 
/// The EntryPoint is the singleton contract that handles UserOperation validation,
/// execution, and gas payment. Different versions have different interfaces and capabilities.
abstract class EntryPoint {
  /// The address of this EntryPoint contract.
  String get address;

  /// The version of this EntryPoint.
  EntryPointVersion get version;

  /// Handles a UserOperation.
  Future<String> handleOps(List<UserOperation> ops, String beneficiary);

  /// Handles aggregated UserOperations.
  Future<String> handleAggregatedOps(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  );

  /// Gets the nonce for an account.
  Future<BigInt> getNonce(String sender, {BigInt? key});

  /// Simulates UserOperation validation.
  Future<ValidationResult> simulateValidation(UserOperation userOp);

  /// Gets the deposit info for an account.
  Future<DepositInfo> getDepositInfo(String account);
}

/// EntryPoint v0.6 implementation.
class EntryPointV06 implements EntryPoint {
  static const String defaultAddress = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';

  final String _address;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

  EntryPointV06({
    String? address,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) : _address = address ?? defaultAddress,
       _publicClient = publicClient,
       _walletClient = walletClient;

  @override
  String get address => _address;

  @override
  EntryPointVersion get version => EntryPointVersion.v06;

  @override
  Future<String> handleOps(List<UserOperation> ops, String beneficiary) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleOps');
    }

    final callData = _encodeHandleOpsCall(ops, beneficiary);
    
    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000), // Estimate gas properly in production
    );

    return await _walletClient!.sendTransaction(txRequest);
  }

  @override
  Future<String> handleAggregatedOps(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleAggregatedOps');
    }

    final callData = _encodeHandleAggregatedOpsCall(opsPerAggregator, beneficiary);
    
    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000),
    );

    return await _walletClient!.sendTransaction(txRequest);
  }

  @override
  Future<BigInt> getNonce(String sender, {BigInt? key}) async {
    final nonceKey = key ?? BigInt.zero;
    final callData = _encodeGetNonceCall(sender, nonceKey);
    
    final result = await _publicClient.call(CallRequest(
      to: _address,
      data: HexUtils.decode(callData),
    ));
    
    return BigInt.parse(HexUtils.encode(result));
  }

  @override
  Future<ValidationResult> simulateValidation(UserOperation userOp) async {
    final callData = _encodeSimulateValidationCall(userOp);
    
    try {
      final result = await _publicClient.call(CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ));
      
      return ValidationResult.fromBytes(result);
    } catch (e) {
      // simulateValidation is expected to revert with validation data
      if (e.toString().contains('ValidationResult')) {
        // Parse the revert data to extract validation result
        return ValidationResult.fromRevertData(e.toString());
      }
      rethrow;
    }
  }

  @override
  Future<DepositInfo> getDepositInfo(String account) async {
    final callData = _encodeGetDepositInfoCall(account);
    
    final result = await _publicClient.call(CallRequest(
      to: _address,
      data: HexUtils.decode(callData),
    ));
    
    return DepositInfo.fromBytes(result);
  }

  /// Encodes handleOps function call.
  ///
  /// Function signature: handleOps(UserOperation[],address)
  /// UserOperation struct (v0.6):
  ///   - address sender
  ///   - uint256 nonce
  ///   - bytes initCode
  ///   - bytes callData
  ///   - uint256 callGasLimit
  ///   - uint256 verificationGasLimit
  ///   - uint256 preVerificationGas
  ///   - uint256 maxFeePerGas
  ///   - uint256 maxPriorityFeePerGas
  ///   - bytes paymasterAndData
  ///   - bytes signature
  String _encodeHandleOpsCall(List<UserOperation> ops, String beneficiary) {
    // handleOps(UserOperation[],address) function selector: 0x1fad948c
    final selector = '1fad948c';

    // Define UserOperation tuple type for v0.6
    final userOpTupleType = AbiTuple([
      AbiAddress(),      // sender
      AbiUint(256),      // nonce
      AbiBytes(),        // initCode
      AbiBytes(),        // callData
      AbiUint(256),      // callGasLimit
      AbiUint(256),      // verificationGasLimit
      AbiUint(256),      // preVerificationGas
      AbiUint(256),      // maxFeePerGas
      AbiUint(256),      // maxPriorityFeePerGas
      AbiBytes(),        // paymasterAndData
      AbiBytes(),        // signature
    ]);

    // Convert UserOperations to tuple values
    final opsValues = ops.map((op) => [
      op.sender,
      op.nonce,
      HexUtils.decode(op.initCode ?? '0x'),
      HexUtils.decode(op.callData),
      op.callGasLimit,
      op.verificationGasLimit,
      op.preVerificationGas,
      op.maxFeePerGas,
      op.maxPriorityFeePerGas,
      HexUtils.decode(op.paymasterAndData ?? '0x'),
      HexUtils.decode(op.signature),
    ]).toList();

    // Encode function call
    final types = [
      AbiArray(userOpTupleType),  // UserOperation[]
      AbiAddress(),               // beneficiary
    ];

    final values = [opsValues, beneficiary];
    final encoded = AbiEncoder.encode(types, values);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes handleAggregatedOps function call.
  ///
  /// Function signature: handleAggregatedOps(UserOpsPerAggregator[],address)
  /// UserOpsPerAggregator struct:
  ///   - UserOperation[] userOps
  ///   - address aggregator
  ///   - bytes signature
  String _encodeHandleAggregatedOpsCall(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) {
    // handleAggregatedOps(UserOpsPerAggregator[],address) function selector: 0x4b1d7cf5
    final selector = '4b1d7cf5';

    // Define UserOperation tuple type for v0.6
    final userOpTupleType = AbiTuple([
      AbiAddress(),      // sender
      AbiUint(256),      // nonce
      AbiBytes(),        // initCode
      AbiBytes(),        // callData
      AbiUint(256),      // callGasLimit
      AbiUint(256),      // verificationGasLimit
      AbiUint(256),      // preVerificationGas
      AbiUint(256),      // maxFeePerGas
      AbiUint(256),      // maxPriorityFeePerGas
      AbiBytes(),        // paymasterAndData
      AbiBytes(),        // signature
    ]);

    // Define UserOpsPerAggregator tuple type
    final aggregatorTupleType = AbiTuple([
      AbiArray(userOpTupleType),  // userOps
      AbiAddress(),               // aggregator
      AbiBytes(),                 // signature
    ]);

    // Convert to tuple values
    final aggregatorValues = opsPerAggregator.map((agg) {
      final opsValues = agg.userOps.map((op) => [
        op.sender,
        op.nonce,
        HexUtils.decode(op.initCode ?? '0x'),
        HexUtils.decode(op.callData),
        op.callGasLimit,
        op.verificationGasLimit,
        op.preVerificationGas,
        op.maxFeePerGas,
        op.maxPriorityFeePerGas,
        HexUtils.decode(op.paymasterAndData ?? '0x'),
        HexUtils.decode(op.signature),
      ]).toList();

      return [
        opsValues,
        agg.aggregator,
        HexUtils.decode(agg.signature),
      ];
    }).toList();

    // Encode function call
    final types = [
      AbiArray(aggregatorTupleType),  // UserOpsPerAggregator[]
      AbiAddress(),                   // beneficiary
    ];

    final values = [aggregatorValues, beneficiary];
    final encoded = AbiEncoder.encode(types, values);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes getNonce function call.
  String _encodeGetNonceCall(String sender, BigInt key) {
    // getNonce(address,uint192) function selector: 0x35567e1a
    final selector = '35567e1a';
    final paddedSender = sender.replaceFirst('0x', '').padLeft(64, '0');
    final paddedKey = key.toRadixString(16).padLeft(64, '0');
    
    return '0x$selector$paddedSender$paddedKey';
  }

  /// Encodes simulateValidation function call.
  ///
  /// Function signature: simulateValidation(UserOperation)
  String _encodeSimulateValidationCall(UserOperation userOp) {
    // simulateValidation(UserOperation) function selector: 0xee219423
    final selector = 'ee219423';

    // Define UserOperation tuple type for v0.6
    final userOpTupleType = AbiTuple([
      AbiAddress(),      // sender
      AbiUint(256),      // nonce
      AbiBytes(),        // initCode
      AbiBytes(),        // callData
      AbiUint(256),      // callGasLimit
      AbiUint(256),      // verificationGasLimit
      AbiUint(256),      // preVerificationGas
      AbiUint(256),      // maxFeePerGas
      AbiUint(256),      // maxPriorityFeePerGas
      AbiBytes(),        // paymasterAndData
      AbiBytes(),        // signature
    ]);

    // Convert UserOperation to tuple values
    final opValue = [
      userOp.sender,
      userOp.nonce,
      HexUtils.decode(userOp.initCode ?? '0x'),
      HexUtils.decode(userOp.callData),
      userOp.callGasLimit,
      userOp.verificationGasLimit,
      userOp.preVerificationGas,
      userOp.maxFeePerGas,
      userOp.maxPriorityFeePerGas,
      HexUtils.decode(userOp.paymasterAndData ?? '0x'),
      HexUtils.decode(userOp.signature),
    ];

    // Encode function call (single tuple parameter, not array)
    final encoded = userOpTupleType.encode(opValue);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes getDepositInfo function call.
  String _encodeGetDepositInfoCall(String account) {
    // getDepositInfo(address) function selector: 0x5287ce12
    final selector = '5287ce12';
    final paddedAccount = account.replaceFirst('0x', '').padLeft(64, '0');
    
    return '0x$selector$paddedAccount';
  }
}

/// EntryPoint v0.7 implementation.
class EntryPointV07 implements EntryPoint {
  static const String defaultAddress = '0x0000000071727De22E5E9d8BAf0edAc6f37da032';

  final String _address;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

  EntryPointV07({
    String? address,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) : _address = address ?? defaultAddress,
       _publicClient = publicClient,
       _walletClient = walletClient;

  @override
  String get address => _address;

  @override
  EntryPointVersion get version => EntryPointVersion.v07;

  @override
  Future<String> handleOps(List<UserOperation> ops, String beneficiary) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleOps');
    }

    // Convert to PackedUserOperations for v0.7
    final packedOps = ops.map((op) => op.toPackedUserOperation()).toList();
    final callData = _encodeHandleOpsCall(packedOps, beneficiary);
    
    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000),
    );

    return await _walletClient!.sendTransaction(txRequest);
  }

  @override
  Future<String> handleAggregatedOps(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleAggregatedOps');
    }

    final callData = _encodeHandleAggregatedOpsCall(opsPerAggregator, beneficiary);
    
    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000),
    );

    return await _walletClient!.sendTransaction(txRequest);
  }

  @override
  Future<BigInt> getNonce(String sender, {BigInt? key}) async {
    final nonceKey = key ?? BigInt.zero;
    final callData = _encodeGetNonceCall(sender, nonceKey);
    
    final result = await _publicClient.call(CallRequest(
      to: _address,
      data: HexUtils.decode(callData),
    ));
    
    return BigInt.parse(HexUtils.encode(result));
  }

  @override
  Future<ValidationResult> simulateValidation(UserOperation userOp) async {
    final packedOp = userOp.toPackedUserOperation();
    final callData = _encodeSimulateValidationCall(packedOp);
    
    try {
      final result = await _publicClient.call(CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ));
      
      return ValidationResult.fromBytes(result);
    } catch (e) {
      if (e.toString().contains('ValidationResult')) {
        return ValidationResult.fromRevertData(e.toString());
      }
      rethrow;
    }
  }

  @override
  Future<DepositInfo> getDepositInfo(String account) async {
    final callData = _encodeGetDepositInfoCall(account);
    
    final result = await _publicClient.call(CallRequest(
      to: _address,
      data: HexUtils.decode(callData),
    ));
    
    return DepositInfo.fromBytes(result);
  }

  /// Encodes handleOps function call for v0.7 (uses PackedUserOperation).
  ///
  /// Function signature: handleOps(PackedUserOperation[],address)
  /// PackedUserOperation struct (v0.7):
  ///   - address sender
  ///   - uint256 nonce
  ///   - bytes initCode
  ///   - bytes callData
  ///   - bytes32 accountGasLimits (verificationGasLimit || callGasLimit)
  ///   - uint256 preVerificationGas
  ///   - bytes32 gasFees (maxPriorityFeePerGas || maxFeePerGas)
  ///   - bytes paymasterAndData
  ///   - bytes signature
  String _encodeHandleOpsCall(List<PackedUserOperation> ops, String beneficiary) {
    // handleOps(PackedUserOperation[],address) function selector: 0x765e827f
    final selector = '765e827f';

    // Define PackedUserOperation tuple type for v0.7
    final packedOpTupleType = AbiTuple([
      AbiAddress(),        // sender
      AbiUint(256),        // nonce
      AbiBytes(),          // initCode
      AbiBytes(),          // callData
      AbiFixedBytes(32),   // accountGasLimits
      AbiUint(256),        // preVerificationGas
      AbiFixedBytes(32),   // gasFees
      AbiBytes(),          // paymasterAndData
      AbiBytes(),          // signature
    ]);

    // Convert PackedUserOperations to tuple values
    final opsValues = ops.map((op) => [
      op.sender,
      op.nonce,
      HexUtils.decode(op.initCode),
      HexUtils.decode(op.callData),
      HexUtils.decode(op.accountGasLimits),
      op.preVerificationGas,
      HexUtils.decode(op.gasFees),
      HexUtils.decode(op.paymasterAndData),
      HexUtils.decode(op.signature),
    ]).toList();

    // Encode function call
    final types = [
      AbiArray(packedOpTupleType),  // PackedUserOperation[]
      AbiAddress(),                 // beneficiary
    ];

    final values = [opsValues, beneficiary];
    final encoded = AbiEncoder.encode(types, values);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes handleAggregatedOps function call for v0.7.
  ///
  /// Function signature: handleAggregatedOps(UserOpsPerAggregator[],address)
  /// UserOpsPerAggregator struct (v0.7 uses PackedUserOperation):
  ///   - PackedUserOperation[] userOps
  ///   - address aggregator
  ///   - bytes signature
  String _encodeHandleAggregatedOpsCall(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) {
    // handleAggregatedOps(UserOpsPerAggregator[],address) function selector: 0x4b1d7cf5
    final selector = '4b1d7cf5';

    // Define PackedUserOperation tuple type for v0.7
    final packedOpTupleType = AbiTuple([
      AbiAddress(),        // sender
      AbiUint(256),        // nonce
      AbiBytes(),          // initCode
      AbiBytes(),          // callData
      AbiFixedBytes(32),   // accountGasLimits
      AbiUint(256),        // preVerificationGas
      AbiFixedBytes(32),   // gasFees
      AbiBytes(),          // paymasterAndData
      AbiBytes(),          // signature
    ]);

    // Define UserOpsPerAggregator tuple type
    final aggregatorTupleType = AbiTuple([
      AbiArray(packedOpTupleType),  // userOps (PackedUserOperation[])
      AbiAddress(),                 // aggregator
      AbiBytes(),                   // signature
    ]);

    // Convert to tuple values
    final aggregatorValues = opsPerAggregator.map((agg) {
      // Convert UserOperations to PackedUserOperations
      final opsValues = agg.userOps.map((op) {
        final packed = op.toPackedUserOperation();
        return [
          packed.sender,
          packed.nonce,
          HexUtils.decode(packed.initCode),
          HexUtils.decode(packed.callData),
          HexUtils.decode(packed.accountGasLimits),
          packed.preVerificationGas,
          HexUtils.decode(packed.gasFees),
          HexUtils.decode(packed.paymasterAndData),
          HexUtils.decode(packed.signature),
        ];
      }).toList();

      return [
        opsValues,
        agg.aggregator,
        HexUtils.decode(agg.signature),
      ];
    }).toList();

    // Encode function call
    final types = [
      AbiArray(aggregatorTupleType),  // UserOpsPerAggregator[]
      AbiAddress(),                   // beneficiary
    ];

    final values = [aggregatorValues, beneficiary];
    final encoded = AbiEncoder.encode(types, values);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes getNonce function call.
  String _encodeGetNonceCall(String sender, BigInt key) {
    // getNonce(address,uint192) function selector: 0x35567e1a
    final selector = '35567e1a';
    final paddedSender = sender.replaceFirst('0x', '').padLeft(64, '0');
    final paddedKey = key.toRadixString(16).padLeft(64, '0');
    
    return '0x$selector$paddedSender$paddedKey';
  }

  /// Encodes simulateValidation function call for v0.7.
  ///
  /// Function signature: simulateValidation(PackedUserOperation)
  String _encodeSimulateValidationCall(PackedUserOperation packedOp) {
    // simulateValidation(PackedUserOperation) function selector: 0xee219423
    final selector = 'ee219423';

    // Define PackedUserOperation tuple type for v0.7
    final packedOpTupleType = AbiTuple([
      AbiAddress(),        // sender
      AbiUint(256),        // nonce
      AbiBytes(),          // initCode
      AbiBytes(),          // callData
      AbiFixedBytes(32),   // accountGasLimits
      AbiUint(256),        // preVerificationGas
      AbiFixedBytes(32),   // gasFees
      AbiBytes(),          // paymasterAndData
      AbiBytes(),          // signature
    ]);

    // Convert PackedUserOperation to tuple values
    final opValue = [
      packedOp.sender,
      packedOp.nonce,
      HexUtils.decode(packedOp.initCode),
      HexUtils.decode(packedOp.callData),
      HexUtils.decode(packedOp.accountGasLimits),
      packedOp.preVerificationGas,
      HexUtils.decode(packedOp.gasFees),
      HexUtils.decode(packedOp.paymasterAndData),
      HexUtils.decode(packedOp.signature),
    ];

    // Encode function call (single tuple parameter, not array)
    final encoded = packedOpTupleType.encode(opValue);

    return '0x$selector${HexUtils.encode(encoded).replaceFirst('0x', '')}';
  }

  /// Encodes getDepositInfo function call.
  String _encodeGetDepositInfoCall(String account) {
    // getDepositInfo(address) function selector: 0x5287ce12
    final selector = '5287ce12';
    final paddedAccount = account.replaceFirst('0x', '').padLeft(64, '0');
    
    return '0x$selector$paddedAccount';
  }
}

/// UserOperation with aggregation info for handleAggregatedOps.
class UserOperationWithAggregation {
  final List<UserOperation> userOps;
  final String aggregator;
  final String signature;

  UserOperationWithAggregation({
    required this.userOps,
    required this.aggregator,
    required this.signature,
  });
}

/// Result from simulateValidation.
class ValidationResult {
  final ReturnInfo returnInfo;
  final StakeInfo senderInfo;
  final StakeInfo? factoryInfo;
  final StakeInfo? paymasterInfo;
  final AggregatorStakeInfo? aggregatorInfo;

  ValidationResult({
    required this.returnInfo,
    required this.senderInfo,
    this.factoryInfo,
    this.paymasterInfo,
    this.aggregatorInfo,
  });

  factory ValidationResult.fromBytes(Uint8List data) {
    // TODO: Decode validation result from bytes
    // This is a complex ABI decoding task
    return ValidationResult(
      returnInfo: ReturnInfo(
        preOpGas: BigInt.zero,
        prefund: BigInt.zero,
        sigFailed: false,
        validAfter: BigInt.zero,
        validUntil: BigInt.zero,
        paymasterContext: '0x',
      ),
      senderInfo: StakeInfo(
        stake: BigInt.zero,
        unstakeDelaySec: BigInt.zero,
      ),
    );
  }

  factory ValidationResult.fromRevertData(String revertData) {
    // TODO: Parse revert data to extract validation result
    return ValidationResult(
      returnInfo: ReturnInfo(
        preOpGas: BigInt.zero,
        prefund: BigInt.zero,
        sigFailed: false,
        validAfter: BigInt.zero,
        validUntil: BigInt.zero,
        paymasterContext: '0x',
      ),
      senderInfo: StakeInfo(
        stake: BigInt.zero,
        unstakeDelaySec: BigInt.zero,
      ),
    );
  }
}

/// Return info from validation.
class ReturnInfo {
  final BigInt preOpGas;
  final BigInt prefund;
  final bool sigFailed;
  final BigInt validAfter;
  final BigInt validUntil;
  final String paymasterContext;

  ReturnInfo({
    required this.preOpGas,
    required this.prefund,
    required this.sigFailed,
    required this.validAfter,
    required this.validUntil,
    required this.paymasterContext,
  });
}

/// Stake info for an entity.
class StakeInfo {
  final BigInt stake;
  final BigInt unstakeDelaySec;

  StakeInfo({
    required this.stake,
    required this.unstakeDelaySec,
  });
}

/// Aggregator stake info.
class AggregatorStakeInfo extends StakeInfo {
  final String aggregator;

  AggregatorStakeInfo({
    required this.aggregator,
    required super.stake,
    required super.unstakeDelaySec,
  });
}

/// Deposit info for an account.
class DepositInfo {
  final BigInt deposit;
  final bool staked;
  final BigInt stake;
  final BigInt unstakeDelaySec;
  final BigInt withdrawTime;

  DepositInfo({
    required this.deposit,
    required this.staked,
    required this.stake,
    required this.unstakeDelaySec,
    required this.withdrawTime,
  });

  factory DepositInfo.fromBytes(Uint8List data) {
    // TODO: Decode deposit info from bytes
    return DepositInfo(
      deposit: BigInt.zero,
      staked: false,
      stake: BigInt.zero,
      unstakeDelaySec: BigInt.zero,
      withdrawTime: BigInt.zero,
    );
  }
}

/// Factory for creating EntryPoint instances.
class EntryPointFactory {
  /// Creates an EntryPoint instance for the specified version.
  static EntryPoint create({
    required EntryPointVersion version,
    String? address,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) {
    switch (version) {
      case EntryPointVersion.v06:
        return EntryPointV06(
          address: address,
          publicClient: publicClient,
          walletClient: walletClient,
        );
      case EntryPointVersion.v07:
        return EntryPointV07(
          address: address,
          publicClient: publicClient,
          walletClient: walletClient,
        );
      case EntryPointVersion.v08:
      case EntryPointVersion.v09:
        // v0.8 and v0.9 use the same interface as v0.7 but with different addresses
        return EntryPointV07(
          address: address ?? _getDefaultAddress(version),
          publicClient: publicClient,
          walletClient: walletClient,
        );
    }
  }

  /// Gets the default address for an EntryPoint version.
  static String _getDefaultAddress(EntryPointVersion version) {
    switch (version) {
      case EntryPointVersion.v06:
        return EntryPointV06.defaultAddress;
      case EntryPointVersion.v07:
        return EntryPointV07.defaultAddress;
      case EntryPointVersion.v08:
        return '0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108'; // EntryPoint v0.8
      case EntryPointVersion.v09:
        return '0x433709009B8330FDa32311DF1C2AFA402eD8D009'; // EntryPoint v0.9
    }
  }

  /// Gets all supported EntryPoint versions.
  static List<EntryPointVersion> get supportedVersions => EntryPointVersion.values;

  /// Gets the latest EntryPoint version.
  static EntryPointVersion get latestVersion => EntryPointVersion.v09;
}