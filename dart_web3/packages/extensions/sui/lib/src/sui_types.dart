import 'dart:typed_data';

/// Sui address (32 bytes, displayed as hex with 0x prefix).
class SuiAddress {
  /// Creates a SuiAddress from bytes.
  const SuiAddress(this.bytes);

  /// Creates a SuiAddress from a hex string.
  factory SuiAddress.fromHex(String hex) {
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
    return SuiAddress(bytes);
  }

  /// The raw 32-byte address.
  final Uint8List bytes;

  /// Returns the address as a hex string with 0x prefix.
  String toHex() {
    final buffer = StringBuffer('0x');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Returns a shortened display format.
  String toShortString() {
    final hex = toHex();
    return '${hex.substring(0, 6)}...${hex.substring(hex.length - 4)}';
  }

  @override
  String toString() => toHex();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SuiAddress) return false;
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);
}

/// Sui object ID (same format as address).
typedef SuiObjectId = SuiAddress;

/// Sui digest (32 bytes, base58 encoded in display).
class SuiDigest {
  /// Creates a SuiDigest from bytes.
  const SuiDigest(this.bytes);

  /// The raw 32-byte digest.
  final Uint8List bytes;

  /// Creates a SuiDigest from a base58 string.
  factory SuiDigest.fromBase58(String base58) {
    // Placeholder - would use proper Base58 decoding
    return SuiDigest(Uint8List(32));
  }

  /// Returns the digest as a base58 string.
  String toBase58() {
    // Placeholder - would use proper Base58 encoding
    return 'DigestPlaceholder';
  }

  @override
  String toString() => toBase58();
}

/// Type tag for Move types.
class SuiTypeTag {
  /// Creates a SuiTypeTag.
  const SuiTypeTag(this.value);

  /// Creates a type tag from a string representation.
  factory SuiTypeTag.fromString(String typeStr) {
    return SuiTypeTag(typeStr);
  }

  /// The type tag string representation.
  final String value;

  /// Built-in type tags.
  static const bool_ = SuiTypeTag('bool');
  static const u8 = SuiTypeTag('u8');
  static const u16 = SuiTypeTag('u16');
  static const u32 = SuiTypeTag('u32');
  static const u64 = SuiTypeTag('u64');
  static const u128 = SuiTypeTag('u128');
  static const u256 = SuiTypeTag('u256');
  static const address = SuiTypeTag('address');
  static const signer = SuiTypeTag('signer');

  /// Creates a vector type tag.
  static SuiTypeTag vector(SuiTypeTag inner) {
    return SuiTypeTag('vector<${inner.value}>');
  }

  /// Creates a struct type tag.
  static SuiTypeTag struct_(
    String address,
    String module,
    String name, [
    List<SuiTypeTag>? typeArgs,
  ]) {
    final typeArgsStr =
        typeArgs != null && typeArgs.isNotEmpty
            ? '<${typeArgs.map((t) => t.value).join(', ')}>'
            : '';
    return SuiTypeTag('$address::$module::$name$typeArgsStr');
  }

  @override
  String toString() => value;
}

/// Sui object reference.
class SuiObjectRef {
  /// Creates a SuiObjectRef.
  const SuiObjectRef({
    required this.objectId,
    required this.version,
    required this.digest,
  });

  /// Object ID.
  final SuiObjectId objectId;

  /// Object version (sequence number).
  final BigInt version;

  /// Object digest.
  final SuiDigest digest;
}

/// Sui owned object reference (includes owner).
class SuiOwnedObjectRef {
  /// Creates a SuiOwnedObjectRef.
  const SuiOwnedObjectRef({required this.owner, required this.reference});

  /// Owner of the object.
  final SuiOwner owner;

  /// Object reference.
  final SuiObjectRef reference;
}

/// Sui object owner types.
sealed class SuiOwner {
  const SuiOwner();
}

/// Object owned by an address.
class AddressOwner extends SuiOwner {
  /// Creates an AddressOwner.
  const AddressOwner(this.address);

  /// The owning address.
  final SuiAddress address;
}

/// Object owned by another object.
class ObjectOwner extends SuiOwner {
  /// Creates an ObjectOwner.
  const ObjectOwner(this.objectId);

  /// The owning object ID.
  final SuiObjectId objectId;
}

/// Shared object.
class SharedOwner extends SuiOwner {
  /// Creates a SharedOwner.
  const SharedOwner({required this.initialSharedVersion});

  /// The version at which the object was shared.
  final BigInt initialSharedVersion;
}

/// Immutable object (no owner).
class ImmutableOwner extends SuiOwner {
  /// Creates an ImmutableOwner.
  const ImmutableOwner();
}

/// Sui coin metadata.
class SuiCoinMetadata {
  /// Creates SuiCoinMetadata.
  const SuiCoinMetadata({
    required this.decimals,
    required this.name,
    required this.symbol,
    required this.description,
    this.iconUrl,
    required this.id,
  });

  /// Number of decimals.
  final int decimals;

  /// Coin name.
  final String name;

  /// Coin symbol.
  final String symbol;

  /// Coin description.
  final String description;

  /// Icon URL.
  final String? iconUrl;

  /// Metadata object ID.
  final SuiObjectId id;
}

/// SUI coin type constant.
const suiCoinType = '0x2::sui::SUI';

/// Sui gas data.
class SuiGasData {
  /// Creates SuiGasData.
  const SuiGasData({
    required this.payment,
    required this.owner,
    required this.price,
    required this.budget,
  });

  /// Gas payment objects.
  final List<SuiObjectRef> payment;

  /// Gas owner address.
  final SuiAddress owner;

  /// Gas price in MIST.
  final BigInt price;

  /// Gas budget in MIST.
  final BigInt budget;
}

/// Sui epoch information.
class SuiEpoch {
  /// Creates a SuiEpoch.
  const SuiEpoch({
    required this.epoch,
    required this.epochStartTimestampMs,
    this.epochDurationMs,
    this.referenceGasPrice,
  });

  /// Epoch number.
  final BigInt epoch;

  /// Epoch start timestamp in milliseconds.
  final BigInt epochStartTimestampMs;

  /// Epoch duration in milliseconds.
  final BigInt? epochDurationMs;

  /// Reference gas price for this epoch.
  final BigInt? referenceGasPrice;
}
