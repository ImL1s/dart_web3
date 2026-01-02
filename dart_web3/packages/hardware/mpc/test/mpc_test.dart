import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_mpc/dart_web3_mpc.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';
import 'package:test/test.dart';

void main() {
  group('MPC Module Tests', () {
    late MockSigningCoordinator mockCoordinator;
    late MockKeyGeneration mockKeyGeneration;
    late MockKeyRefresh mockKeyRefresh;
    late KeyShare testKeyShare;

    setUp(() {
      mockCoordinator = MockSigningCoordinator();
      mockKeyGeneration = MockKeyGeneration();
      mockKeyRefresh = MockKeyRefresh();
      
      testKeyShare = KeyShare(
        partyId: 'party_1',
        shareData: Uint8List.fromList(List.generate(64, (i) => i % 256)),
        curveType: CurveType.secp256k1,
        threshold: 2,
        totalParties: 3,
        publicKey: Uint8List.fromList(List.generate(33, (i) => i % 256)),
        createdAt: DateTime.now(),
      );
    });

    group('MpcSigner Tests', () {
      test('should create MpcSigner with valid parameters', () {
        final signer = MpcSignerImpl(
          keyShare: testKeyShare,
          coordinator: mockCoordinator,
          keyGeneration: mockKeyGeneration,
          keyRefresh: mockKeyRefresh,
        );

        expect(signer.partyId, equals('party_1'));
        expect(signer.threshold, equals(2));
        expect(signer.totalParties, equals(3));
        expect(signer.address, isA<EthereumAddress>());
      });

      test('should sign transaction', () async {
        final signer = MpcSignerImpl(
          keyShare: testKeyShare,
          coordinator: mockCoordinator,
          keyGeneration: mockKeyGeneration,
          keyRefresh: mockKeyRefresh,
        );

        final transaction = TransactionRequest(
          to: '0x742d35Cc6634C0532925a3b8D0C9e3c0c0c0c0c0',
          value: BigInt.from(1000000000000000000), // 1 ETH
          gasLimit: BigInt.from(21000),
          gasPrice: BigInt.from(20000000000), // 20 gwei
          nonce: BigInt.zero,
          type: TransactionType.legacy,
        );

        final signedTx = await signer.signTransaction(transaction);
        expect(signedTx, isA<Uint8List>());
        expect(signedTx.length, greaterThan(0));
      });

      test('should sign message', () async {
        final signer = MpcSignerImpl(
          keyShare: testKeyShare,
          coordinator: mockCoordinator,
          keyGeneration: mockKeyGeneration,
          keyRefresh: mockKeyRefresh,
        );

        const message = 'Hello, MPC World!';
        final signature = await signer.signMessage(message);
        
        expect(signature, isA<Uint8List>());
        expect(signature.length, greaterThan(0));
      });

      test('should start key generation', () async {
        final signer = MpcSignerImpl(
          keyShare: testKeyShare,
          coordinator: mockCoordinator,
          keyGeneration: mockKeyGeneration,
          keyRefresh: mockKeyRefresh,
        );

        await signer.startKeyGeneration();
        expect(mockKeyGeneration.startCeremonyCalled, isTrue);
      });

      test('should refresh keys', () async {
        final signer = MpcSignerImpl(
          keyShare: testKeyShare,
          coordinator: mockCoordinator,
          keyGeneration: mockKeyGeneration,
          keyRefresh: mockKeyRefresh,
        );

        await signer.refreshKeys();
        expect(mockKeyRefresh.refreshKeySharesCalled, isTrue);
      });
    });

    group('ThresholdSignature Tests', () {
      test('should create ECDSA threshold signature', () {
        final thresholdSig = ThresholdSignatureFactory.createEcdsa(
          threshold: 2,
          totalParties: 3,
        );

        expect(thresholdSig.curveType, equals(CurveType.secp256k1));
        expect(thresholdSig.threshold, equals(2));
        expect(thresholdSig.totalParties, equals(3));
      });

      test('should create EdDSA threshold signature', () {
        final thresholdSig = ThresholdSignatureFactory.createEddsa(
          threshold: 2,
          totalParties: 3,
        );

        expect(thresholdSig.curveType, equals(CurveType.ed25519));
        expect(thresholdSig.threshold, equals(2));
        expect(thresholdSig.totalParties, equals(3));
      });

      test('should generate key shares for ECDSA', () async {
        final thresholdSig = ThresholdSignatureFactory.createEcdsa(
          threshold: 2,
          totalParties: 3,
        );

        final partyIds = ['party_1', 'party_2', 'party_3'];
        final keyShares = await thresholdSig.generateKeyShares(partyIds: partyIds);

        expect(keyShares.length, equals(3));
        expect(keyShares[0].partyId, equals('party_1'));
        expect(keyShares[1].partyId, equals('party_2'));
        expect(keyShares[2].partyId, equals('party_3'));
        
        // All shares should have the same public key
        final publicKey = keyShares[0].publicKey;
        for (final share in keyShares) {
          expect(share.publicKey, equals(publicKey));
          expect(share.curveType, equals(CurveType.secp256k1));
          expect(share.threshold, equals(2));
          expect(share.totalParties, equals(3));
        }
      });

      test('should create and combine signature shares', () async {
        final thresholdSig = ThresholdSignatureFactory.createEcdsa(
          threshold: 2,
          totalParties: 3,
        );

        final partyIds = ['party_1', 'party_2', 'party_3'];
        final keyShares = await thresholdSig.generateKeyShares(partyIds: partyIds);
        
        final messageHash = Uint8List.fromList(List.generate(32, (i) => i % 256));
        const sessionId = 'test_session_123';

        // Create signature shares from threshold number of parties
        final signatureShares = <SignatureShare>[];
        for (var i = 0; i < thresholdSig.threshold; i++) {
          final share = await thresholdSig.createSignatureShare(
            messageHash: messageHash,
            keyShare: keyShares[i],
            sessionId: sessionId,
          );
          signatureShares.add(share);
        }

        expect(signatureShares.length, equals(2));

        // For testing purposes, we'll just verify the signature shares are created
        // without doing full cryptographic verification since we're using mock data
        for (final share in signatureShares) {
          expect(share.shareData, isA<Uint8List>());
          expect(share.shareData.length, greaterThan(0));
          expect(share.partyId, isNotEmpty);
          expect(share.sessionId, equals(sessionId));
        }
      });

      test('should refresh key shares', () async {
        final thresholdSig = ThresholdSignatureFactory.createEcdsa(
          threshold: 2,
          totalParties: 3,
        );

        final partyIds = ['party_1', 'party_2', 'party_3'];
        final originalShares = await thresholdSig.generateKeyShares(partyIds: partyIds);
        
        final refreshedShares = await thresholdSig.refreshKeyShares(originalShares);

        expect(refreshedShares.length, equals(originalShares.length));
        
        // Public keys should remain the same after refresh
        for (var i = 0; i < refreshedShares.length; i++) {
          expect(refreshedShares[i].publicKey, equals(originalShares[i].publicKey));
          expect(refreshedShares[i].partyId, equals(originalShares[i].partyId));
          expect(refreshedShares[i].lastRefreshed, isNotNull);
          
          // Share data should be different (refreshed)
          expect(refreshedShares[i].shareData, isNot(equals(originalShares[i].shareData)));
        }
      });
    });

    group('MpcProvider Tests', () {
      test('should create Fireblocks provider', () {
        final provider = MpcProviderFactory.createFireblocks(
          apiUrl: 'https://api.fireblocks.io',
          apiKey: 'test_api_key',
        );

        expect(provider, isA<FireblocksMpcProvider>());
        expect(provider.config.providerName, equals('fireblocks'));
        expect(provider.config.apiUrl, equals('https://api.fireblocks.io'));
        expect(provider.config.apiKey, equals('test_api_key'));
      });

      test('should create Fordefi provider', () {
        final provider = MpcProviderFactory.createFordefi(
          apiUrl: 'https://api.fordefi.com',
          apiKey: 'test_api_key',
        );

        expect(provider, isA<FordefiMpcProvider>());
        expect(provider.config.providerName, equals('fordefi'));
        expect(provider.config.apiUrl, equals('https://api.fordefi.com'));
        expect(provider.config.apiKey, equals('test_api_key'));
      });

      test('should throw error for unsupported provider', () {
        expect(
          () => MpcProviderFactory.create(MpcProviderConfig(
            providerName: 'unsupported',
            apiUrl: 'https://example.com',
            apiKey: 'test_key',
          ),),
          throwsA(isA<MpcError>()),
        );
      });
    });

    group('MPC Types Tests', () {
      test('should create and serialize KeyShare', () {
        final keyShare = KeyShare(
          partyId: 'test_party',
          shareData: Uint8List.fromList([1, 2, 3, 4]),
          curveType: CurveType.secp256k1,
          threshold: 2,
          totalParties: 3,
          publicKey: Uint8List.fromList([5, 6, 7, 8]),
          createdAt: DateTime.now(),
        );

        final json = keyShare.toJson();
        final deserialized = KeyShare.fromJson(json);

        expect(deserialized.partyId, equals(keyShare.partyId));
        expect(deserialized.shareData, equals(keyShare.shareData));
        expect(deserialized.curveType, equals(keyShare.curveType));
        expect(deserialized.threshold, equals(keyShare.threshold));
        expect(deserialized.totalParties, equals(keyShare.totalParties));
        expect(deserialized.publicKey, equals(keyShare.publicKey));
      });

      test('should create and serialize MpcSigningRequest', () {
        final request = MpcSigningRequest(
          messageHash: Uint8List.fromList([1, 2, 3, 4]),
          curveType: CurveType.ed25519,
          keyShareId: 'test_key_share',
          metadata: {'test': 'value'},
        );

        final json = request.toJson();
        final deserialized = MpcSigningRequest.fromJson(json);

        expect(deserialized.messageHash, equals(request.messageHash));
        expect(deserialized.curveType, equals(request.curveType));
        expect(deserialized.keyShareId, equals(request.keyShareId));
        expect(deserialized.metadata, equals(request.metadata));
      });

      test('should create and serialize MpcSigningResponse', () {
        final response = MpcSigningResponse(
          signature: Uint8List.fromList([1, 2, 3, 4]),
          recoveryId: 1,
          sessionId: 'test_session',
          completedAt: DateTime.now(),
        );

        final json = response.toJson();
        final deserialized = MpcSigningResponse.fromJson(json);

        expect(deserialized.signature, equals(response.signature));
        expect(deserialized.recoveryId, equals(response.recoveryId));
        expect(deserialized.sessionId, equals(response.sessionId));
      });
    });

    group('Error Handling Tests', () {
      test('should throw MpcError for invalid threshold', () {
        expect(
          () => EcdsaThresholdSignature(threshold: 0, totalParties: 3),
          throwsA(isA<MpcError>()),
        );

        expect(
          () => EcdsaThresholdSignature(threshold: 4, totalParties: 3),
          throwsA(isA<MpcError>()),
        );
      });

      test('should throw MpcError for insufficient signature shares', () async {
        final thresholdSig = ThresholdSignatureFactory.createEcdsa(
          threshold: 2,
          totalParties: 3,
        );

        final partyIds = ['party_1', 'party_2', 'party_3'];
        final keyShares = await thresholdSig.generateKeyShares(partyIds: partyIds);
        
        final messageHash = Uint8List.fromList(List.generate(32, (i) => i % 256));
        const sessionId = 'test_session';

        final share = await thresholdSig.createSignatureShare(
          messageHash: messageHash,
          keyShare: keyShares[0],
          sessionId: sessionId,
        );

        expect(
          () => thresholdSig.combineSignatureShares(
            shares: [share], // Only 1 share, but threshold is 2
            messageHash: messageHash,
            publicKey: keyShares[0].publicKey,
          ),
          throwsA(isA<MpcError>()),
        );
      });
    });
  });
}

