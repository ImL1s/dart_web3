import 'dart:typed_data';

import 'authorization.dart';
import 'authorization_batch.dart';
import 'signer.dart';

/// Utility class for managing EIP-7702 authorization revocations.
class AuthorizationRevocation {
  /// Creates a single revocation authorization.
  ///
  /// Setting the address to zero address revokes any existing delegation
  /// for the given nonce.
  static Authorization createRevocation({
    required int chainId,
    required BigInt nonce,
  }) {
    return Authorization.revocation(
      chainId: chainId,
      nonce: nonce,
    );
  }

  /// Creates multiple revocation authorizations.
  ///
  /// This is useful for revoking multiple delegations in a single transaction.
  static AuthorizationBatch createRevocationBatch({
    required int chainId,
    required List<BigInt> nonces,
  }) {
    return AuthorizationBatch.revocations(
      chainId: chainId,
      nonces: nonces,
    );
  }

  /// Creates a revocation for a specific contract delegation.
  ///
  /// This revokes the delegation to a specific contract address by setting
  /// the authorization address to zero.
  static Authorization revokeContractDelegation({
    required int chainId,
    required BigInt nonce,
  }) {
    return createRevocation(chainId: chainId, nonce: nonce);
  }

  /// Creates revocations for multiple contract delegations.
  static AuthorizationBatch revokeMultipleContractDelegations({
    required int chainId,
    required List<BigInt> nonces,
  }) {
    return createRevocationBatch(chainId: chainId, nonces: nonces);
  }

  /// Signs a revocation authorization.
  static Future<Authorization> signRevocation({
    required Authorization revocation,
    required Signer signer,
  }) async {
    if (!revocation.isRevocation) {
      throw ArgumentError('Authorization is not a revocation');
    }

    final signature = await signer.signAuthorization(revocation);

    // Extract signature components
    final r = signature.sublist(0, 32);
    final s = signature.sublist(32, 64);
    final yParity = signature[64];

    return revocation.withSignature(
      yParity: yParity,
      r: _bytesToBigInt(r),
      s: _bytesToBigInt(s),
    );
  }

  /// Signs a revocation authorization with a private key.
  static Authorization signRevocationWithPrivateKey({
    required Authorization revocation,
    required Uint8List privateKey,
  }) {
    if (!revocation.isRevocation) {
      throw ArgumentError('Authorization is not a revocation');
    }

    return revocation.sign(privateKey);
  }

  /// Signs multiple revocation authorizations.
  static Future<AuthorizationBatch> signRevocationBatch({
    required AuthorizationBatch revocationBatch,
    required Signer signer,
  }) async {
    // Validate that all authorizations are revocations
    for (final auth in revocationBatch.authorizations) {
      if (!auth.isRevocation) {
        throw ArgumentError('All authorizations in batch must be revocations');
      }
    }

    return revocationBatch.signAll(signer);
  }

  /// Signs multiple revocation authorizations with a private key.
  static AuthorizationBatch signRevocationBatchWithPrivateKey({
    required AuthorizationBatch revocationBatch,
    required Uint8List privateKey,
  }) {
    // Validate that all authorizations are revocations
    for (final auth in revocationBatch.authorizations) {
      if (!auth.isRevocation) {
        throw ArgumentError('All authorizations in batch must be revocations');
      }
    }

    return revocationBatch.signAllWithPrivateKey(privateKey);
  }

  /// Checks if an authorization is a valid revocation.
  ///
  /// A valid revocation must:
  /// - Have address set to zero address
  /// - Have valid chain ID and nonce
  /// - If signed, have valid signature
  static bool isValidRevocation(Authorization authorization) {
    // Must be a revocation (zero address)
    if (!authorization.isRevocation) return false;

    // Must have valid chain ID
    if (authorization.chainId <= 0) return false;

    // Must have non-negative nonce
    if (authorization.nonce < BigInt.zero) return false;

    // If signed, signature must be valid format
    if (authorization.isSigned) {
      if (authorization.yParity != 0 && authorization.yParity != 1)
        return false;
      if (authorization.r == BigInt.zero && authorization.s == BigInt.zero)
        return false;
    }

    return true;
  }

  /// Validates a batch of revocation authorizations.
  static Map<int, bool> validateRevocationBatch(AuthorizationBatch batch) {
    final results = <int, bool>{};

    for (var i = 0; i < batch.length; i++) {
      results[i] = isValidRevocation(batch.authorizations[i]);
    }

    return results;
  }

  /// Checks if all authorizations in a batch are valid revocations.
  static bool isValidRevocationBatch(AuthorizationBatch batch) {
    return batch.authorizations.every(isValidRevocation);
  }

  /// Creates a revocation that undoes a previous delegation.
  ///
  /// This creates a revocation authorization that uses the same nonce
  /// as the original delegation, effectively canceling it.
  static Authorization undoDelegation({
    required Authorization originalDelegation,
  }) {
    if (originalDelegation.isRevocation) {
      throw ArgumentError('Cannot undo a revocation authorization');
    }

    return createRevocation(
      chainId: originalDelegation.chainId,
      nonce: originalDelegation.nonce,
    );
  }

  /// Creates revocations that undo multiple previous delegations.
  static AuthorizationBatch undoMultipleDelegations({
    required List<Authorization> originalDelegations,
  }) {
    final batch = AuthorizationBatch();

    for (final delegation in originalDelegations) {
      if (delegation.isRevocation) {
        throw ArgumentError('Cannot undo a revocation authorization');
      }

      final revocation = undoDelegation(originalDelegation: delegation);
      batch.add(revocation);
    }

    return batch;
  }

  /// Gets the zero address used for revocations.
  static String get zeroAddress => '0x${'0' * 40}';

  /// Checks if an address is the zero address (used for revocations).
  static bool isZeroAddress(String address) {
    return address.toLowerCase() == zeroAddress.toLowerCase();
  }

  // Helper method
  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }
}
