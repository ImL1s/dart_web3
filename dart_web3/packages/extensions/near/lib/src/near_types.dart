import 'dart:typed_data';

/// NEAR account ID (human-readable string).
class NearAccountId {
  /// Creates a NearAccountId.
  const NearAccountId(this.value);

  /// Creates from string, validating format.
  factory NearAccountId.parse(String accountId) {
    // NEAR account IDs are lowercase and can contain:
    // - a-z, 0-9, -, _
    // - Must be between 2-64 characters
    // - Implicit accounts are 64 hex characters
    if (accountId.isEmpty) {
      throw ArgumentError('Account ID cannot be empty');
    }
    if (accountId.length < 2 || accountId.length > 64) {
      throw ArgumentError('Account ID must be 2-64 characters');
    }
    return NearAccountId(accountId.toLowerCase());
  }

  /// The account ID string.
  final String value;

  /// Whether this is an implicit account (64 hex chars).
  bool get isImplicit => value.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(value);

  /// Whether this is a named account.
  bool get isNamed => !isImplicit;

  /// Gets the top-level account (e.g., "near" from "alice.near").
  String get topLevel {
    final parts = value.split('.');
    return parts.last;
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NearAccountId && value == other.value);

  @override
  int get hashCode => value.hashCode;
}

/// NEAR public key.
class NearPublicKey {
  /// Creates a NearPublicKey.
  const NearPublicKey({required this.keyType, required this.data});

  /// Creates from string (e.g., "ed25519:...").
  factory NearPublicKey.fromString(String publicKey) {
    final parts = publicKey.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid public key format');
    }
    final keyType = NearKeyType.values.firstWhere(
      (t) => t.name == parts[0].toLowerCase(),
      orElse: () => NearKeyType.ed25519,
    );
    // Decode Base58 - placeholder
    return NearPublicKey(keyType: keyType, data: Uint8List(32));
  }

  /// Key type.
  final NearKeyType keyType;

  /// Key data.
  final Uint8List data;

  /// Converts to string representation.
  String toStringKey() {
    // Base58 encoding would go here
    return '${keyType.name}:placeholder';
  }

  @override
  String toString() => toStringKey();
}

/// NEAR key types.
enum NearKeyType {
  /// Ed25519 key.
  ed25519,

  /// SECP256K1 key.
  secp256k1,
}

/// NEAR access key.
class NearAccessKey {
  /// Creates a NearAccessKey.
  const NearAccessKey({required this.nonce, required this.permission});

  /// Creates from JSON.
  factory NearAccessKey.fromJson(Map<String, dynamic> json) {
    return NearAccessKey(
      nonce: BigInt.parse(json['nonce'].toString()),
      permission: NearAccessKeyPermission.fromJson(
        json['permission'] as dynamic,
      ),
    );
  }

  /// Access key nonce.
  final BigInt nonce;

  /// Access key permission.
  final NearAccessKeyPermission permission;
}

/// NEAR access key permission.
sealed class NearAccessKeyPermission {
  const NearAccessKeyPermission();

  /// Creates from JSON.
  factory NearAccessKeyPermission.fromJson(dynamic json) {
    if (json == 'FullAccess') {
      return const FullAccessPermission();
    }
    if (json is Map<String, dynamic> && json.containsKey('FunctionCall')) {
      final fc = json['FunctionCall'] as Map<String, dynamic>;
      return FunctionCallPermission(
        allowance: fc['allowance'] != null
            ? BigInt.parse(fc['allowance'].toString())
            : null,
        receiverId: fc['receiver_id'] as String,
        methodNames: (fc['method_names'] as List).cast<String>(),
      );
    }
    return const FullAccessPermission();
  }
}

/// Full access permission.
class FullAccessPermission extends NearAccessKeyPermission {
  /// Creates a FullAccessPermission.
  const FullAccessPermission();
}

/// Function call permission.
class FunctionCallPermission extends NearAccessKeyPermission {
  /// Creates a FunctionCallPermission.
  const FunctionCallPermission({
    this.allowance,
    required this.receiverId,
    required this.methodNames,
  });

