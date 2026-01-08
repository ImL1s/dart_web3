import 'dart:typed_data';

/// Aptos address (32 bytes, displayed as hex with 0x prefix).
class AptosAddress {
  /// Creates an AptosAddress from bytes.
  const AptosAddress(this.bytes);

  /// Creates an AptosAddress from a hex string.
  factory AptosAddress.fromHex(String hex) {
    var cleanHex = hex.toLowerCase();
    if (cleanHex.startsWith('0x')) {
      cleanHex = cleanHex.substring(2);
    }
    // Pad to 64 characters (32 bytes)
    cleanHex = cleanHex.padLeft(64, '0');

    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return AptosAddress(bytes);
  }

  /// Standard address for 0x1 (framework).
  static final framework = AptosAddress.fromHex('0x1');

  /// Standard address for 0x3 (token).
  static final token = AptosAddress.fromHex('0x3');

  /// Standard address for 0x4 (objects).
  static final objects = AptosAddress.fromHex('0x4');

  /// The raw 32-byte address.
  final Uint8List bytes;

  /// Returns the address as a hex string with 0x prefix.
  String toHex() {
    final buffer = StringBuffer('0x');
    // Skip leading zeros for display
    var started = false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0) started = true;
      if (started || i == bytes.length - 1) {
        buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  /// Returns the full address with all 64 hex characters.
  String toFullHex() {
    final buffer = StringBuffer('0x');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Returns a shortened display format.
  String toShortString() {
    final hex = toFullHex();
    return '${hex.substring(0, 6)}...${hex.substring(hex.length - 4)}';
  }

  @override
  String toString() => toHex();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AptosAddress) return false;
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);
}

/// Aptos type tag for Move types.
class AptosTypeTag {
  /// Creates an AptosTypeTag.
  const AptosTypeTag(this.value);

  /// Creates a type tag from a string representation.
  factory AptosTypeTag.fromString(String typeStr) {
    return AptosTypeTag(typeStr);
  }

  /// The type tag string representation.
  final String value;

  /// Built-in type tags.
  static const bool_ = AptosTypeTag('bool');
  static const u8 = AptosTypeTag('u8');
  static const u16 = AptosTypeTag('u16');
  static const u32 = AptosTypeTag('u32');
  static const u64 = AptosTypeTag('u64');
  static const u128 = AptosTypeTag('u128');
  static const u256 = AptosTypeTag('u256');
  static const address = AptosTypeTag('address');
  static const signer = AptosTypeTag('signer');

  /// Creates a vector type tag.
  static AptosTypeTag vector(AptosTypeTag inner) {
    return AptosTypeTag('vector<${inner.value}>');
  }

  /// Creates a struct type tag.
  static AptosTypeTag struct_(
    String address,
    String module,
    String name, [
    List<AptosTypeTag>? typeArgs,
  ]) {
    final typeArgsStr =
        typeArgs != null && typeArgs.isNotEmpty
            ? '<${typeArgs.map((t) => t.value).join(', ')}>'
            : '';
    return AptosTypeTag('$address::$module::$name$typeArgsStr');
  }

  /// APT coin type.
  static final aptCoin = AptosTypeTag.struct_('0x1', 'aptos_coin', 'AptosCoin');

  @override
  String toString() => value;
}

/// Aptos account resource.
class AptosAccountResource {
  /// Creates an AptosAccountResource.
  const AptosAccountResource({
    required this.type,
    required this.data,
  });

