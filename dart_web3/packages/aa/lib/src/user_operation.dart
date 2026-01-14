import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

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
@immutable
class UserOperation {
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
    var factory = json['factory'] as String?;
    var factoryData = json['factoryData'] as String?;
    final initCode = json['initCode'] as String?;

    // Parse factory and factoryData from initCode if not provided
    if (factory == null && initCode != null && initCode.length >= 42) {
      factory = initCode.substring(0, 42);
      if (initCode.length > 42) {
        factoryData = '0x${initCode.substring(42)}';
      }
    }

    return UserOperation(
      sender: json['sender'] as String,
      nonce: BigInt.parse(json['nonce'] as String),
      callData: json['callData'] as String,
      callGasLimit: BigInt.parse(json['callGasLimit'] as String),
      verificationGasLimit:
          BigInt.parse(json['verificationGasLimit'] as String),
      preVerificationGas: BigInt.parse(json['preVerificationGas'] as String),
      maxFeePerGas: BigInt.parse(json['maxFeePerGas'] as String),
      maxPriorityFeePerGas:
          BigInt.parse(json['maxPriorityFeePerGas'] as String),
      signature: json['signature'] as String,
      initCode: initCode,
      paymasterAndData: json['paymasterAndData'] as String?,
      factory: factory,
      factoryData: factoryData,
      paymaster: json['paymaster'] as String?,
      paymasterData: json['paymasterData'] as String?,
      paymasterVerificationGasLimit:
          json['paymasterVerificationGasLimit'] != null
              ? BigInt.parse(json['paymasterVerificationGasLimit'] as String)
              : null,
      paymasterPostOpGasLimit: json['paymasterPostOpGasLimit'] != null
          ? BigInt.parse(json['paymasterPostOpGasLimit'] as String)
          : null,
      paymasterSignature: json['paymasterSignature'] as String?,
      authorization: json['authorization'] != null
          ? Authorization.fromJson(
              json['authorization'] as Map<String, dynamic>)
          : null,
    );
  }

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

  /// Convert UserOperation to JSON
  ///
  /// [version] specifies the EntryPoint version to target.
  /// If not provided, it defaults to v0.7 formatting including packed fields where required.
  Map<String, dynamic> toJson(
      [EntryPointVersion version = EntryPointVersion.v07]) {
    final json = <String, dynamic>{
      'sender': sender,
      'nonce': '0x${nonce.toRadixString(16)}',
      'callData': callData,
      'signature': signature,
    };

    if (version == EntryPointVersion.v06) {
      json['callGasLimit'] = '0x${callGasLimit.toRadixString(16)}';
      json['verificationGasLimit'] =
          '0x${verificationGasLimit.toRadixString(16)}';
      json['preVerificationGas'] = '0x${preVerificationGas.toRadixString(16)}';
      json['maxFeePerGas'] = '0x${maxFeePerGas.toRadixString(16)}';
      json['maxPriorityFeePerGas'] =
          '0x${maxPriorityFeePerGas.toRadixString(16)}';

      if (initCode != null) json['initCode'] = initCode;
      if (paymasterAndData != null) json['paymasterAndData'] = paymasterAndData;
    } else {
      // v0.7+ uses packed fields
      json['accountGasLimits'] =
          _packGasLimits(verificationGasLimit, callGasLimit);
      json['preVerificationGas'] = '0x${preVerificationGas.toRadixString(16)}';
      json['gasFees'] = _packGasLimits(maxPriorityFeePerGas, maxFeePerGas);

      // Combined initCode (factory + factoryData)
      final packedInitCode = factory != null
          ? factory! + (factoryData ?? '').replaceFirst('0x', '')
          : '0x';
      json['initCode'] = packedInitCode;

      // Combined paymasterAndData
      var packedPmData = '0x';
      if (paymaster != null) {
        packedPmData = paymaster!;
        if (paymasterVerificationGasLimit != null &&
            paymasterPostOpGasLimit != null) {
          packedPmData += _packGasLimits(
                  paymasterVerificationGasLimit!, paymasterPostOpGasLimit!)
              .replaceFirst('0x', '');
        }
        if (paymasterData != null) {
          packedPmData += paymasterData!.replaceFirst('0x', '');
        }
      }
      json['paymasterAndData'] = packedPmData;
    }

    if (paymasterSignature != null) {
      json['paymasterSignature'] = paymasterSignature;
    }
    if (authorization != null) {
      json['authorization'] = authorization!.toJson();
    }

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

  /// Calculate hash for EntryPoint v0.8/v0.9 using EIP-712 typed data.
  ///
  /// Per EIP-712 and ERC-4337 specification:
  /// 1. Calculate domain separator with EntryPoint name, version, chainId, address
  /// 2. Calculate struct hash of PackedUserOperation (excluding signature)
  /// 3. Final hash = keccak256("\x19\x01" ++ domainSeparator ++ structHash)
  String _getTypedDataHash(int chainId, String entryPointAddress) {
    final packedOp = toPackedUserOperation();

    // EIP-712 Domain Separator
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    final domainTypeHash = Keccak256.hash(
      Uint8List.fromList(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
              .codeUnits),
    );

    // Domain name and version for EntryPoint
    final nameHash = Keccak256.hash(
      Uint8List.fromList('Account Abstraction EntryPoint'.codeUnits),
    );
    final versionHash = Keccak256.hash(
      Uint8List.fromList('0.8'.codeUnits),
    );

    // Encode domain separator: keccak256(abi.encode(typeHash, nameHash, versionHash, chainId, address))
    final domainEncoded = AbiEncoder.encode([
      AbiFixedBytes(32), // typeHash
      AbiFixedBytes(32), // nameHash
      AbiFixedBytes(32), // versionHash
      AbiUint(256), // chainId
      AbiAddress(), // verifyingContract
    ], [
      domainTypeHash,
      nameHash,
      versionHash,
      BigInt.from(chainId),
      entryPointAddress,
    ]);
    final domainSeparator = Keccak256.hash(domainEncoded);

    // PackedUserOperation type hash (signature excluded)
    // keccak256("PackedUserOperation(address sender,uint256 nonce,bytes initCode,bytes callData,bytes32 accountGasLimits,uint256 preVerificationGas,bytes32 gasFees,bytes paymasterAndData)")
    final userOpTypeHash = Keccak256.hash(
      Uint8List.fromList(
          'PackedUserOperation(address sender,uint256 nonce,bytes initCode,bytes callData,bytes32 accountGasLimits,uint256 preVerificationGas,bytes32 gasFees,bytes paymasterAndData)'
              .codeUnits),
    );

    // Hash dynamic fields (bytes -> keccak256)
    final initCodeHash = Keccak256.hash(HexUtils.decode(packedOp.initCode));
    final callDataHash = Keccak256.hash(HexUtils.decode(packedOp.callData));
    final paymasterAndDataHash =
        Keccak256.hash(HexUtils.decode(packedOp.paymasterAndData));

    // Encode struct hash: keccak256(abi.encode(typeHash, fields...))
    final structEncoded = AbiEncoder.encode([
      AbiFixedBytes(32), // typeHash
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiFixedBytes(32), // initCodeHash
      AbiFixedBytes(32), // callDataHash
      AbiFixedBytes(32), // accountGasLimits
      AbiUint(256), // preVerificationGas
      AbiFixedBytes(32), // gasFees
      AbiFixedBytes(32), // paymasterAndDataHash
    ], [
      userOpTypeHash,
      packedOp.sender,
      packedOp.nonce,
      initCodeHash,
      callDataHash,
      HexUtils.decode(packedOp.accountGasLimits),
      packedOp.preVerificationGas,
      HexUtils.decode(packedOp.gasFees),
      paymasterAndDataHash,
    ]);
    final structHash = Keccak256.hash(structEncoded);

    // EIP-712 final hash: keccak256("\x19\x01" ++ domainSeparator ++ structHash)
    final prefix = Uint8List.fromList([0x19, 0x01]);
    final finalData = Uint8List.fromList([
      ...prefix,
      ...domainSeparator,
      ...structHash,
    ]);

    return HexUtils.encode(Keccak256.hash(finalData));
  }

  /// Calculate hash for EntryPoint v0.6 using ABI encoding.
  ///
  /// Per ERC-4337 specification:
  /// 1. Hash initCode, callData, paymasterAndData with keccak256
  /// 2. ABI encode the UserOperation fields with hashes
  /// 3. Hash the packed UserOperation
  /// 4. ABI encode with entryPointAddress and chainId
  /// 5. Final keccak256 hash
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

    // 1. Hash variable-length fields
    final initCodeToHash = _getInitCode(factory, factoryData, authorization);
    final initCodeHash = Keccak256.hash(HexUtils.decode(initCodeToHash));
    final callDataHash = Keccak256.hash(HexUtils.decode(callData));
    final paymasterAndDataHash =
        Keccak256.hash(HexUtils.decode(paymasterAndData ?? '0x'));

    // 2. ABI encode the UserOperation fields
    final packedUserOp = _encodeUserOpV06(
      sender,
      nonce,
      HexUtils.encode(initCodeHash),
      HexUtils.encode(callDataHash),
      callGasLimit,
      verificationGasLimit,
      preVerificationGas,
      maxFeePerGas,
      maxPriorityFeePerGas,
      HexUtils.encode(paymasterAndDataHash),
    );

    // 3. Hash the packed UserOperation
    final userOpHash = Keccak256.hash(packedUserOp);

    // 4. ABI encode with entryPointAddress and chainId
    final finalEncoded =
        _encodeFinalHash(userOpHash, entryPointAddress, chainId);

    // 5. Final hash
    return HexUtils.encode(Keccak256.hash(finalEncoded));
  }

  /// Calculate hash for EntryPoint v0.7 using packed UserOperation.
  ///
  /// Per ERC-4337 specification:
  /// 1. Convert to PackedUserOperation format
  /// 2. Hash initCode, callData, paymasterAndData with keccak256
  /// 3. ABI encode the packed UserOperation fields with hashes
  /// 4. Hash the packed UserOperation
  /// 5. ABI encode with entryPointAddress and chainId
  /// 6. Final keccak256 hash
  String _getV07Hash(int chainId, String entryPointAddress) {
    final packedUserOp = toPackedUserOperation();

    // 1. Hash variable-length fields
    final initCodeHash = Keccak256.hash(HexUtils.decode(packedUserOp.initCode));
    final callDataHash = Keccak256.hash(HexUtils.decode(packedUserOp.callData));
    final paymasterAndDataHash =
        Keccak256.hash(HexUtils.decode(packedUserOp.paymasterAndData));

    // 2. ABI encode the packed UserOperation fields
    final encoded = _encodeUserOpV07(
      packedUserOp.sender,
      packedUserOp.nonce,
      HexUtils.encode(initCodeHash),
      HexUtils.encode(callDataHash),
      packedUserOp.accountGasLimits,
      packedUserOp.preVerificationGas,
      packedUserOp.gasFees,
      HexUtils.encode(paymasterAndDataHash),
    );

    // 3. Hash the packed UserOperation
    final userOpHash = Keccak256.hash(encoded);

    // 4. ABI encode with entryPointAddress and chainId
    final finalEncoded =
        _encodeFinalHash(userOpHash, entryPointAddress, chainId);

    // 5. Final hash
    return HexUtils.encode(Keccak256.hash(finalEncoded));
  }

  /// Get initCode for hashing (handles authorization for EIP-7702)
  String _getInitCode(
      String? factory, String? factoryData, Authorization? authorization) {
    if (authorization != null) {
      // For EIP-7702, encode authorization data
      // Note: Implement proper authorization encoding
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
    var paymasterAndData = '0x';
    if (paymaster != null) {
      paymasterAndData = paymaster!;
      if (paymasterVerificationGasLimit != null &&
          paymasterPostOpGasLimit != null) {
        paymasterAndData += _packGasLimits(
                paymasterVerificationGasLimit!, paymasterPostOpGasLimit!)
            .replaceFirst('0x', '');
      }
      if (paymasterData != null) {
        paymasterAndData += paymasterData!.replaceFirst('0x', '');
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
    return '0x${HexUtils.encode(Uint8List.fromList([...bytes1, ...bytes2])).replaceFirst('0x', '')}';
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

  /// ABI encode UserOperation for v0.6 according to ERC-4337 specification.
  ///
  /// Encodes: (address sender, uint256 nonce, bytes32 initCodeHash, bytes32 callDataHash,
  ///           uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas,
  ///           uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes32 paymasterAndDataHash)
  Uint8List _encodeUserOpV06(
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
    final types = [
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiFixedBytes(32), // initCodeHash
      AbiFixedBytes(32), // callDataHash
      AbiUint(256), // callGasLimit
      AbiUint(256), // verificationGasLimit
      AbiUint(256), // preVerificationGas
      AbiUint(256), // maxFeePerGas
      AbiUint(256), // maxPriorityFeePerGas
      AbiFixedBytes(32), // paymasterAndDataHash
    ];

    final values = [
      sender,
      nonce,
      HexUtils.decode(initCodeHash),
      HexUtils.decode(callDataHash),
      callGasLimit,
      verificationGasLimit,
      preVerificationGas,
      maxFeePerGas,
      maxPriorityFeePerGas,
      HexUtils.decode(paymasterAndDataHash),
    ];

    return AbiEncoder.encode(types, values);
  }

  /// ABI encode UserOperation for v0.7 according to ERC-4337 specification.
  ///
  /// Encodes: (address sender, uint256 nonce, bytes32 initCodeHash, bytes32 callDataHash,
  ///           bytes32 accountGasLimits, uint256 preVerificationGas, bytes32 gasFees,
  ///           bytes32 paymasterAndDataHash)
  Uint8List _encodeUserOpV07(
    String sender,
    BigInt nonce,
    String initCodeHash,
    String callDataHash,
    String accountGasLimits,
    BigInt preVerificationGas,
    String gasFees,
    String paymasterAndDataHash,
  ) {
    final types = [
      AbiAddress(), // sender
      AbiUint(256), // nonce
      AbiFixedBytes(32), // initCodeHash
      AbiFixedBytes(32), // callDataHash
      AbiFixedBytes(32), // accountGasLimits (packed)
      AbiUint(256), // preVerificationGas
      AbiFixedBytes(32), // gasFees (packed)
      AbiFixedBytes(32), // paymasterAndDataHash
    ];

    final values = [
      sender,
      nonce,
      HexUtils.decode(initCodeHash),
      HexUtils.decode(callDataHash),
      HexUtils.decode(accountGasLimits),
      preVerificationGas,
      HexUtils.decode(gasFees),
      HexUtils.decode(paymasterAndDataHash),
    ];

    return AbiEncoder.encode(types, values);
  }

  /// Encode final hash with entryPoint and chainId according to ERC-4337.
  ///
  /// Final hash = keccak256(abi.encode(userOpHash, entryPointAddress, chainId))
  Uint8List _encodeFinalHash(
      Uint8List userOpHash, String entryPointAddress, int chainId) {
    final types = [
      AbiFixedBytes(32), // userOpHash
      AbiAddress(), // entryPointAddress
      AbiUint(256), // chainId
    ];

    final values = [
      userOpHash,
      entryPointAddress,
      BigInt.from(chainId),
    ];

    return AbiEncoder.encode(types, values);
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
      paymasterVerificationGasLimit:
          paymasterVerificationGasLimit ?? this.paymasterVerificationGasLimit,
      paymasterPostOpGasLimit:
          paymasterPostOpGasLimit ?? this.paymasterPostOpGasLimit,
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
  final String sender;
  final BigInt nonce;
  final String initCode;
  final String callData;
  final String accountGasLimits;
  final BigInt preVerificationGas;
  final String gasFees;
  final String paymasterAndData;
  final String signature;
}

/// UserOperation request for building operations
class UserOperationRequest {
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
}

/// Gas estimation result for UserOperation
class UserOperationGasEstimate {
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
      verificationGasLimit:
          BigInt.parse(json['verificationGasLimit'] as String),
      callGasLimit: BigInt.parse(json['callGasLimit'] as String),
      paymasterVerificationGasLimit:
          json['paymasterVerificationGasLimit'] != null
              ? BigInt.parse(json['paymasterVerificationGasLimit'] as String)
              : null,
      paymasterPostOpGasLimit: json['paymasterPostOpGasLimit'] != null
          ? BigInt.parse(json['paymasterPostOpGasLimit'] as String)
          : null,
    );
  }
  final BigInt preVerificationGas;
  final BigInt verificationGasLimit;
  final BigInt callGasLimit;
  final BigInt? paymasterVerificationGasLimit;
  final BigInt? paymasterPostOpGasLimit;
}

/// UserOperation receipt from bundler
class UserOperationReceipt {
  UserOperationReceipt({
    required this.userOpHash,
    required this.sender,
    required this.nonce,
    required this.actualGasCost,
    required this.actualGasUsed,
    required this.success,
    required this.entryPoint,
    required this.receipt,
    this.paymaster,
    this.reason,
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
}
