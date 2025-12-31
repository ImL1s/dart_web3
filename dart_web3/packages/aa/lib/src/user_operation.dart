import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

/// Entry Point version enumeration for ERC-4337
enum EntryPointVersion {
  v06('0.6'),
  v07('0.7'),
  v08('0.8'),
  v09('0.9');

  const EntryPointVersion(this.version);
  final String version;
}

/// UserOperation data structure according to ERC-4337 specification
/// 
/// Supports multiple EntryPoint versions (0.6, 0.7, 0.8, 0.9) with
/// version-specific fields and validation.
class UserOperation {
  /// The account making the operation
  final String sender;
  
  /// Anti-replay parameter
  final BigInt nonce;
  
  /// The data to pass to the sender during the main execution call
  final String callData;
  
  /// The amount of gas to allocate the main execution call
  final BigInt callGasLimit;
  
  /// The amount of gas to allocate for the verification step
  final BigInt verificationGasLimit;
  
  /// Extra gas to pay the Bundler
  final BigInt preVerificationGas;
  
  /// Maximum fee per gas
  final BigInt maxFeePerGas;
  
  /// Maximum priority fee per gas
  final BigInt maxPriorityFeePerGas;
  
  /// Data passed into the account to verify authorization
  final String signature;
  
  // EntryPoint v0.6 specific fields
  /// Account init code. Only for new accounts (v0.6 only)
  final String? initCode;
  
  /// Paymaster address with calldata (v0.6 only)
  final String? paymasterAndData;
  
  // EntryPoint v0.7+ specific fields
  /// Account factory. Only for new accounts (v0.7+)
  final String? factory;
  
  /// Data for account factory (v0.7+)
  final String? factoryData;
  
  /// Address of paymaster contract (v0.7+)
  final String? paymaster;
  
  /// Data for paymaster (v0.7+)
  final String? paymasterData;
  
  /// The amount of gas to allocate for the paymaster validation code (v0.7+)
  final BigInt? paymasterVerificationGasLimit;
  
  /// The amount of gas to allocate for the paymaster post-operation code (v0.7+)
  final BigInt? paymasterPostOpGasLimit;
  
  // EntryPoint v0.9 specific fields
  /// Paymaster signature. Can be provided separately for parallelizable signing (v0.9 only)
  final String? paymasterSignature;
  
  /// Authorization data for EIP-7702 (v0.7+)
  final Authorization? authorization;

  UserOperation({
    required this.sender,
    required this.nonce,
    required this.callData,
    required this.callGasLimit,
    required this.verificationGasLimit,
    required this.preVerificationGas,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
    required this.signature,
    this.initCode,
    this.paymasterAndData,
    this.factory,
    this.factoryData,
    this.paymaster,
    this.paymasterData,
    this.paymasterVerificationGasLimit,
    this.paymasterPostOpGasLimit,
    this.paymasterSignature,
    this.authorization,
  });

