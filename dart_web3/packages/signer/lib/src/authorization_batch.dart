import 'dart:typed_data';

import 'authorization.dart';
import 'signer.dart';

/// Utility class for creating and managing batch authorizations.
class AuthorizationBatch {

  /// Creates an empty authorization batch.
  AuthorizationBatch();

  /// Creates a batch authorization for multiple contracts.
  /// 
  /// This allows delegating to multiple contracts in a single transaction.
  factory AuthorizationBatch.forContracts({
    required int chainId,
    required List<String> contractAddresses,
    required BigInt startingNonce,
  }) {
    final batch = AuthorizationBatch();
    
    for (var i = 0; i < contractAddresses.length; i++) {
      final authorization = Authorization.unsigned(
        chainId: chainId,
        address: contractAddresses[i],
        nonce: startingNonce + BigInt.from(i),
      );
      batch.add(authorization);
    }
    
    return batch;
  }

  /// Creates a batch with revocation authorizations.
  /// 
  /// This creates authorizations that revoke existing delegations.
  factory AuthorizationBatch.revocations({
    required int chainId,
    required List<BigInt> nonces,
  }) {
    final batch = AuthorizationBatch();
    
    for (final nonce in nonces) {
      final revocation = Authorization.revocation(
        chainId: chainId,
        nonce: nonce,
      );
      batch.add(revocation);
    }
    
    return batch;
  }

  /// Creates a batch from RLP list.
  factory AuthorizationBatch.fromRlpList(List<List<dynamic>> rlpList) {
    final batch = AuthorizationBatch();
    
    for (final authRlp in rlpList) {
      final authorization = Authorization.fromRlpList(authRlp);
      batch.add(authorization);
    }
    
    return batch;
  }
  final List<Authorization> _authorizations = [];

  /// Gets the list of authorizations in this batch.
  List<Authorization> get authorizations => List.unmodifiable(_authorizations);

  /// Gets the number of authorizations in this batch.
  int get length => _authorizations.length;

  /// Checks if the batch is empty.
  bool get isEmpty => _authorizations.isEmpty;

  /// Checks if the batch is not empty.
  bool get isNotEmpty => _authorizations.isNotEmpty;

  /// Adds an authorization to the batch.
  void add(Authorization authorization) {
    _authorizations.add(authorization);
  }

  /// Adds multiple authorizations to the batch.
  void addAll(Iterable<Authorization> authorizations) {
    _authorizations.addAll(authorizations);
  }

  /// Removes an authorization from the batch.
  bool remove(Authorization authorization) {
    return _authorizations.remove(authorization);
  }

  /// Removes an authorization at the specified index.
  Authorization removeAt(int index) {
    return _authorizations.removeAt(index);
  }

  /// Clears all authorizations from the batch.
  void clear() {
    _authorizations.clear();
  }

  /// Signs all authorizations in the batch with the given signer.
  /// 
  /// Returns a new batch with all authorizations signed.
  Future<AuthorizationBatch> signAll(Signer signer) async {
    final signedBatch = AuthorizationBatch();
    
    for (final authorization in _authorizations) {
      final signature = await signer.signAuthorization(authorization);
      
      // Extract signature components
      final r = signature.sublist(0, 32);
      final s = signature.sublist(32, 64);
      final yParity = signature[64];
      
      final signedAuth = authorization.withSignature(
        yParity: yParity,
        r: _bytesToBigInt(r),
        s: _bytesToBigInt(s),
      );
      
      signedBatch.add(signedAuth);
    }
    
    return signedBatch;
  }

  /// Signs all authorizations in the batch with a private key.
  /// 
  /// Returns a new batch with all authorizations signed.
  AuthorizationBatch signAllWithPrivateKey(Uint8List privateKey) {
    final signedBatch = AuthorizationBatch();
    
    for (final authorization in _authorizations) {
      final signedAuth = authorization.sign(privateKey);
      signedBatch.add(signedAuth);
    }
    
    return signedBatch;
  }

  /// Validates that all authorizations in the batch are properly formatted.
  bool validateFormat() {
    return _authorizations.every(_isValidFormat);
  }

  /// Gets the total gas cost estimate for this batch.
  /// 
  /// Each authorization adds approximately 2,300 gas to the transaction.
  BigInt estimateGasCost() {
    return BigInt.from(_authorizations.length * 2300);
  }

  /// Converts the batch to a list suitable for RLP encoding.
  List<List<dynamic>> toRlpList() {
    return _authorizations.map((auth) => auth.toRlpList()).toList();
  }

  /// Creates a copy of this batch.
  AuthorizationBatch copy() {
    final newBatch = AuthorizationBatch();
    newBatch.addAll(_authorizations);
    return newBatch;
  }

  /// Filters authorizations by chain ID.
  AuthorizationBatch filterByChainId(int chainId) {
    final filtered = AuthorizationBatch();
    for (final auth in _authorizations) {
      if (auth.chainId == chainId) {
        filtered.add(auth);
      }
    }
    return filtered;
  }

  /// Gets all unique contract addresses in this batch.
  Set<String> getContractAddresses() {
    return _authorizations.map((auth) => auth.address).toSet();
  }

  /// Gets all unique chain IDs in this batch.
  Set<int> getChainIds() {
    return _authorizations.map((auth) => auth.chainId).toSet();
  }

  /// Checks if all authorizations are signed.
  bool get areAllSigned => _authorizations.every((auth) => auth.isSigned);

  /// Checks if any authorization is a revocation.
  bool get hasRevocations => _authorizations.any((auth) => auth.isRevocation);

  /// Gets only the revocation authorizations.
  List<Authorization> get revocations => 
      _authorizations.where((auth) => auth.isRevocation).toList();

  /// Gets only the non-revocation authorizations.
  List<Authorization> get delegations => 
      _authorizations.where((auth) => !auth.isRevocation).toList();

  @override
  String toString() {
    return 'AuthorizationBatch(length: $length, signed: $areAllSigned)';
  }

  // Helper methods

  bool _isValidFormat(Authorization authorization) {
    try {
      // Check chain ID
      if (authorization.chainId <= 0) return false;

      // Check nonce
      if (authorization.nonce < BigInt.zero) return false;

      // Check address format (basic hex check)
      if (!authorization.address.startsWith('0x') || authorization.address.length != 42) {
        return false;
      }

      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }
}
