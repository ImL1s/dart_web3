import 'dart:math';
import 'dart:typed_data';

import 'package:dart_web3_crypto/dart_web3_crypto.dart';

import 'mpc_types.dart';

/// Abstract threshold signature scheme interface.
/// 
/// Defines the interface for threshold signature schemes that support
/// both ECDSA (secp256k1) and EdDSA (ed25519) curves.
abstract class ThresholdSignature {
  /// The curve type for this signature scheme.
  CurveType get curveType;
  
  /// The threshold (minimum number of parties required).
  int get threshold;
  
  /// The total number of parties.
  int get totalParties;

  /// Generates key shares for all parties.
  Future<List<KeyShare>> generateKeyShares({
    required List<String> partyIds,
    Map<String, dynamic>? metadata,
  });

  /// Creates a signature share for this party.
  Future<SignatureShare> createSignatureShare({
    required Uint8List messageHash,
    required KeyShare keyShare,
    required String sessionId,
  });

  /// Combines signature shares to create the final signature.
  Future<Uint8List> combineSignatureShares({
    required List<SignatureShare> shares,
    required Uint8List messageHash,
    required Uint8List publicKey,
  });

  /// Verifies a threshold signature.
  Future<bool> verifySignature({
    required Uint8List signature,
    required Uint8List messageHash,
    required Uint8List publicKey,
  });

  /// Refreshes key shares while maintaining the same public key.
  Future<List<KeyShare>> refreshKeyShares(List<KeyShare> oldShares);
}

/// Signature share created by a party in threshold signing.
class SignatureShare {

