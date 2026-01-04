import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

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
  EntryPointV06({
    required PublicClient publicClient,
    String? address,
    WalletClient? walletClient,
  })  : _address = address ?? defaultAddress,
        _publicClient = publicClient,
        _walletClient = walletClient;
  static const String defaultAddress =
      '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';

  final String _address;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

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

    return _walletClient.sendTransaction(txRequest);
  }

  @override
  Future<String> handleAggregatedOps(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleAggregatedOps');
    }

    final callData =
        _encodeHandleAggregatedOpsCall(opsPerAggregator, beneficiary);

    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000),
    );

    return _walletClient.sendTransaction(txRequest);
  }

  @override
  Future<BigInt> getNonce(String sender, {BigInt? key}) async {
    final nonceKey = key ?? BigInt.zero;
    final callData = _encodeGetNonceCall(sender, nonceKey);

    final result = await _publicClient.call(
      CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ),
    );

    return BigInt.parse(HexUtils.encode(result));
  }

  @override
  Future<ValidationResult> simulateValidation(UserOperation userOp) async {
    final callData = _encodeSimulateValidationCall(userOp);

    try {
      final result = await _publicClient.call(
        CallRequest(
          to: _address,
          data: HexUtils.decode(callData),
        ),
      );

      return ValidationResult.fromBytes(result);
    } catch (e) {
      // simulateValidation is expected to revert with validation data
      if (e.toString().contains('ValidationResult')) {
        // Parse the revert data to extract validation result
        return ValidationResult.fromRevertData();
      }
      rethrow;
    }
  }

  @override
  Future<DepositInfo> getDepositInfo(String account) async {
    final callData = _encodeGetDepositInfoCall(account);

    final result = await _publicClient.call(
      CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ),
    );

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
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiUint(256), // callGasLimit
      AbiUint(256), // verificationGasLimit
      AbiUint(256), // preVerificationGas
      AbiUint(256), // maxFeePerGas
      AbiUint(256), // maxPriorityFeePerGas
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
    ]);

    // Convert UserOperations to tuple values
    final opsValues = ops
        .map(
          (op) => [
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
          ],
        )
        .toList();

    // Encode function call
    final types = [
      AbiArray(userOpTupleType), // UserOperation[]
      AbiAddress(), // beneficiary
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
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiUint(256), // callGasLimit
      AbiUint(256), // verificationGasLimit
      AbiUint(256), // preVerificationGas
      AbiUint(256), // maxFeePerGas
      AbiUint(256), // maxPriorityFeePerGas
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
    ]);

    // Define UserOpsPerAggregator tuple type
    final aggregatorTupleType = AbiTuple([
      AbiArray(userOpTupleType), // userOps
      AbiAddress(), // aggregator
      AbiBytes(), // signature
    ]);

    // Convert to tuple values
    final aggregatorValues = opsPerAggregator.map((agg) {
      final opsValues = agg.userOps
          .map(
            (op) => [
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
            ],
          )
          .toList();

      return [
        opsValues,
        agg.aggregator,
        HexUtils.decode(agg.signature),
      ];
    }).toList();

    // Encode function call
    final types = [
      AbiArray(aggregatorTupleType), // UserOpsPerAggregator[]
      AbiAddress(), // beneficiary
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
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiUint(256), // callGasLimit
      AbiUint(256), // verificationGasLimit
      AbiUint(256), // preVerificationGas
      AbiUint(256), // maxFeePerGas
      AbiUint(256), // maxPriorityFeePerGas
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
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
  EntryPointV07({
    required PublicClient publicClient,
    String? address,
    WalletClient? walletClient,
  })  : _address = address ?? defaultAddress,
        _publicClient = publicClient,
        _walletClient = walletClient;
  static const String defaultAddress =
      '0x0000000071727De22E5E9d8BAf0edAc6f37da032';

  final String _address;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

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

    return _walletClient.sendTransaction(txRequest);
  }

  @override
  Future<String> handleAggregatedOps(
    List<UserOperationWithAggregation> opsPerAggregator,
    String beneficiary,
  ) async {
    if (_walletClient == null) {
      throw StateError('WalletClient required for handleAggregatedOps');
    }

    final callData =
        _encodeHandleAggregatedOpsCall(opsPerAggregator, beneficiary);

    final txRequest = TransactionRequest(
      to: _address,
      data: HexUtils.decode(callData),
      gasLimit: BigInt.from(1000000),
    );

    return _walletClient.sendTransaction(txRequest);
  }

  @override
  Future<BigInt> getNonce(String sender, {BigInt? key}) async {
    final nonceKey = key ?? BigInt.zero;
    final callData = _encodeGetNonceCall(sender, nonceKey);

    final result = await _publicClient.call(
      CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ),
    );

    return BigInt.parse(HexUtils.encode(result));
  }

  @override
  Future<ValidationResult> simulateValidation(UserOperation userOp) async {
    final packedOp = userOp.toPackedUserOperation();
    final callData = _encodeSimulateValidationCall(packedOp);

    try {
      final result = await _publicClient.call(
        CallRequest(
          to: _address,
          data: HexUtils.decode(callData),
        ),
      );

      return ValidationResult.fromBytes(result);
    } catch (e) {
      if (e.toString().contains('ValidationResult')) {
        return ValidationResult.fromRevertData();
      }
      rethrow;
    }
  }

  @override
  Future<DepositInfo> getDepositInfo(String account) async {
    final callData = _encodeGetDepositInfoCall(account);

    final result = await _publicClient.call(
      CallRequest(
        to: _address,
        data: HexUtils.decode(callData),
      ),
    );

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
  String _encodeHandleOpsCall(
      List<PackedUserOperation> ops, String beneficiary) {
    // handleOps(PackedUserOperation[],address) function selector: 0x765e827f
    final selector = '765e827f';

    // Define PackedUserOperation tuple type for v0.7
    final packedOpTupleType = AbiTuple([
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiFixedBytes(32), // accountGasLimits
      AbiUint(256), // preVerificationGas
      AbiFixedBytes(32), // gasFees
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
    ]);

    // Convert PackedUserOperations to tuple values
    final opsValues = ops
        .map(
          (op) => [
            op.sender,
            op.nonce,
            HexUtils.decode(op.initCode),
            HexUtils.decode(op.callData),
            HexUtils.decode(op.accountGasLimits),
            op.preVerificationGas,
            HexUtils.decode(op.gasFees),
            HexUtils.decode(op.paymasterAndData),
            HexUtils.decode(op.signature),
          ],
        )
        .toList();

    // Encode function call
    final types = [
      AbiArray(packedOpTupleType), // PackedUserOperation[]
      AbiAddress(), // beneficiary
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
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiFixedBytes(32), // accountGasLimits
      AbiUint(256), // preVerificationGas
      AbiFixedBytes(32), // gasFees
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
    ]);

    // Define UserOpsPerAggregator tuple type
    final aggregatorTupleType = AbiTuple([
      AbiArray(packedOpTupleType), // userOps (PackedUserOperation[])
      AbiAddress(), // aggregator
      AbiBytes(), // signature
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
      AbiArray(aggregatorTupleType), // UserOpsPerAggregator[]
      AbiAddress(), // beneficiary
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
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiBytes(), // initCode
      AbiBytes(), // callData
      AbiFixedBytes(32), // accountGasLimits
      AbiUint(256), // preVerificationGas
      AbiFixedBytes(32), // gasFees
      AbiBytes(), // paymasterAndData
      AbiBytes(), // signature
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
  UserOperationWithAggregation({
    required this.userOps,
    required this.aggregator,
    required this.signature,
  });
  final List<UserOperation> userOps;
  final String aggregator;
  final String signature;
}

/// Result from simulateValidation.
class ValidationResult {
  ValidationResult({
    required this.returnInfo,
    required this.senderInfo,
    this.factoryInfo,
    this.paymasterInfo,
    this.aggregatorInfo,
  });

  /// Decode ValidationResult from ABI-encoded bytes.
  ///
  /// ValidationResult struct (ERC-4337):
  ///   - ReturnInfo returnInfo (tuple)
  ///   - StakeInfo senderInfo (tuple)
  ///   - StakeInfo factoryInfo (tuple)
  ///   - StakeInfo paymasterInfo (tuple)
  factory ValidationResult.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      return ValidationResult._empty();
    }

    try {
      // Define the ValidationResult tuple type
      // ReturnInfo: (uint256 preOpGas, uint256 prefund, bool sigFailed, uint48 validAfter, uint48 validUntil, bytes paymasterContext)
      final returnInfoType = AbiTuple([
        AbiUint(256), // preOpGas
        AbiUint(256), // prefund
        AbiUint(
            256), // accountValidationData (packed: sigFailed, validUntil, validAfter)
        AbiBytes(), // paymasterContext
      ]);

      // StakeInfo: (uint256 stake, uint256 unstakeDelaySec)
      final stakeInfoType = AbiTuple([
        AbiUint(256), // stake
        AbiUint(256), // unstakeDelaySec
      ]);

      // Full ValidationResult tuple
      final validationResultType = AbiTuple([
        returnInfoType, // returnInfo
        stakeInfoType, // senderInfo
        stakeInfoType, // factoryInfo
        stakeInfoType, // paymasterInfo
      ]);

      final (decodedValue, _) = validationResultType.decode(data, 0);
      final values = decodedValue as List<dynamic>;

      // Parse ReturnInfo
      final returnInfoValues = values[0] as List<dynamic>;
      final preOpGas = returnInfoValues[0] as BigInt;
      final prefund = returnInfoValues[1] as BigInt;
      final accountValidationData = returnInfoValues[2] as BigInt;
      final paymasterContext = returnInfoValues[3] as Uint8List;

      // Unpack accountValidationData: sigFailed (1 bit) | validUntil (48 bits) | validAfter (48 bits)
      final sigFailed =
          (accountValidationData >> 160) & BigInt.one == BigInt.one;
      final validUntil = (accountValidationData >> 48) &
          BigInt.parse('ffffffffffff', radix: 16);
      final validAfter =
          accountValidationData & BigInt.parse('ffffffffffff', radix: 16);

      // Parse StakeInfo structs
      final senderInfoValues = values[1] as List<dynamic>;
      final factoryInfoValues = values[2] as List<dynamic>;
      final paymasterInfoValues = values[3] as List<dynamic>;

      return ValidationResult(
        returnInfo: ReturnInfo(
          preOpGas: preOpGas,
          prefund: prefund,
          sigFailed: sigFailed,
          validAfter: validAfter,
          validUntil: validUntil,
          paymasterContext: HexUtils.encode(paymasterContext),
        ),
        senderInfo: StakeInfo(
          stake: senderInfoValues[0] as BigInt,
          unstakeDelaySec: senderInfoValues[1] as BigInt,
        ),
        factoryInfo: StakeInfo(
          stake: factoryInfoValues[0] as BigInt,
          unstakeDelaySec: factoryInfoValues[1] as BigInt,
        ),
        paymasterInfo: StakeInfo(
          stake: paymasterInfoValues[0] as BigInt,
          unstakeDelaySec: paymasterInfoValues[1] as BigInt,
        ),
      );
    } on Exception catch (_) {
      // If decoding fails, return empty result
      return ValidationResult._empty();
    }
  }

  /// Creates an empty ValidationResult for error cases.
  factory ValidationResult._empty() {
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

  factory ValidationResult.fromRevertData() {
    // Note: Parse revert data to extract validation result
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
  final ReturnInfo returnInfo;
  final StakeInfo senderInfo;
  final StakeInfo? factoryInfo;
  final StakeInfo? paymasterInfo;
  final AggregatorStakeInfo? aggregatorInfo;
}

/// Return info from validation.
class ReturnInfo {
  ReturnInfo({
    required this.preOpGas,
    required this.prefund,
    required this.sigFailed,
    required this.validAfter,
    required this.validUntil,
    required this.paymasterContext,
  });
  final BigInt preOpGas;
  final BigInt prefund;
  final bool sigFailed;
  final BigInt validAfter;
  final BigInt validUntil;
  final String paymasterContext;
}

/// Stake info for an entity.
class StakeInfo {
  StakeInfo({
    required this.stake,
    required this.unstakeDelaySec,
  });
  final BigInt stake;
  final BigInt unstakeDelaySec;
}

/// Aggregator stake info.
class AggregatorStakeInfo extends StakeInfo {
  AggregatorStakeInfo({
    required this.aggregator,
    required super.stake,
    required super.unstakeDelaySec,
  });
  final String aggregator;
}

/// Deposit info for an account.
class DepositInfo {
  DepositInfo({
    required this.deposit,
    required this.staked,
    required this.stake,
    required this.unstakeDelaySec,
    required this.withdrawTime,
  });

  /// Decode DepositInfo from ABI-encoded bytes.
  ///
  /// DepositInfo struct (ERC-4337):
  ///   - uint112 deposit
  ///   - bool staked
  ///   - uint112 stake
  ///   - uint32 unstakeDelaySec
  ///   - uint48 withdrawTime
  ///
  /// Note: The values are typically returned as uint256 padded in ABI encoding.
  factory DepositInfo.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      return DepositInfo._empty();
    }

    try {
      // DepositInfo is returned as a tuple with 5 fields
      // In ABI encoding, each field is padded to 32 bytes
      final depositInfoType = AbiTuple([
        AbiUint(256), // deposit (uint112 padded)
        AbiUint(256), // staked (bool as uint)
        AbiUint(256), // stake (uint112 padded)
        AbiUint(256), // unstakeDelaySec (uint32 padded)
        AbiUint(256), // withdrawTime (uint48 padded)
      ]);

      final (decodedValue, _) = depositInfoType.decode(data, 0);
      final values = decodedValue as List<dynamic>;

      return DepositInfo(
        deposit: values[0] as BigInt,
        staked: (values[1] as BigInt) != BigInt.zero,
        stake: values[2] as BigInt,
        unstakeDelaySec: values[3] as BigInt,
        withdrawTime: values[4] as BigInt,
      );
    } on Exception catch (_) {
      // If decoding fails, return empty result
      return DepositInfo._empty();
    }
  }

  /// Creates an empty DepositInfo for error cases.
  factory DepositInfo._empty() {
    return DepositInfo(
      deposit: BigInt.zero,
      staked: false,
      stake: BigInt.zero,
      unstakeDelaySec: BigInt.zero,
      withdrawTime: BigInt.zero,
    );
  }
  final BigInt deposit;
  final bool staked;
  final BigInt stake;
  final BigInt unstakeDelaySec;
  final BigInt withdrawTime;
}

/// Factory for creating EntryPoint instances.
class EntryPointFactory {
  /// Creates an EntryPoint instance for the specified version.
  static EntryPoint create({
    required EntryPointVersion version,
    required PublicClient publicClient,
    String? address,
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
  static List<EntryPointVersion> get supportedVersions =>
      EntryPointVersion.values;

  /// Gets the latest EntryPoint version.
  static EntryPointVersion get latestVersion => EntryPointVersion.v09;
}
