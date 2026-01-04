import 'dart:typed_data';

import 'bytes.dart';
import 'exceptions.dart';
import 'hex.dart';

/// Represents an Ethereum address with validation and checksum support.
///
/// Supports EIP-55 checksum encoding for mixed-case addresses.
class EthereumAddress {
  /// Creates an EthereumAddress from raw bytes.
  ///
  /// Throws [InvalidAddressException] if bytes length is not 20.
  EthereumAddress(this.bytes) {
    if (bytes.length != 20) {
      throw InvalidAddressException(
        HexUtils.encode(bytes),
        'Address must be exactly 20 bytes, got ${bytes.length}',
      );
    }
  }

  /// Creates an EthereumAddress from a hex string.
  ///
  /// The input can be checksummed or lowercase.
  /// Throws [InvalidAddressException] if the address is invalid.
  factory EthereumAddress.fromHex(String hex) {
    final stripped = HexUtils.strip0x(hex);

    if (stripped.length != 40) {
      throw InvalidAddressException(hex, 'Address must be 40 hex characters');
    }

    if (!HexUtils.isValid(stripped)) {
      throw InvalidAddressException(hex, 'Invalid hex characters');
    }

    return EthereumAddress(HexUtils.decode(stripped));
  }

  /// Creates an EthereumAddress from a public key.
  ///
  /// The public key should be the uncompressed 64-byte public key
  /// (without the 0x04 prefix) or the 65-byte public key (with prefix).
  ///
  /// Note: This requires keccak256 hashing which is in the crypto module.
  /// This factory is provided for API completeness but requires the
  /// keccak256 function to be passed in.
  factory EthereumAddress.fromPublicKey(
    Uint8List publicKey,
    Uint8List Function(Uint8List) keccak256,
  ) {
    Uint8List key;

    if (publicKey.length == 65 && publicKey[0] == 0x04) {
      // Remove the 0x04 prefix
      key = BytesUtils.slice(publicKey, 1);
    } else if (publicKey.length == 64) {
      key = publicKey;
    } else {
      throw InvalidAddressException(
        HexUtils.encode(publicKey),
        'Invalid public key length: ${publicKey.length}',
      );
    }

    // Take the last 20 bytes of the keccak256 hash
    final hash = keccak256(key);
    return EthereumAddress(BytesUtils.slice(hash, 12));
  }

  /// The raw 20-byte address.
  final Uint8List bytes;

  /// Returns the address as a lowercase hex string with 0x prefix.
  String get hex => HexUtils.encode(bytes).toLowerCase();

  /// Returns the address as a checksummed hex string (EIP-55).
  ///
  /// Note: This requires keccak256 hashing. If not available,
  /// use [hex] for lowercase representation.
  String toChecksum(Uint8List Function(Uint8List) keccak256) {
    final lowercaseHex = HexUtils.strip0x(hex);
    final hash = keccak256(Uint8List.fromList(lowercaseHex.codeUnits));
    final hashHex = HexUtils.strip0x(HexUtils.encode(hash));

    final result = StringBuffer('0x');
    for (var i = 0; i < lowercaseHex.length; i++) {
      final char = lowercaseHex[i];
      final hashChar = hashHex[i];

      // If the hash character is >= 8, uppercase the address character
      if (int.parse(hashChar, radix: 16) >= 8) {
        result.write(char.toUpperCase());
      } else {
        result.write(char);
      }
    }

    return result.toString();
  }

  /// Validates if a string is a valid Ethereum address.
  static bool isValid(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } on InvalidAddressException {
      return false;
    }
  }

  /// Validates if a checksummed address has the correct checksum.
  ///
  /// Returns true if the address is all lowercase, all uppercase,
  /// or has a valid EIP-55 checksum.
  static bool isValidChecksum(
      String address, Uint8List Function(Uint8List) keccak256) {
    if (!isValid(address)) return false;

    final stripped = HexUtils.strip0x(address);

    // All lowercase or all uppercase is valid
    if (stripped == stripped.toLowerCase() ||
        stripped == stripped.toUpperCase()) {
      return true;
    }

    // Check EIP-55 checksum
    final addr = EthereumAddress.fromHex(address);
    return addr.toChecksum(keccak256) == address;
  }

  /// Returns the zero address (0x0000...0000).
  static EthereumAddress get zero => EthereumAddress(Uint8List(20));

  /// Checks if this is the zero address.
  bool get isZero => bytes.every((b) => b == 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EthereumAddress) return false;
    return BytesUtils.equals(bytes, other.bytes);
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => hex;
}