  /// Remaining allowance in yoctoNEAR.
  final BigInt? allowance;

  /// Contract account ID.
  final String receiverId;

  /// Allowed method names (empty = all).
  final List<String> methodNames;
}

/// NEAR account.
class NearAccount {
  /// Creates a NearAccount.
  const NearAccount({
    required this.amount,
    required this.locked,
    required this.codeHash,
    required this.storageUsage,
    required this.storagePaidAt,
  });

  /// Creates from JSON.
  factory NearAccount.fromJson(Map<String, dynamic> json) {
    return NearAccount(
      amount: BigInt.parse(json['amount'] as String),
      locked: BigInt.parse(json['locked'] as String),
      codeHash: json['code_hash'] as String,
      storageUsage: BigInt.parse(json['storage_usage'].toString()),
      storagePaidAt: BigInt.parse(json['storage_paid_at'].toString()),
    );
  }

  /// Available balance in yoctoNEAR.
  final BigInt amount;

  /// Locked balance (staking).
  final BigInt locked;

  /// Code hash (for contracts).
  final String codeHash;

  /// Storage used in bytes.
  final BigInt storageUsage;

  /// Block height when storage was last paid.
  final BigInt storagePaidAt;

  /// Whether the account has a contract.
  bool get hasContract => codeHash != '11111111111111111111111111111111';
}

/// NEAR block.
class NearBlock {
  /// Creates a NearBlock.
  const NearBlock({
    required this.height,
    required this.hash,
    required this.prevHash,
    required this.timestamp,
    required this.epochId,
    required this.chunksIncluded,
  });

  /// Creates from JSON.
  factory NearBlock.fromJson(Map<String, dynamic> json) {
    final header = json['header'] as Map<String, dynamic>;
    return NearBlock(
      height: BigInt.parse(header['height'].toString()),
      hash: header['hash'] as String,
      prevHash: header['prev_hash'] as String,
      timestamp: BigInt.parse(header['timestamp'].toString()),
      epochId: header['epoch_id'] as String,
      chunksIncluded: header['chunks_included'] as int,
    );
  }

  /// Block height.
  final BigInt height;

  /// Block hash.
  final String hash;

  /// Previous block hash.
  final String prevHash;

  /// Block timestamp in nanoseconds.
  final BigInt timestamp;

  /// Epoch ID.
  final String epochId;

  /// Number of chunks included.
  final int chunksIncluded;

  /// Block time as DateTime.
  DateTime get time => DateTime.fromMicrosecondsSinceEpoch(
        (timestamp ~/ BigInt.from(1000)).toInt(),
      );
}

/// NEAR gas price.
class NearGasPrice {
  /// Creates a NearGasPrice.
  const NearGasPrice({required this.gasPrice});

  /// Creates from JSON.
  factory NearGasPrice.fromJson(Map<String, dynamic> json) {
    return NearGasPrice(
      gasPrice: BigInt.parse(json['gas_price'] as String),
    );
  }

  /// Gas price in yoctoNEAR.
  final BigInt gasPrice;
}

/// NEAR validator.
class NearValidator {
  /// Creates a NearValidator.
  const NearValidator({
    required this.accountId,
    required this.publicKey,
    required this.stake,
    this.isSlashed = false,
    this.numProducedBlocks,
    this.numExpectedBlocks,
  });

  /// Creates from JSON.
  factory NearValidator.fromJson(Map<String, dynamic> json) {
    return NearValidator(
      accountId: json['account_id'] as String,
      publicKey: json['public_key'] as String,
      stake: BigInt.parse(json['stake'] as String),
      isSlashed: json['is_slashed'] as bool? ?? false,
      numProducedBlocks: json['num_produced_blocks'] as int?,
      numExpectedBlocks: json['num_expected_blocks'] as int?,
    );
  }

  /// Validator account ID.
  final String accountId;

  /// Validator public key.
  final String publicKey;

  /// Staked amount in yoctoNEAR.
  final BigInt stake;

  /// Whether the validator was slashed.
  final bool isSlashed;

