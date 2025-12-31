import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

void main() {
  group('EIP-7702 Authorization Tests', () {
    late Uint8List privateKey;
    late PrivateKeySigner signer;
    late String contractAddress;
    
    setUp(() {
      privateKey = _generateValidPrivateKey();
      signer = PrivateKeySigner(privateKey, 1);
      contractAddress = '0x' + List.generate(40, (_) => Random().nextInt(16).toRadixString(16)).join();
    });

    group('Authorization Creation', () {
      test('should create unsigned authorization', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        expect(auth.chainId, equals(1));
        expect(auth.address, equals(contractAddress));
        expect(auth.nonce, equals(BigInt.from(42)));
        expect(auth.isSigned, isFalse);
        expect(auth.isRevocation, isFalse);
      });

      test('should create revocation authorization', () {
        final revocation = Authorization.revocation(
          chainId: 1,
          nonce: BigInt.from(42),
        );

        expect(revocation.chainId, equals(1));
        expect(revocation.address, equals('0x${'0' * 40}'));
        expect(revocation.nonce, equals(BigInt.from(42)));
        expect(revocation.isSigned, isFalse);
        expect(revocation.isRevocation, isTrue);
      });

      test('should create authorization from JSON', () {
        final json = {
          'chainId': 1,
          'address': contractAddress,
          'nonce': '0x2a',
          'yParity': 1,
          'r': '0x123',
          's': '0x456',
        };

        final auth = Authorization.fromJson(json);

        expect(auth.chainId, equals(1));
        expect(auth.address, equals(contractAddress));
        expect(auth.nonce, equals(BigInt.from(42)));
        expect(auth.yParity, equals(1));
        expect(auth.r, equals(BigInt.from(0x123)));
        expect(auth.s, equals(BigInt.from(0x456)));
        expect(auth.isSigned, isTrue);
      });
    });

    group('Authorization Signing', () {
      test('should sign authorization with private key', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);

        expect(signedAuth.isSigned, isTrue);
        expect(signedAuth.chainId, equals(auth.chainId));
        expect(signedAuth.address, equals(auth.address));
        expect(signedAuth.nonce, equals(auth.nonce));
        expect(signedAuth.r, isNot(equals(BigInt.zero)));
        expect(signedAuth.s, isNot(equals(BigInt.zero)));
      });

      test('should sign authorization with signer', () async {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signature = await signer.signAuthorization(auth);

        expect(signature, isNotNull);
        expect(signature.length, equals(64)); // 32 + 32 bytes (r + s)
      });

      test('should produce consistent signatures for same input', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth1 = auth.sign(privateKey);
        final signedAuth2 = auth.sign(privateKey);

        // The signatures might not be identical due to random k generation,
        // but they should both be valid for the same signer
        expect(signedAuth1.verifySignature(signer.address.hex), isTrue);
        expect(signedAuth2.verifySignature(signer.address.hex), isTrue);
        
        // Both should have the same authorization data
        expect(signedAuth1.chainId, equals(signedAuth2.chainId));
        expect(signedAuth1.address, equals(signedAuth2.address));
        expect(signedAuth1.nonce, equals(signedAuth2.nonce));
      });
    });

    group('Authorization Verification', () {
      test('should verify valid authorization signature', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);
        final isValid = signedAuth.verifySignature(signer.address.hex);

        expect(isValid, isTrue);
      });

      test('should reject invalid authorization signature', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);
        final wrongAddress = '0x' + List.generate(40, (_) => Random().nextInt(16).toRadixString(16)).join();
        final isValid = signedAuth.verifySignature(wrongAddress);

        expect(isValid, isFalse);
      });

      test('should reject unsigned authorization', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final isValid = auth.verifySignature(signer.address.hex);

        expect(isValid, isFalse);
      });
    });

    group('Authorization Verifier', () {
      test('should verify single authorization', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);
        final isValid = AuthorizationVerifier.verifyAuthorization(signedAuth, signer.address.hex);

        expect(isValid, isTrue);
      });

      test('should verify authorization list', () {
        final auths = [
          Authorization.unsigned(chainId: 1, address: contractAddress, nonce: BigInt.from(1)),
          Authorization.unsigned(chainId: 1, address: contractAddress, nonce: BigInt.from(2)),
        ];

        final signedAuths = auths.map((auth) => auth.sign(privateKey)).toList();
        final signers = [signer.address.hex, signer.address.hex];

        final results = AuthorizationVerifier.verifyAuthorizationList(signedAuths, signers);

        expect(results[0], isTrue);
        expect(results[1], isTrue);
      });

      test('should validate authorization format', () {
        final validAuth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final invalidAuth = Authorization(
          chainId: -1, // Invalid chain ID
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        expect(AuthorizationVerifier.isValidAuthorizationFormat(validAuth), isTrue);
        expect(AuthorizationVerifier.isValidAuthorizationFormat(invalidAuth), isFalse);
      });

      test('should recover signer address', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);
        final recoveredAddress = AuthorizationVerifier.recoverSigner(signedAuth);

        expect(recoveredAddress?.toLowerCase(), equals(signer.address.hex.toLowerCase()));
      });
    });

    group('Authorization Batch', () {
      test('should create batch for multiple contracts', () {
        final contracts = [contractAddress, contractAddress.replaceFirst('1', '2')];
        final batch = AuthorizationBatch.forContracts(
          chainId: 1,
          contractAddresses: contracts,
          startingNonce: BigInt.from(10),
        );

        expect(batch.length, equals(2));
        expect(batch.authorizations[0].address, equals(contracts[0]));
        expect(batch.authorizations[1].address, equals(contracts[1]));
        expect(batch.authorizations[0].nonce, equals(BigInt.from(10)));
        expect(batch.authorizations[1].nonce, equals(BigInt.from(11)));
      });

      test('should create revocation batch', () {
        final nonces = [BigInt.from(1), BigInt.from(2), BigInt.from(3)];
        final batch = AuthorizationBatch.revocations(
          chainId: 1,
          nonces: nonces,
        );

        expect(batch.length, equals(3));
        expect(batch.hasRevocations, isTrue);
        expect(batch.authorizations.every((auth) => auth.isRevocation), isTrue);
      });

      test('should sign all authorizations in batch', () {
        final batch = AuthorizationBatch.forContracts(
          chainId: 1,
          contractAddresses: [contractAddress],
          startingNonce: BigInt.from(1),
        );

        final signedBatch = batch.signAllWithPrivateKey(privateKey);

        expect(signedBatch.areAllSigned, isTrue);
        expect(signedBatch.length, equals(batch.length));
      });

      test('should estimate gas cost for batch', () {
        final batch = AuthorizationBatch.forContracts(
          chainId: 1,
          contractAddresses: [contractAddress, contractAddress.replaceFirst('1', '2')],
          startingNonce: BigInt.from(1),
        );

        final estimatedGas = batch.estimateGasCost();

        expect(estimatedGas, equals(BigInt.from(2 * 2300))); // 2 authorizations * 2300 gas each
      });

      test('should filter batch by chain ID', () {
        final batch = AuthorizationBatch();
        batch.add(Authorization.unsigned(chainId: 1, address: contractAddress, nonce: BigInt.from(1)));
        batch.add(Authorization.unsigned(chainId: 2, address: contractAddress, nonce: BigInt.from(2)));
        batch.add(Authorization.unsigned(chainId: 1, address: contractAddress, nonce: BigInt.from(3)));

        final filtered = batch.filterByChainId(1);

        expect(filtered.length, equals(2));
        expect(filtered.authorizations.every((auth) => auth.chainId == 1), isTrue);
      });
    });

    group('Authorization Revocation', () {
      test('should create single revocation', () {
        final revocation = AuthorizationRevocation.createRevocation(
          chainId: 1,
          nonce: BigInt.from(42),
        );

        expect(revocation.isRevocation, isTrue);
        expect(revocation.chainId, equals(1));
        expect(revocation.nonce, equals(BigInt.from(42)));
      });

      test('should create revocation batch', () {
        final nonces = [BigInt.from(1), BigInt.from(2)];
        final batch = AuthorizationRevocation.createRevocationBatch(
          chainId: 1,
          nonces: nonces,
        );

        expect(batch.length, equals(2));
        expect(batch.hasRevocations, isTrue);
      });

      test('should validate revocation', () {
        final validRevocation = AuthorizationRevocation.createRevocation(
          chainId: 1,
          nonce: BigInt.from(42),
        );

        final invalidRevocation = Authorization.unsigned(
          chainId: 1,
          address: contractAddress, // Not zero address
          nonce: BigInt.from(42),
        );

        expect(AuthorizationRevocation.isValidRevocation(validRevocation), isTrue);
        expect(AuthorizationRevocation.isValidRevocation(invalidRevocation), isFalse);
      });

      test('should undo delegation', () {
        final originalDelegation = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final undoRevocation = AuthorizationRevocation.undoDelegation(
          originalDelegation: originalDelegation,
        );

        expect(undoRevocation.isRevocation, isTrue);
        expect(undoRevocation.chainId, equals(originalDelegation.chainId));
        expect(undoRevocation.nonce, equals(originalDelegation.nonce));
      });

      test('should check zero address', () {
        expect(AuthorizationRevocation.isZeroAddress('0x${'0' * 40}'), isTrue);
        expect(AuthorizationRevocation.isZeroAddress(contractAddress), isFalse);
      });
    });

    group('RLP Encoding', () {
      test('should encode and decode authorization', () {
        final auth = Authorization.unsigned(
          chainId: 1,
          address: contractAddress,
          nonce: BigInt.from(42),
        );

        final signedAuth = auth.sign(privateKey);
        final rlpList = signedAuth.toRlpList();
        final decodedAuth = Authorization.fromRlpList(rlpList);

        expect(decodedAuth.chainId, equals(signedAuth.chainId));
        expect(decodedAuth.address, equals(signedAuth.address));
        expect(decodedAuth.nonce, equals(signedAuth.nonce));
        expect(decodedAuth.yParity, equals(signedAuth.yParity));
        expect(decodedAuth.r, equals(signedAuth.r));
        expect(decodedAuth.s, equals(signedAuth.s));
      });

      test('should encode and decode authorization batch', () {
        final batch = AuthorizationBatch.forContracts(
          chainId: 1,
          contractAddresses: [contractAddress],
          startingNonce: BigInt.from(1),
        );

        final signedBatch = batch.signAllWithPrivateKey(privateKey);
        final rlpList = signedBatch.toRlpList();
        final decodedBatch = AuthorizationBatch.fromRlpList(rlpList);

        expect(decodedBatch.length, equals(signedBatch.length));
        expect(decodedBatch.areAllSigned, isTrue);
      });
    });
  });
}

// Helper function to generate a valid private key
Uint8List _generateValidPrivateKey() {
  final random = Random.secure();
  final secp256k1Order = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
  
  while (true) {
    final privateKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    
    final privateKeyInt = _bytesToBigInt(privateKey);
    if (privateKeyInt < secp256k1Order && privateKeyInt != BigInt.zero) {
      return privateKey;
    }
  }
}

BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (int i = 0; i < bytes.length; i++) {
    result = (result << 8) + BigInt.from(bytes[i]);
  }
  return result;
}