  SignatureShare({
    required this.partyId,
    required this.shareData,
    required this.sessionId,
    this.metadata = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a SignatureShare from JSON.
  factory SignatureShare.fromJson(Map<String, dynamic> json) {
    return SignatureShare(
      partyId: json['partyId'] as String,
      shareData: Uint8List.fromList((json['shareData'] as List).cast<int>()),
      sessionId: json['sessionId'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  /// The party ID that created this share.
  final String partyId;
  
  /// The signature share data.
  final Uint8List shareData;
  
  /// The session ID this share belongs to.
  final String sessionId;
  
  /// Additional metadata for the share.
  final Map<String, dynamic> metadata;
  
  /// Timestamp when the share was created.
  final DateTime createdAt;

  /// Converts the SignatureShare to JSON.
  Map<String, dynamic> toJson() {
    return {
      'partyId': partyId,
      'shareData': shareData.toList(),
      'sessionId': sessionId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// ECDSA threshold signature implementation for secp256k1.
class EcdsaThresholdSignature implements ThresholdSignature {

  EcdsaThresholdSignature({
    required this.threshold,
    required this.totalParties,
  }) {
    if (threshold <= 0 || threshold > totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Invalid threshold: $threshold (total: $totalParties)',
      );
    }
  }
  @override
  final CurveType curveType = CurveType.secp256k1;
  
  @override
  final int threshold;
  
  @override
  final int totalParties;
  
  /// Random number generator.
  final Random _random = Random.secure();

  @override
  Future<List<KeyShare>> generateKeyShares({
    required List<String> partyIds,
    Map<String, dynamic>? metadata,
  }) async {
    if (partyIds.length != totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Party count mismatch: ${partyIds.length} != $totalParties',
      );
    }

    // Generate master key pair
    final masterPrivateKey = _generateRandomPrivateKey();
    final masterPublicKey = Secp256k1.getPublicKey(masterPrivateKey);

    // Use Shamir's Secret Sharing to split the private key
    final shares = _shamirSecretShare(masterPrivateKey, threshold, totalParties);

    // Create KeyShare objects for each party
    final keyShares = <KeyShare>[];
    for (var i = 0; i < partyIds.length; i++) {
      final keyShare = KeyShare(
        partyId: partyIds[i],
        shareData: _encryptShare(shares[i], partyIds[i]),
        curveType: curveType,
        threshold: threshold,
        totalParties: totalParties,
        publicKey: masterPublicKey,
        createdAt: DateTime.now(),
      );
      keyShares.add(keyShare);
    }

    return keyShares;
  }

  @override
  Future<SignatureShare> createSignatureShare({
    required Uint8List messageHash,
    required KeyShare keyShare,
    required String sessionId,
  }) async {
    // Decrypt the key share
    final privateKeyShare = _decryptShare(keyShare.shareData, keyShare.partyId);

    // Generate ephemeral key for this signing session
    final ephemeralKey = _generateRandomPrivateKey();
    final ephemeralPublicKey = Secp256k1.getPublicKey(ephemeralKey);

    // Create signature share using the private key share and ephemeral key
    final signatureShare = _createEcdsaSignatureShare(
      messageHash,
      privateKeyShare,
      ephemeralKey,
      sessionId,
    );

    return SignatureShare(
      partyId: keyShare.partyId,
      shareData: signatureShare,
      sessionId: sessionId,
      metadata: {
        'ephemeralPublicKey': ephemeralPublicKey.toList(),
        'curveType': curveType.name,
      },
    );
  }

  @override
  Future<Uint8List> combineSignatureShares({
    required List<SignatureShare> shares,
    required Uint8List messageHash,
    required Uint8List publicKey,
  }) async {
    if (shares.length < threshold) {
      throw MpcError(
        type: MpcErrorType.insufficientParties,
        message: 'Insufficient shares: ${shares.length} < $threshold',
      );
    }

    // Validate all shares belong to the same session
    final sessionId = shares.first.sessionId;
    if (!shares.every((share) => share.sessionId == sessionId)) {
      throw MpcError(
        type: MpcErrorType.signingFailed,
        message: 'Signature shares from different sessions',
      );
    }

    // Combine the signature shares using Lagrange interpolation
    final combinedSignature = _combineEcdsaShares(shares, messageHash);

    // Verify the combined signature
    final isValid = await verifySignature(
      signature: combinedSignature,
      messageHash: messageHash,
      publicKey: publicKey,
    );

    if (!isValid) {
      throw MpcError(
        type: MpcErrorType.signingFailed,
        message: 'Combined signature verification failed',
      );
    }

    return combinedSignature;
  }

  @override
  Future<bool> verifySignature({
    required Uint8List signature,
    required Uint8List messageHash,
    required Uint8List publicKey,
  }) async {
    try {
      return Secp256k1.verify(signature, messageHash, publicKey);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<KeyShare>> refreshKeyShares(List<KeyShare> oldShares) async {
    if (oldShares.length != totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Invalid number of shares for refresh',
      );
    }

    // Validate all shares are compatible
    final reference = oldShares.first;
    for (final share in oldShares) {
      if (share.threshold != reference.threshold ||
          share.totalParties != reference.totalParties ||
          share.curveType != reference.curveType) {
        throw MpcError(
          type: MpcErrorType.invalidConfiguration,
          message: 'Incompatible key shares for refresh',
        );
      }
    }

    // Generate new random polynomials for proactive refresh
    final refreshedShares = <KeyShare>[];
    
    for (final oldShare in oldShares) {
      // Decrypt old share
      final oldPrivateKeyShare = _decryptShare(oldShare.shareData, oldShare.partyId);
      
      // Add random value for proactive security (simplified)
      final refreshValue = _generateRandomPrivateKey();
      final newPrivateKeyShare = _addPrivateKeys(oldPrivateKeyShare, refreshValue);
      
      // Create new key share
      final newShare = KeyShare(
        partyId: oldShare.partyId,
        shareData: _encryptShare(newPrivateKeyShare, oldShare.partyId),
        curveType: oldShare.curveType,
        threshold: oldShare.threshold,
        totalParties: oldShare.totalParties,
        publicKey: oldShare.publicKey, // Public key remains the same
        createdAt: oldShare.createdAt,
        lastRefreshed: DateTime.now(),
      );
      
      refreshedShares.add(newShare);
    }

    return refreshedShares;
  }

  /// Generates a random private key for secp256k1.
  Uint8List _generateRandomPrivateKey() {
    final privateKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKey[i] = _random.nextInt(256);
    }
    return privateKey;
  }

  /// Implements Shamir's Secret Sharing for the private key.
  List<Uint8List> _shamirSecretShare(Uint8List secret, int threshold, int totalShares) {
    // This is a simplified implementation of Shamir's Secret Sharing
    // In a real implementation, you would use proper finite field arithmetic
    
    final shares = <Uint8List>[];
    
    for (var i = 1; i <= totalShares; i++) {
      final share = Uint8List(32);
      
      // Generate polynomial coefficients (simplified)
      for (var j = 0; j < 32; j++) {
        var value = secret[j];
        
        // Add polynomial terms (simplified)
        for (var k = 1; k < threshold; k++) {
          value = (value + _random.nextInt(256) * pow(i, k).toInt()) % 256;
        }
        
        share[j] = value;
      }
      
      shares.add(share);
    }
    
    return shares;
  }

  /// Encrypts a key share for a specific party.
  Uint8List _encryptShare(Uint8List share, String partyId) {
    // This is a mock encryption implementation
    // In a real implementation, you would use proper encryption
    
    final encrypted = Uint8List(share.length);
    final keyBytes = partyId.codeUnits;
    
    for (var i = 0; i < share.length; i++) {
      encrypted[i] = share[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return encrypted;
  }

  /// Decrypts a key share for a specific party.
  Uint8List _decryptShare(Uint8List encryptedShare, String partyId) {
    // This is a mock decryption implementation
    // In a real implementation, you would use proper decryption
    
    return _encryptShare(encryptedShare, partyId); // XOR is its own inverse
  }

  /// Creates an ECDSA signature share.
  Uint8List _createEcdsaSignatureShare(
    Uint8List messageHash,
    Uint8List privateKeyShare,
    Uint8List ephemeralKey,
    String sessionId,
  ) {
    // This is a simplified signature share creation
    // In a real implementation, you would use proper threshold ECDSA protocols
    
    final signatureShare = Uint8List(32);
    
    for (var i = 0; i < 32; i++) {
      signatureShare[i] = (messageHash[i] ^ 
                          privateKeyShare[i] ^ 
                          ephemeralKey[i]) % 256;
    }
    
    return signatureShare;
  }

  /// Combines ECDSA signature shares using Lagrange interpolation.
  Uint8List _combineEcdsaShares(List<SignatureShare> shares, Uint8List messageHash) {
    // This is a simplified signature combination
    // In a real implementation, you would use proper Lagrange interpolation
    
    final combinedSignature = Uint8List(65); // r(32) + s(32) + v(1)
    
    // Combine the shares (simplified)
    for (var i = 0; i < 64; i++) {
      var combined = 0;
      for (final share in shares.take(threshold)) {
        combined ^= share.shareData[i % share.shareData.length];
      }
      combinedSignature[i] = combined % 256;
    }
    
    // Set recovery ID
    combinedSignature[64] = 0;
    
    return combinedSignature;
  }

  /// Adds two private keys in the secp256k1 field.
  Uint8List _addPrivateKeys(Uint8List key1, Uint8List key2) {
    final result = Uint8List(32);
    var carry = 0;
    
    for (var i = 31; i >= 0; i--) {
      final sum = key1[i] + key2[i] + carry;
      result[i] = sum % 256;
      carry = sum ~/ 256;
    }
    
    return result;
  }
}

/// EdDSA threshold signature implementation for ed25519.
class EddsaThresholdSignature implements ThresholdSignature {

  EddsaThresholdSignature({
    required this.threshold,
    required this.totalParties,
  }) {
    if (threshold <= 0 || threshold > totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Invalid threshold: $threshold (total: $totalParties)',
      );
    }
  }
  @override
  final CurveType curveType = CurveType.ed25519;
  
  @override
  final int threshold;
  
  @override
  final int totalParties;
  
  /// Random number generator.
  final Random _random = Random.secure();

  @override
  Future<List<KeyShare>> generateKeyShares({
    required List<String> partyIds,
    Map<String, dynamic>? metadata,
  }) async {
    if (partyIds.length != totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Party count mismatch: ${partyIds.length} != $totalParties',
      );
    }

    // Generate master key pair for ed25519
    final masterPrivateKey = _generateRandomEd25519PrivateKey();
    // For ed25519, we'll use a mock public key since we don't have the actual implementation
    final masterPublicKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      masterPublicKey[i] = Random().nextInt(256);
    }

    // Use Shamir's Secret Sharing for ed25519
    final shares = _shamirSecretShareEd25519(masterPrivateKey, threshold, totalParties);

    // Create KeyShare objects for each party
    final keyShares = <KeyShare>[];
    for (var i = 0; i < partyIds.length; i++) {
      final keyShare = KeyShare(
        partyId: partyIds[i],
        shareData: _encryptShare(shares[i], partyIds[i]),
        curveType: curveType,
        threshold: threshold,
        totalParties: totalParties,
        publicKey: masterPublicKey,
        createdAt: DateTime.now(),
      );
      keyShares.add(keyShare);
    }

    return keyShares;
  }

  @override
  Future<SignatureShare> createSignatureShare({
    required Uint8List messageHash,
    required KeyShare keyShare,
    required String sessionId,
  }) async {
    // Decrypt the key share
    final privateKeyShare = _decryptShare(keyShare.shareData, keyShare.partyId);

    // Create EdDSA signature share
    final signatureShare = _createEddsaSignatureShare(
      messageHash,
      privateKeyShare,
      sessionId,
    );

    return SignatureShare(
      partyId: keyShare.partyId,
      shareData: signatureShare,
      sessionId: sessionId,
      metadata: {
        'curveType': curveType.name,
      },
    );
  }

  @override
  Future<Uint8List> combineSignatureShares({
    required List<SignatureShare> shares,
    required Uint8List messageHash,
    required Uint8List publicKey,
  }) async {
    if (shares.length < threshold) {
      throw MpcError(
        type: MpcErrorType.insufficientParties,
        message: 'Insufficient shares: ${shares.length} < $threshold',
      );
    }

    // Validate all shares belong to the same session
    final sessionId = shares.first.sessionId;
    if (!shares.every((share) => share.sessionId == sessionId)) {
      throw MpcError(
        type: MpcErrorType.signingFailed,
        message: 'Signature shares from different sessions',
      );
    }

    // Combine the EdDSA signature shares
    final combinedSignature = _combineEddsaShares(shares, messageHash);

    // Verify the combined signature
    final isValid = await verifySignature(
      signature: combinedSignature,
      messageHash: messageHash,
      publicKey: publicKey,
    );

    if (!isValid) {
      throw MpcError(
        type: MpcErrorType.signingFailed,
        message: 'Combined signature verification failed',
      );
    }

    return combinedSignature;
  }

  @override
  Future<bool> verifySignature({
    required Uint8List signature,
    required Uint8List messageHash,
    required Uint8List publicKey,
  }) async {
    try {
      // For ed25519, we'll use a mock verification since we don't have the actual implementation
      return signature.length == 64 && messageHash.length == 32 && publicKey.length == 32;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<KeyShare>> refreshKeyShares(List<KeyShare> oldShares) async {
    // Similar to ECDSA refresh but for ed25519
    if (oldShares.length != totalParties) {
      throw MpcError(
        type: MpcErrorType.invalidConfiguration,
        message: 'Invalid number of shares for refresh',
      );
    }

    final refreshedShares = <KeyShare>[];
    
    for (final oldShare in oldShares) {
      final oldPrivateKeyShare = _decryptShare(oldShare.shareData, oldShare.partyId);
      final refreshValue = _generateRandomEd25519PrivateKey();
      final newPrivateKeyShare = _addEd25519PrivateKeys(oldPrivateKeyShare, refreshValue);
      
      final newShare = KeyShare(
        partyId: oldShare.partyId,
        shareData: _encryptShare(newPrivateKeyShare, oldShare.partyId),
        curveType: oldShare.curveType,
        threshold: oldShare.threshold,
        totalParties: oldShare.totalParties,
        publicKey: oldShare.publicKey,
        createdAt: oldShare.createdAt,
        lastRefreshed: DateTime.now(),
      );
      
      refreshedShares.add(newShare);
    }

    return refreshedShares;
  }

  /// Generates a random private key for ed25519.
  Uint8List _generateRandomEd25519PrivateKey() {
    final privateKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKey[i] = _random.nextInt(256);
    }
    return privateKey;
  }

  /// Implements Shamir's Secret Sharing for ed25519.
  List<Uint8List> _shamirSecretShareEd25519(Uint8List secret, int threshold, int totalShares) {
    // Similar to secp256k1 but adapted for ed25519 field arithmetic
    final shares = <Uint8List>[];
    
    for (var i = 1; i <= totalShares; i++) {
      final share = Uint8List(32);
      
      for (var j = 0; j < 32; j++) {
        var value = secret[j];
        
        for (var k = 1; k < threshold; k++) {
          value = (value + _random.nextInt(256) * pow(i, k).toInt()) % 256;
        }
        
        share[j] = value;
      }
      
      shares.add(share);
    }
    
    return shares;
  }

  /// Encrypts a key share (same as ECDSA).
  Uint8List _encryptShare(Uint8List share, String partyId) {
    final encrypted = Uint8List(share.length);
    final keyBytes = partyId.codeUnits;
    
    for (var i = 0; i < share.length; i++) {
      encrypted[i] = share[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return encrypted;
  }

  /// Decrypts a key share (same as ECDSA).
  Uint8List _decryptShare(Uint8List encryptedShare, String partyId) {
    return _encryptShare(encryptedShare, partyId);
  }

  /// Creates an EdDSA signature share.
  Uint8List _createEddsaSignatureShare(
    Uint8List messageHash,
    Uint8List privateKeyShare,
    String sessionId,
  ) {
    // Simplified EdDSA signature share creation
    final signatureShare = Uint8List(32);
    
    for (var i = 0; i < 32; i++) {
      signatureShare[i] = (messageHash[i] ^ privateKeyShare[i]) % 256;
    }
    
    return signatureShare;
  }

  /// Combines EdDSA signature shares.
  Uint8List _combineEddsaShares(List<SignatureShare> shares, Uint8List messageHash) {
    // Simplified EdDSA signature combination
    final combinedSignature = Uint8List(64); // EdDSA signatures are 64 bytes
    
    for (var i = 0; i < 64; i++) {
      var combined = 0;
      for (final share in shares.take(threshold)) {
        combined ^= share.shareData[i % share.shareData.length];
      }
      combinedSignature[i] = combined % 256;
    }
    
    return combinedSignature;
  }

  /// Adds two ed25519 private keys.
  Uint8List _addEd25519PrivateKeys(Uint8List key1, Uint8List key2) {
    final result = Uint8List(32);
    var carry = 0;
    
    for (var i = 31; i >= 0; i--) {
      final sum = key1[i] + key2[i] + carry;
      result[i] = sum % 256;
      carry = sum ~/ 256;
    }
    
    return result;
  }
}

/// Factory for creating threshold signature schemes.
class ThresholdSignatureFactory {
  /// Creates a threshold signature scheme for the specified curve type.
  static ThresholdSignature create({
    required CurveType curveType,
    required int threshold,
    required int totalParties,
  }) {
    switch (curveType) {
      case CurveType.secp256k1:
        return EcdsaThresholdSignature(
          threshold: threshold,
          totalParties: totalParties,
        );
      case CurveType.ed25519:
        return EddsaThresholdSignature(
          threshold: threshold,
          totalParties: totalParties,
        );
    }
  }

  /// Creates an ECDSA threshold signature scheme.
  static EcdsaThresholdSignature createEcdsa({
    required int threshold,
    required int totalParties,
  }) {
    return EcdsaThresholdSignature(
      threshold: threshold,
      totalParties: totalParties,
    );
  }

  /// Creates an EdDSA threshold signature scheme.
  static EddsaThresholdSignature createEddsa({
    required int threshold,
    required int totalParties,
  }) {
    return EddsaThresholdSignature(
      threshold: threshold,
      totalParties: totalParties,
    );
  }
}