  /// Number of blocks produced.
  final int? numProducedBlocks;

  /// Number of expected blocks.
  final int? numExpectedBlocks;
}

/// NEAR protocol config.
class NearProtocolConfig {
  /// Creates a NearProtocolConfig.
  const NearProtocolConfig({
    required this.protocolVersion,
    required this.genesisHeight,
    required this.epochLength,
    required this.minGasPrice,
    required this.runtimeConfig,
  });

  /// Creates from JSON.
  factory NearProtocolConfig.fromJson(Map<String, dynamic> json) {
    return NearProtocolConfig(
      protocolVersion: json['protocol_version'] as int,
      genesisHeight: BigInt.parse(json['genesis_height'].toString()),
      epochLength: json['epoch_length'] as int,
      minGasPrice: BigInt.parse(json['min_gas_price'] as String),
      runtimeConfig: json['runtime_config'] as Map<String, dynamic>,
    );
  }

  /// Protocol version.
  final int protocolVersion;

  /// Genesis block height.
  final BigInt genesisHeight;

  /// Epoch length in blocks.
  final int epochLength;

  /// Minimum gas price.
  final BigInt minGasPrice;

  /// Runtime configuration.
  final Map<String, dynamic> runtimeConfig;
}

/// NEAR amount in yoctoNEAR (10^-24 NEAR).
class NearAmount {
  /// Creates a NearAmount.
  const NearAmount(this.yoctoNear);

  /// Creates from NEAR (decimal).
  factory NearAmount.fromNear(double near) {
    return NearAmount(
      BigInt.from(near * 1e24),
    );
  }

  /// Parses from string (e.g., "1 NEAR" or "1000000000000000000000000").
  factory NearAmount.parse(String amount) {
    final trimmed = amount.trim().toUpperCase();
    if (trimmed.endsWith('NEAR')) {
      final value = double.parse(trimmed.replaceAll('NEAR', '').trim());
      return NearAmount.fromNear(value);
    }
    return NearAmount(BigInt.parse(trimmed));
  }

  /// One NEAR in yoctoNEAR.
  static final oneNear = NearAmount(BigInt.from(10).pow(24));

  /// Zero amount.
  static final zero = NearAmount(BigInt.zero);

  /// Amount in yoctoNEAR.
  final BigInt yoctoNear;

  /// Converts to NEAR (decimal).
  double toNear() {
    return yoctoNear.toDouble() / 1e24;
  }

  /// Converts to string.
  @override
  String toString() => yoctoNear.toString();

  /// Converts to formatted string.
  String toFormattedString() {
    final near = toNear();
    return '${near.toStringAsFixed(5)} NEAR';
  }

  NearAmount operator +(NearAmount other) =>
      NearAmount(yoctoNear + other.yoctoNear);

  NearAmount operator -(NearAmount other) =>
      NearAmount(yoctoNear - other.yoctoNear);

  bool operator <(NearAmount other) => yoctoNear < other.yoctoNear;
  bool operator >(NearAmount other) => yoctoNear > other.yoctoNear;
  bool operator <=(NearAmount other) => yoctoNear <= other.yoctoNear;
  bool operator >=(NearAmount other) => yoctoNear >= other.yoctoNear;
}

/// NEAR gas amount.
class NearGas {
  /// Creates a NearGas.
  const NearGas(this.gas);

  /// Creates from TGas.
  factory NearGas.tGas(int tgas) {
    return NearGas(BigInt.from(tgas) * BigInt.from(10).pow(12));
  }

  /// Default gas for transfers.
  static final defaultTransfer = NearGas.tGas(30);

  /// Default gas for function calls.
  static final defaultFunctionCall = NearGas.tGas(100);

  /// Maximum gas per transaction.
  static final max = NearGas(BigInt.from(300) * BigInt.from(10).pow(12));

  /// Gas amount.
  final BigInt gas;

  /// Converts to TGas.
  int toTGas() {
    return (gas ~/ BigInt.from(10).pow(12)).toInt();
  }

  @override
  String toString() => gas.toString();
}
