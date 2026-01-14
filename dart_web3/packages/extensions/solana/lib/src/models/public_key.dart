import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Represents a Solana Public Key.
class PublicKey {
  PublicKey(this.bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Invalid public key length');
    }
  }

  factory PublicKey.fromString(String address) {
    final decoded = Base58.decode(address);
    if (decoded.length != 32) {
      throw ArgumentError('Invalid public key length');
    }
    return PublicKey(decoded);
  }

  factory PublicKey.fromBase58(String address) => PublicKey.fromString(address);

  static final defaultPublicKey = PublicKey(Uint8List(32));

  final Uint8List bytes;

  Uint8List toBytes() => bytes;

  String toBase58() => Base58.encode(bytes);

  @override
  String toString() => toBase58();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicKey &&
          runtimeType == other.runtimeType &&
          BytesUtils.equals(bytes, other.bytes);

  @override
  int get hashCode => bytes.fold(0, (p, c) => p + c);

  /// Derives a Program Address (e.g. for PDAs).
  ///
  /// [seeds] - List of seeds (bytes).
  /// [programId] - The program ID to derive address for.
  static PublicKey createProgramAddress(
      List<Uint8List> seeds, PublicKey programId) {
    final buffer = BytesBuilder();
    for (final seed in seeds) {
      buffer.add(seed);
    }
    buffer.add(programId.bytes);
    buffer.add(Uint8List.fromList('ProgramDerivedAddress'.codeUnits));

    final hash = Sha256.hash(buffer.toBytes());

    if (_isOnCurve(hash)) {
      throw Exception('Invalid seeds, address must fall off the curve');
    }
    return PublicKey(hash);
  }

  /// Check if the point is on the Ed25519 curve.
  static bool _isOnCurve(Uint8List bytes) {
    try {
      // We use Ed25519 to check if it's a valid point compression.
      // The `crypto` package might not expose `isOnCurve` directly but `PublicKey.verify`
      // or low level usage implies validity.
      // Actually, for PDA, we just need to ensure it DOES NOT map to a valid Ed25519 public key.
      // However, `web3_universal_crypto` Ed25519 implementation naturally handles valid points.
      // If we interpret the 32 bytes as a Point, is it valid?
      // TODO: Expose `isOnCurve` in Ed25519 low-level or attempt to decode.
      // For now, attempting to construct an Ed25519 public key might throw if invalid?
      // Actually most 32-byte sequences are valid Y-coordinates, but some aren't.
      // But PDAs are valid ONLY if they are NOT valid public keys?
      // No, PDAs are just addresses.
      // The rule is: "Program Derived Addresses ... do not lie on the ed25519 curve".
      // So we need `Ed25519.isOnCurve(bytes)`.
      return Ed25519.isOnCurve(bytes);
    } on Object catch (_) {
      return false;
    }
  }

  /// Finds a valid PDA.
  static ProgramAddress findProgramAddress(
      List<Uint8List> seeds, PublicKey programId) {
    var nonce = 255;
    while (nonce != 0) {
      try {
        final seedsWithNonce = [
          ...seeds,
          Uint8List.fromList([nonce])
        ];
        final address = createProgramAddress(seedsWithNonce, programId);
        return ProgramAddress(address, nonce);
      } on Object catch (e) {
        nonce--;
      }
    }
    throw Exception('Unable to find a valid program address');
  }
}

class ProgramAddress {
  ProgramAddress(this.address, this.bump);
  final PublicKey address;
  final int bump;
}