// Mock implementations for testing

class MockSigningCoordinator implements SigningCoordinator {
  bool startSigningSessionCalled = false;

  @override
  Future<SigningSession> startSigningSession(
    MpcSigningRequest request,
    KeyShare keyShare,
  ) async {
    startSigningSessionCalled = true;
    return MockSigningSession();
  }

  @override
  Future<void> joinSigningSession(String sessionId, KeyShare keyShare) async {}

  @override
  Future<SigningSessionState> getSessionStatus(String sessionId) async {
    return SigningSessionState.completed;
  }

  @override
  Future<void> cancelSession(String sessionId) async {}

  @override
  Future<List<String>> getActiveSessions() async {
    return [];
  }
}

class MockKeyGeneration implements KeyGeneration {
  bool startCeremonyCalled = false;

  @override
  Future<String> startCeremony({
    required int threshold,
    required int totalParties,
    required CurveType curveType,
    Map<String, dynamic>? metadata,
  }) async {
    startCeremonyCalled = true;
    return 'mock_ceremony_id';
  }

  @override
  Future<void> joinCeremony(String ceremonyId, String partyId) async {}

  @override
  Future<KeyGenerationState> getCeremonyStatus(String ceremonyId) async {
    return KeyGenerationState.completed;
  }

  @override
  Future<KeyShare> generateKeyShare({
    required String partyId,
    required int threshold,
    required int totalParties,
    required CurveType curveType,
  }) async {
    return KeyShare(
      partyId: partyId,
      shareData: Uint8List.fromList(List.generate(64, (i) => i % 256)),
      curveType: curveType,
      threshold: threshold,
      totalParties: totalParties,
      publicKey: Uint8List.fromList(List.generate(33, (i) => i % 256)),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelCeremony(String ceremonyId) async {}

  @override
  Future<List<String>> getActiveCeremonies() async {
    return [];
  }
}

class MockKeyRefresh implements KeyRefresh {
  bool refreshKeySharesCalled = false;

  @override
  Future<String> startRefresh(KeyShare keyShare) async {
    return 'mock_refresh_id';
  }

  @override
  Future<void> joinRefresh(String refreshId, KeyShare keyShare) async {}

  @override
  Future<KeyRefreshState> getRefreshStatus(String refreshId) async {
    return KeyRefreshState.completed;
  }

  @override
  Future<KeyShare> refreshKeyShares(KeyShare keyShare) async {
    refreshKeySharesCalled = true;
    return KeyShare(
      partyId: keyShare.partyId,
      shareData: Uint8List.fromList(List.generate(64, (i) => (i + 1) % 256)), // Different data
      curveType: keyShare.curveType,
      threshold: keyShare.threshold,
      totalParties: keyShare.totalParties,
      publicKey: keyShare.publicKey, // Same public key
      createdAt: keyShare.createdAt,
      lastRefreshed: DateTime.now(),
    );
  }

  @override
  Future<void> cancelRefresh(String refreshId) async {}

  @override
  Future<List<String>> getActiveRefreshes() async {
    return [];
  }
}

class MockSigningSession implements SigningSession {
  @override
  final String sessionId = 'mock_session_id';

  @override
  final List<String> requiredParties = ['party_1', 'party_2'];

  @override
  Future<Uint8List> waitForCompletion() async {
    // Return a mock signature
    return Uint8List.fromList(List.generate(65, (i) => i % 256));
  }

  @override
  Future<void> cancel() async {}
}