  /// Create a UserOperation from JSON
  factory UserOperation.fromJson(Map<String, dynamic> json) {
    return UserOperation(
      sender: json['sender'] as String,
      nonce: BigInt.parse(json['nonce'] as String),
      callData: json['callData'] as String,
      callGasLimit: BigInt.parse(json['callGasLimit'] as String),
      verificationGasLimit: BigInt.parse(json['verificationGasLimit'] as String),
      preVerificationGas: BigInt.parse(json['preVerificationGas'] as String),
      maxFeePerGas: BigInt.parse(json['maxFeePerGas'] as String),
      maxPriorityFeePerGas: BigInt.parse(json['maxPriorityFeePerGas'] as String),
      signature: json['signature'] as String,
      initCode: json['initCode'] as String?,
      paymasterAndData: json['paymasterAndData'] as String?,
      factory: json['factory'] as String?,
      factoryData: json['factoryData'] as String?,
      paymaster: json['paymaster'] as String?,
      paymasterData: json['paymasterData'] as String?,
      paymasterVerificationGasLimit: json['paymasterVerificationGasLimit'] != null
          ? BigInt.parse(json['paymasterVerificationGasLimit'] as String)
          : null,
      paymasterPostOpGasLimit: json['paymasterPostOpGasLimit'] != null
          ? BigInt.parse(json['paymasterPostOpGasLimit'] as String)
          : null,
      paymasterSignature: json['paymasterSignature'] as String?,
      authorization: json['authorization'] != null
          ? Authorization.fromJson(json['authorization'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert UserOperation to JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'sender': sender,
      'nonce': '0x${nonce.toRadixString(16)}',
      'callData': callData,
      'callGasLimit': '0x${callGasLimit.toRadixString(16)}',
      'verificationGasLimit': '0x${verificationGasLimit.toRadixString(16)}',
      'preVerificationGas': '0x${preVerificationGas.toRadixString(16)}',
      'maxFeePerGas': '0x${maxFeePerGas.toRadixString(16)}',
      'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas.toRadixString(16)}',
      'signature': signature,
    };

    if (initCode != null) json['initCode'] = initCode;
    if (paymasterAndData != null) json['paymasterAndData'] = paymasterAndData;
    if (factory != null) json['factory'] = factory;
    if (factoryData != null) json['factoryData'] = factoryData;
    if (paymaster != null) json['paymaster'] = paymaster;
    if (paymasterData != null) json['paymasterData'] = paymasterData;
    if (paymasterVerificationGasLimit != null) {
      json['paymasterVerificationGasLimit'] = '0x${paymasterVerificationGasLimit!.toRadixString(16)}';
    }
    if (paymasterPostOpGasLimit != null) {
      json['paymasterPostOpGasLimit'] = '0x${paymasterPostOpGasLimit!.toRadixString(16)}';
    }
    if (paymasterSignature != null) json['paymasterSignature'] = paymasterSignature;
    if (authorization != null) json['authorization'] = authorization!.toJson();

    return json;
  }

  /// Calculate the userOpHash according to ERC-4337 specification
  /// 
  /// The hash calculation varies by EntryPoint version:
  /// - v0.6: Uses ABI encoding with keccak256
  /// - v0.7: Uses packed UserOperation with keccak256
  /// - v0.8/v0.9: Uses EIP-712 typed data hashing
  String getUserOpHash({
    required int chainId,
    required String entryPointAddress,
    required EntryPointVersion entryPointVersion,
  }) {
    switch (entryPointVersion) {
      case EntryPointVersion.v08:
      case EntryPointVersion.v09:
        return _getTypedDataHash(chainId, entryPointAddress);
      
      case EntryPointVersion.v06:
        return _getV06Hash(chainId, entryPointAddress);
      
      case EntryPointVersion.v07:
        return _getV07Hash(chainId, entryPointAddress);
    }
  }

  /// Calculate hash for EntryPoint v0.8/v0.9 using EIP-712 typed data
  String _getTypedDataHash(int chainId, String entryPointAddress) {
    // TODO: Implement EIP-712 typed data hashing
    // This requires the TypedData implementation from the ABI module
    throw UnimplementedError('EIP-712 typed data hashing not yet implemented');
  }

  /// Calculate hash for EntryPoint v0.6 using ABI encoding
  String _getV06Hash(int chainId, String entryPointAddress) {
    // Extract factory and factoryData from initCode for v0.6
    String? factory;
    String? factoryData;
    
    if (initCode != null && initCode!.length > 2) {
      if (initCode!.length >= 42) {
        factory = initCode!.substring(0, 42);
        if (initCode!.length > 42) {
          factoryData = initCode!.substring(42);
        }
      }
    }

    final initCodeToHash = _getInitCode(factory, factoryData, authorization);
    final callDataHash = HexUtils.encode(Keccak256.hash(HexUtils.decode(callData)));
    final paymasterAndDataHash = HexUtils.encode(
      Keccak256.hash(HexUtils.decode(paymasterAndData ?? '0x'))
    );
    final initCodeHash = HexUtils.encode(Keccak256.hash(HexUtils.decode(initCodeToHash)));

    // ABI encode the UserOperation fields
    final packedUserOp = _encodeUserOpV06(
      sender,
      nonce,
      initCodeHash,
      callDataHash,
      callGasLimit,
      verificationGasLimit,
      preVerificationGas,
      maxFeePerGas,
      maxPriorityFeePerGas,
      paymasterAndDataHash,
    );

    // Final hash: keccak256(abi.encode(packedUserOp, entryPointAddress, chainId))
    final finalEncoded = _encodeFinalHash(packedUserOp, entryPointAddress, chainId);
    return HexUtils.encode(Keccak256.hash(HexUtils.decode(finalEncoded)));
  }

  /// Calculate hash for EntryPoint v0.7 using packed UserOperation
  String _getV07Hash(int chainId, String entryPointAddress) {
    final packedUserOp = toPackedUserOperation();
    
    final initCodeHash = HexUtils.encode(Keccak256.hash(HexUtils.decode(packedUserOp.initCode)));
    final callDataHash = HexUtils.encode(Keccak256.hash(HexUtils.decode(packedUserOp.callData)));
    final paymasterAndDataHash = HexUtils.encode(
      Keccak256.hash(HexUtils.decode(packedUserOp.paymasterAndData))
    );

    // ABI encode the packed UserOperation fields
    final encoded = _encodeUserOpV07(
      packedUserOp.sender,
      packedUserOp.nonce,
      initCodeHash,
      callDataHash,
      packedUserOp.accountGasLimits,
      packedUserOp.preVerificationGas,
      packedUserOp.gasFees,
      paymasterAndDataHash,
    );

    // Final hash: keccak256(abi.encode(encoded, entryPointAddress, chainId))
    final finalEncoded = _encodeFinalHash(encoded, entryPointAddress, chainId);
    return HexUtils.encode(Keccak256.hash(HexUtils.decode(finalEncoded)));
  }

  /// Get initCode for hashing (handles authorization for EIP-7702)
  String _getInitCode(String? factory, String? factoryData, Authorization? authorization) {
    if (authorization != null) {
      // For EIP-7702, encode authorization data
      // TODO: Implement proper authorization encoding
      return '0x';
    }
    
    if (factory == null) return '0x';
    return factory + (factoryData ?? '').replaceFirst('0x', '');
  }

  /// Convert to PackedUserOperation for v0.7+ hashing
  PackedUserOperation toPackedUserOperation() {
    // Concatenate verificationGasLimit (16 bytes) and callGasLimit (16 bytes)
    final accountGasLimits = _packGasLimits(verificationGasLimit, callGasLimit);
    
    // Concatenate maxPriorityFeePerGas (16 bytes) and maxFeePerGas (16 bytes)
    final gasFees = _packGasLimits(maxPriorityFeePerGas, maxFeePerGas);
    
    // Concatenate factory and factoryData
    final initCode = factory != null 
        ? factory! + (factoryData ?? '').replaceFirst('0x', '')
        : '0x';
    
    // Concatenate paymaster fields
    String paymasterAndData = '0x';
    if (paymaster != null) {
      paymasterAndData = paymaster!;
      if (paymasterVerificationGasLimit != null && paymasterPostOpGasLimit != null) {
        paymasterAndData += _packGasLimits(paymasterVerificationGasLimit!, paymasterPostOpGasLimit!).replaceFirst('0x', '');
      }
      if (this.paymasterData != null) {
        paymasterAndData += this.paymasterData!.replaceFirst('0x', '');
      }
    }

    return PackedUserOperation(
      sender: sender,
      nonce: nonce,
      initCode: initCode,
      callData: callData,
      accountGasLimits: accountGasLimits,
      preVerificationGas: preVerificationGas,
      gasFees: gasFees,
      paymasterAndData: paymasterAndData,
      signature: signature,
    );
  }

  /// Pack two gas values into a single 32-byte hex string
  String _packGasLimits(BigInt value1, BigInt value2) {
    final bytes1 = _bigIntToBytes16(value1);
    final bytes2 = _bigIntToBytes16(value2);
    return '0x' + HexUtils.encode(Uint8List.fromList([...bytes1, ...bytes2])).replaceFirst('0x', '');
  }

  /// Convert BigInt to 16-byte array
  List<int> _bigIntToBytes16(BigInt value) {
    final bytes = <int>[];
    var temp = value;
    
    // Convert to bytes (little endian)
    while (temp > BigInt.zero) {
      bytes.add((temp & BigInt.from(0xff)).toInt());
      temp = temp >> 8;
    }
    
    // Pad to 16 bytes and reverse to big endian
    while (bytes.length < 16) {
      bytes.add(0);
    }
    
    return bytes.reversed.toList();
  }

  /// ABI encode UserOperation for v0.6
  String _encodeUserOpV06(
    String sender,
    BigInt nonce,
    String initCodeHash,
    String callDataHash,
    BigInt callGasLimit,
    BigInt verificationGasLimit,
    BigInt preVerificationGas,
    BigInt maxFeePerGas,
    BigInt maxPriorityFeePerGas,
    String paymasterAndDataHash,
  ) {
    // TODO: Use proper ABI encoding from dart_web3_abi
    // For now, return a placeholder
    throw UnimplementedError('ABI encoding not yet implemented');
  }

  /// ABI encode UserOperation for v0.7
  String _encodeUserOpV07(
    String sender,
    BigInt nonce,
    String initCodeHash,
    String callDataHash,
    String accountGasLimits,
    BigInt preVerificationGas,
    String gasFees,
    String paymasterAndDataHash,
  ) {
    // TODO: Use proper ABI encoding from dart_web3_abi
    // For now, return a placeholder
    throw UnimplementedError('ABI encoding not yet implemented');
  }

  /// Encode final hash with entryPoint and chainId
  String _encodeFinalHash(String packedUserOp, String entryPointAddress, int chainId) {
    // TODO: Use proper ABI encoding from dart_web3_abi
    // For now, return a placeholder
    throw UnimplementedError('ABI encoding not yet implemented');
  }

  /// Create a copy of this UserOperation with updated fields
  UserOperation copyWith({
    String? sender,
    BigInt? nonce,
    String? callData,
    BigInt? callGasLimit,
    BigInt? verificationGasLimit,
    BigInt? preVerificationGas,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
    String? signature,
    String? initCode,
    String? paymasterAndData,
    String? factory,
    String? factoryData,
    String? paymaster,
    String? paymasterData,
    BigInt? paymasterVerificationGasLimit,
    BigInt? paymasterPostOpGasLimit,
    String? paymasterSignature,
    Authorization? authorization,
  }) {
    return UserOperation(
      sender: sender ?? this.sender,
      nonce: nonce ?? this.nonce,
      callData: callData ?? this.callData,
      callGasLimit: callGasLimit ?? this.callGasLimit,
      verificationGasLimit: verificationGasLimit ?? this.verificationGasLimit,
      preVerificationGas: preVerificationGas ?? this.preVerificationGas,
      maxFeePerGas: maxFeePerGas ?? this.maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas ?? this.maxPriorityFeePerGas,
      signature: signature ?? this.signature,
      initCode: initCode ?? this.initCode,
      paymasterAndData: paymasterAndData ?? this.paymasterAndData,
      factory: factory ?? this.factory,
      factoryData: factoryData ?? this.factoryData,
      paymaster: paymaster ?? this.paymaster,
      paymasterData: paymasterData ?? this.paymasterData,
      paymasterVerificationGasLimit: paymasterVerificationGasLimit ?? this.paymasterVerificationGasLimit,
      paymasterPostOpGasLimit: paymasterPostOpGasLimit ?? this.paymasterPostOpGasLimit,
      paymasterSignature: paymasterSignature ?? this.paymasterSignature,
      authorization: authorization ?? this.authorization,
    );
  }

  @override
  String toString() {
    return 'UserOperation(sender: $sender, nonce: $nonce, callData: $callData)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserOperation &&
        other.sender == sender &&
        other.nonce == nonce &&
        other.callData == callData &&
        other.callGasLimit == callGasLimit &&
        other.verificationGasLimit == verificationGasLimit &&
        other.preVerificationGas == preVerificationGas &&
        other.maxFeePerGas == maxFeePerGas &&
        other.maxPriorityFeePerGas == maxPriorityFeePerGas &&
        other.signature == signature;
  }

  @override
  int get hashCode {
    return Object.hash(
      sender,
      nonce,
      callData,
      callGasLimit,
      verificationGasLimit,
      preVerificationGas,
      maxFeePerGas,
      maxPriorityFeePerGas,
      signature,
    );
  }
}

/// Packed UserOperation for EntryPoint v0.7+
class PackedUserOperation {
  final String sender;
  final BigInt nonce;
  final String initCode;
  final String callData;
  final String accountGasLimits;
  final BigInt preVerificationGas;
  final String gasFees;
  final String paymasterAndData;
  final String signature;

  PackedUserOperation({
    required this.sender,
    required this.nonce,
    required this.initCode,
    required this.callData,
    required this.accountGasLimits,
    required this.preVerificationGas,
    required this.gasFees,
    required this.paymasterAndData,
    required this.signature,
  });
}

/// UserOperation request for building operations
class UserOperationRequest {
  final String? sender;
  final BigInt? nonce;
  final String? callData;
  final BigInt? callGasLimit;
  final BigInt? verificationGasLimit;
  final BigInt? preVerificationGas;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;
  final String? signature;
  final String? initCode;
  final String? paymasterAndData;
  final String? factory;
  final String? factoryData;
  final String? paymaster;
  final String? paymasterData;
  final BigInt? paymasterVerificationGasLimit;
  final BigInt? paymasterPostOpGasLimit;
  final String? paymasterSignature;
  final Authorization? authorization;

  UserOperationRequest({
    this.sender,
    this.nonce,
    this.callData,
    this.callGasLimit,
    this.verificationGasLimit,
    this.preVerificationGas,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.signature,
    this.initCode,
    this.paymasterAndData,
    this.factory,
    this.factoryData,
    this.paymaster,
    this.paymasterData,
    this.paymasterVerificationGasLimit,
    this.paymasterPostOpGasLimit,
    this.paymasterSignature,
    this.authorization,
  });
}

/// Gas estimation result for UserOperation
class UserOperationGasEstimate {
  final BigInt preVerificationGas;
  final BigInt verificationGasLimit;
  final BigInt callGasLimit;
  final BigInt? paymasterVerificationGasLimit;
  final BigInt? paymasterPostOpGasLimit;

  UserOperationGasEstimate({
    required this.preVerificationGas,
    required this.verificationGasLimit,
    required this.callGasLimit,
    this.paymasterVerificationGasLimit,
    this.paymasterPostOpGasLimit,
  });

  factory UserOperationGasEstimate.fromJson(Map<String, dynamic> json) {
    return UserOperationGasEstimate(
      preVerificationGas: BigInt.parse(json['preVerificationGas'] as String),
      verificationGasLimit: BigInt.parse(json['verificationGasLimit'] as String),
      callGasLimit: BigInt.parse(json['callGasLimit'] as String),
      paymasterVerificationGasLimit: json['paymasterVerificationGasLimit'] != null
          ? BigInt.parse(json['paymasterVerificationGasLimit'] as String)
          : null,
      paymasterPostOpGasLimit: json['paymasterPostOpGasLimit'] != null
          ? BigInt.parse(json['paymasterPostOpGasLimit'] as String)
          : null,
    );
  }
}

/// UserOperation receipt from bundler
class UserOperationReceipt {
  final String userOpHash;
  final String sender;
  final BigInt nonce;
  final String? paymaster;
  final BigInt actualGasCost;
  final BigInt actualGasUsed;
  final bool success;
  final String? reason;
  final String entryPoint;
  final Map<String, dynamic> receipt;

  UserOperationReceipt({
    required this.userOpHash,
    required this.sender,
    required this.nonce,
    this.paymaster,
    required this.actualGasCost,
    required this.actualGasUsed,
    required this.success,
    this.reason,
    required this.entryPoint,
    required this.receipt,
  });

  factory UserOperationReceipt.fromJson(Map<String, dynamic> json) {
    return UserOperationReceipt(
      userOpHash: json['userOpHash'] as String,
      sender: json['sender'] as String,
      nonce: BigInt.parse(json['nonce'] as String),
      paymaster: json['paymaster'] as String?,
      actualGasCost: BigInt.parse(json['actualGasCost'] as String),
      actualGasUsed: BigInt.parse(json['actualGasUsed'] as String),
      success: json['success'] as bool,
      reason: json['reason'] as String?,
      entryPoint: json['entryPoint'] as String,
      receipt: Map<String, dynamic>.from(json['receipt'] as Map),
    );
  }
}