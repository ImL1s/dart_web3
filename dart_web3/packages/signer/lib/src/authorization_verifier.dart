import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import 'authorization.dart';

/// Utility class for verifying EIP-7702 authorizations.
class AuthorizationVerifier {
  /// Verifies a single authorization.
  ///
  /// Returns true if the authorization signature is valid for the expected signer.
  static bool verifyAuthorization(
      Authorization authorization, String expectedSigner) {
    return authorization.verifySignature(expectedSigner);
  }

  /// Verifies a list of authorizations.
  ///
  /// Returns a map where keys are authorization indices and values indicate
  /// whether each authorization is valid.
  static Map<int, bool> verifyAuthorizationList(
    List<Authorization> authorizations,
    List<String> expectedSigners,
  ) {
    if (authorizations.length != expectedSigners.length) {
      throw ArgumentError(
          'Authorization list and signer list must have the same length');
    }

    final results = <int, bool>{};
    for (var i = 0; i < authorizations.length; i++) {
      results[i] = verifyAuthorization(authorizations[i], expectedSigners[i]);
    }
    return results;
  }

  /// Verifies that all authorizations in a list are valid.
  ///
  /// Returns true only if all authorizations are valid.
  static bool verifyAllAuthorizations(
    List<Authorization> authorizations,
    List<String> expectedSigners,
  ) {
    final results = verifyAuthorizationList(authorizations, expectedSigners);
    return results.values.every((isValid) => isValid);
  }

  /// Checks if an authorization is properly formatted.
  ///
  /// Validates:
  /// - Chain ID is positive
  /// - Address is a valid Ethereum address
  /// - Nonce is non-negative
  /// - If signed, signature components are valid
  static bool isValidAuthorizationFormat(Authorization authorization) {
    try {
      // Check chain ID
      if (authorization.chainId <= 0) return false;

      // Check address format
      if (!_isValidEthereumAddress(authorization.address)) return false;

      // Check nonce
      if (authorization.nonce < BigInt.zero) return false;

      // If signed, check signature components
      if (authorization.isSigned) {
        // Check y-parity is 0 or 1
        if (authorization.yParity != 0 && authorization.yParity != 1)
          return false;

        // Check r and s are not zero (both zero means unsigned)
        if (authorization.r == BigInt.zero && authorization.s == BigInt.zero)
          return false;

        // Check r and s are in valid range (less than secp256k1 order)
        final secp256k1Order = BigInt.parse(
          'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
          radix: 16,
        );
        if (authorization.r >= secp256k1Order ||
            authorization.s >= secp256k1Order) return false;
      }

      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Validates a list of authorizations for format correctness.
  ///
  /// Returns a map where keys are authorization indices and values indicate
  /// whether each authorization has valid format.
  static Map<int, bool> validateAuthorizationListFormat(
      List<Authorization> authorizations) {
    final results = <int, bool>{};
    for (var i = 0; i < authorizations.length; i++) {
      results[i] = isValidAuthorizationFormat(authorizations[i]);
    }
    return results;
  }

  /// Checks if all authorizations in a list have valid format.
  static bool isValidAuthorizationListFormat(
      List<Authorization> authorizations) {
    return authorizations.every(isValidAuthorizationFormat);
  }

  /// Recovers the signer address from an authorization signature.
  ///
  /// Returns null if the signature is invalid or the authorization is unsigned.
  static String? recoverSigner(Authorization authorization) {
    if (!authorization.isSigned) return null;

    try {
      final messageHash = authorization.getMessageHash();

      // Reconstruct signature
      final rBytes = BytesUtils.bigIntToBytes(authorization.r, length: 32);
      final sBytes = BytesUtils.bigIntToBytes(authorization.s, length: 32);
      final signature = BytesUtils.concat([rBytes, sBytes]);

      // Recover public key using the yParity as recovery parameter
      final recoveredPublicKey =
          Secp256k1.recover(signature, messageHash, authorization.yParity);

      // Derive address from public key
      final recoveredAddress =
          EthereumAddress.fromPublicKey(recoveredPublicKey, Keccak256.hash);

      return recoveredAddress.toString();
    } on Exception catch (_) {
      return null;
    }
  }

  // Helper method to validate Ethereum address format
  static bool _isValidEthereumAddress(String address) {
    if (!address.startsWith('0x')) return false;
    if (address.length != 42) return false;

    final hex = address.substring(2);
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  /// Recovers signer addresses from a list of authorizations.
  ///
  /// Returns a map where keys are authorization indices and values are
  /// the recovered signer addresses (null if recovery failed).
  static Map<int, String?> recoverSigners(List<Authorization> authorizations) {
    final results = <int, String?>{};
    for (var i = 0; i < authorizations.length; i++) {
      results[i] = recoverSigner(authorizations[i]);
    }
    return results;
  }
}