  /// Creates from JSON.
  factory AptosAccountResource.fromJson(Map<String, dynamic> json) {
    return AptosAccountResource(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  /// Resource type.
  final String type;

  /// Resource data.
  final Map<String, dynamic> data;
}

/// Aptos account information.
class AptosAccount {
  /// Creates an AptosAccount.
  const AptosAccount({
    required this.sequenceNumber,
    required this.authenticationKey,
  });

  /// Creates from JSON.
  factory AptosAccount.fromJson(Map<String, dynamic> json) {
    return AptosAccount(
      sequenceNumber: BigInt.parse(json['sequence_number'] as String),
      authenticationKey: json['authentication_key'] as String,
    );
  }

  /// Account sequence number (nonce).
  final BigInt sequenceNumber;

  /// Authentication key.
  final String authenticationKey;
}

/// Aptos coin store.
class AptosCoinStore {
  /// Creates an AptosCoinStore.
  const AptosCoinStore({
    required this.coin,
    required this.frozen,
  });

  /// Creates from JSON.
  factory AptosCoinStore.fromJson(Map<String, dynamic> json) {
    return AptosCoinStore(
      coin: AptosCoin.fromJson(json['coin'] as Map<String, dynamic>),
      frozen: json['frozen'] as bool,
    );
  }

  /// The coin.
  final AptosCoin coin;

  /// Whether the store is frozen.
  final bool frozen;
}

/// Aptos coin.
class AptosCoin {
  /// Creates an AptosCoin.
  const AptosCoin({required this.value});

  /// Creates from JSON.
  factory AptosCoin.fromJson(Map<String, dynamic> json) {
    return AptosCoin(value: BigInt.parse(json['value'] as String));
  }

  /// Coin value in octas (1 APT = 10^8 octas).
  final BigInt value;
}

/// Aptos ledger information.
class AptosLedgerInfo {
  /// Creates an AptosLedgerInfo.
  const AptosLedgerInfo({
    required this.chainId,
    required this.epoch,
    required this.ledgerVersion,
    required this.oldestLedgerVersion,
    required this.ledgerTimestamp,
    required this.nodeRole,
    required this.oldestBlockHeight,
    required this.blockHeight,
    required this.gitHash,
  });

  /// Creates from JSON.
  factory AptosLedgerInfo.fromJson(Map<String, dynamic> json) {
    return AptosLedgerInfo(
      chainId: json['chain_id'] as int,
      epoch: BigInt.parse(json['epoch'] as String),
      ledgerVersion: BigInt.parse(json['ledger_version'] as String),
      oldestLedgerVersion: BigInt.parse(json['oldest_ledger_version'] as String),
      ledgerTimestamp: BigInt.parse(json['ledger_timestamp'] as String),
      nodeRole: json['node_role'] as String,
      oldestBlockHeight: BigInt.parse(json['oldest_block_height'] as String),
      blockHeight: BigInt.parse(json['block_height'] as String),
      gitHash: json['git_hash'] as String?,
    );
  }

  final int chainId;
  final BigInt epoch;
  final BigInt ledgerVersion;
  final BigInt oldestLedgerVersion;
  final BigInt ledgerTimestamp;
  final String nodeRole;
  final BigInt oldestBlockHeight;
  final BigInt blockHeight;
  final String? gitHash;
}

/// Aptos gas estimation.
class AptosGasEstimation {
  /// Creates an AptosGasEstimation.
  const AptosGasEstimation({
    required this.gasEstimate,
    required this.deprioritizedGasEstimate,
    required this.prioritizedGasEstimate,
  });

  /// Creates from JSON.
  factory AptosGasEstimation.fromJson(Map<String, dynamic> json) {
    return AptosGasEstimation(
      gasEstimate: json['gas_estimate'] as int,
      deprioritizedGasEstimate: json['deprioritized_gas_estimate'] as int?,
      prioritizedGasEstimate: json['prioritized_gas_estimate'] as int?,
    );
  }

  /// Standard gas estimate.
  final int gasEstimate;

  /// Deprioritized gas estimate.
  final int? deprioritizedGasEstimate;

  /// Prioritized gas estimate.
  final int? prioritizedGasEstimate;
}

/// Aptos block.
class AptosBlock {
  /// Creates an AptosBlock.
  const AptosBlock({
    required this.blockHeight,
    required this.blockHash,
    required this.blockTimestamp,
    required this.firstVersion,
    required this.lastVersion,
    this.transactions,
  });

  /// Creates from JSON.
  factory AptosBlock.fromJson(Map<String, dynamic> json) {
    return AptosBlock(
      blockHeight: BigInt.parse(json['block_height'] as String),
      blockHash: json['block_hash'] as String,
      blockTimestamp: BigInt.parse(json['block_timestamp'] as String),
      firstVersion: BigInt.parse(json['first_version'] as String),
      lastVersion: BigInt.parse(json['last_version'] as String),
      transactions: json['transactions'] as List?,
    );
  }

  final BigInt blockHeight;
  final String blockHash;
  final BigInt blockTimestamp;
  final BigInt firstVersion;
  final BigInt lastVersion;
  final List? transactions;
}

/// Aptos event.
class AptosEvent {
  /// Creates an AptosEvent.
  const AptosEvent({
    required this.guid,
    required this.sequenceNumber,
    required this.type,
    required this.data,
  });

  /// Creates from JSON.
  factory AptosEvent.fromJson(Map<String, dynamic> json) {
    return AptosEvent(
      guid: AptosEventGuid.fromJson(json['guid'] as Map<String, dynamic>),
      sequenceNumber: BigInt.parse(json['sequence_number'] as String),
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  final AptosEventGuid guid;
  final BigInt sequenceNumber;
  final String type;
  final Map<String, dynamic> data;
}

/// Aptos event GUID.
class AptosEventGuid {
  /// Creates an AptosEventGuid.
  const AptosEventGuid({
    required this.creationNumber,
    required this.accountAddress,
  });

  /// Creates from JSON.
  factory AptosEventGuid.fromJson(Map<String, dynamic> json) {
    return AptosEventGuid(
      creationNumber: BigInt.parse(json['creation_number'] as String),
      accountAddress: json['account_address'] as String,
    );
  }

  final BigInt creationNumber;
  final String accountAddress;
}

/// Signature schemes supported by Aptos.
enum AptosSignatureScheme {
  /// Ed25519 signature.
  ed25519(0),

  /// Multi-Ed25519 signature.
  multiEd25519(1),

  /// Single key signature.
  singleKey(2),

  /// Multi key signature.
  multiKey(3);

  const AptosSignatureScheme(this.value);

  /// Scheme identifier.
  final int value;
}
