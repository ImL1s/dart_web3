/// MPC providers implementation.
library;

import 'dart:async';
import 'dart:typed_data';

import 'mpc_types.dart';

/// Fireblocks MPC provider implementation.
class FireblocksMpcProvider implements MpcProvider {
  FireblocksMpcProvider({required this.config});
  @override
  final MpcProviderConfig config;

  @override
  Future<void> initialize() async {
    // Validate API credentials
    await _validateCredentials();
  }

  @override
  Future<String> createWallet({
    required String name,
    required int threshold,
    required int totalParties,
    required CurveType curveType,
    Map<String, dynamic>? metadata,
  }) async {
    // final requestBody = {
    //   'name': name,
    //   'algorithm': _curveTypeToAlgorithm(curveType),
    //   'threshold': threshold,
    //   'totalParties': totalParties,
    //   'metadata': metadata ?? {},
    // };

    // Simulate API call
    await Future<void>.delayed(const Duration(seconds: 1));

    // Return mock wallet ID
    return 'fb_wallet_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<MpcWalletInfo> getWallet(String walletId) async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Return mock wallet info
    return MpcWalletInfo(
      walletId: walletId,
      name: 'Fireblocks Wallet',
      curveType: CurveType.secp256k1,
      threshold: 2,
      totalParties: 3,
      publicKey: Uint8List(33), // Mock public key
      status: MpcWalletStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastActivity: DateTime.now(),
    );
  }

  @override
  Future<List<MpcWalletInfo>> listWallets() async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Return mock wallet list
    return [
      await getWallet('wallet_1'),
      await getWallet('wallet_2'),
    ];
  }

  @override
  Future<String> initiateSigningRequest(MpcSigningRequest request) async {
    // final requestBody = {
    //   'walletId': request.keyShareId,
    //   'messageHash': request.messageHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    //   'algorithm': _curveTypeToAlgorithm(request.curveType),
    //   'metadata': request.metadata,
    // };

    // Simulate API call
    await Future<void>.delayed(const Duration(seconds: 1));

    // Return mock request ID
    return 'fb_sign_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<MpcSigningStatus> getSigningStatus(String requestId) async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Return mock status
    return MpcSigningStatus.completed;
  }

  @override
  Future<MpcSigningResponse> getSigningResult(String requestId) async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Return mock signature
    final signature = Uint8List(65); // Mock signature
    return MpcSigningResponse(
      signature: signature,
      recoveryId: 0,
      sessionId: requestId,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelSigningRequest(String requestId) async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> refreshWalletKeys(String walletId) async {
    // Simulate API call
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  @override
  Future<void> dispose() async {
    // _httpClient.close();
  }

  /// Validates API credentials.
  Future<void> _validateCredentials() async {
    // Simulate API call
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  // String _curveTypeToAlgorithm(CurveType curveType) {
  //   switch (curveType) {
  //     case CurveType.secp256k1:
  //       return 'ECDSA_SECP256K1';
  //     case CurveType.ed25519:
  //       return 'EDDSA_ED25519';
  //   }
  // }
}

/// Fordefi MPC provider implementation.
class FordefiMpcProvider implements MpcProvider {
  FordefiMpcProvider({required this.config});
  @override
  final MpcProviderConfig config;

  @override
  Future<void> initialize() async {
    await _validateCredentials();
  }

  @override
  Future<String> createWallet({
    required String name,
    required int threshold,
    required int totalParties,
    required CurveType curveType,
    Map<String, dynamic>? metadata,
  }) async {
    // final requestBody = {
    //   'name': name,
    //   'curve': _curveTypeToCurve(curveType),
    //   'threshold': threshold,
    //   'parties': totalParties,
    //   'metadata': metadata ?? {},
    // };

    // Simulate API call
    await Future<void>.delayed(const Duration(seconds: 1));

    return 'fd_wallet_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<MpcWalletInfo> getWallet(String walletId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return MpcWalletInfo(
      walletId: walletId,
      name: 'Fordefi Wallet',
      curveType: CurveType.secp256k1,
      threshold: 2,
      totalParties: 3,
      publicKey: Uint8List(33),
      status: MpcWalletStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastActivity: DateTime.now(),
    );
  }

  @override
  Future<List<MpcWalletInfo>> listWallets() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return [
      await getWallet('wallet_1'),
      await getWallet('wallet_2'),
    ];
  }

  @override
  Future<String> initiateSigningRequest(MpcSigningRequest request) async {
    // final requestBody = {
    //   'vaultId': request.keyShareId,
    //   'message': request.messageHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    //   'curve': _curveTypeToCurve(request.curveType),
    //   'metadata': request.metadata,
    // };

    await Future<void>.delayed(const Duration(seconds: 1));

    return 'fd_sign_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<MpcSigningStatus> getSigningStatus(String requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MpcSigningStatus.completed;
  }

  @override
  Future<MpcSigningResponse> getSigningResult(String requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final signature = Uint8List(65);
    return MpcSigningResponse(
      signature: signature,
      recoveryId: 0,
      sessionId: requestId,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelSigningRequest(String requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> refreshWalletKeys(String walletId) async {
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  @override
  Future<void> dispose() async {
    // Cleanup resources
  }

  /// Validates API credentials.
  Future<void> _validateCredentials() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  // String _curveTypeToCurve(CurveType curveType) {
  //   switch (curveType) {
  //     case CurveType.secp256k1:
  //       return 'secp256k1';
  //     case CurveType.ed25519:
  //       return 'ed25519';
  //   }
  // }
}

/// Factory for creating MPC providers.
// ignore: avoid_classes_with_only_static_members
class MpcProviderFactory {
  MpcProviderFactory._();

  /// Creates a provider instance.
  static MpcProvider create(MpcProviderConfig config) {
    switch (config.providerName) {
      case 'fireblocks':
        return FireblocksMpcProvider(config: config);
      case 'fordefi':
        return FordefiMpcProvider(config: config);
      default:
        throw MpcError(
          type: MpcErrorType.invalidConfiguration,
          message: 'Unsupported provider: ${config.providerName}',
        );
    }
  }

  /// Creates a Fireblocks provider.
  static MpcProvider createFireblocks({
    required String apiUrl,
    required String apiKey,
    Map<String, dynamic>? additionalConfig,
  }) {
    return create(
      MpcProviderConfig(
        providerName: 'fireblocks',
        apiUrl: apiUrl,
        apiKey: apiKey,
        additionalConfig: additionalConfig ?? {},
      ),
    );
  }

  /// Creates a Fordefi provider.
  static MpcProvider createFordefi({
    required String apiUrl,
    required String apiKey,
    Map<String, dynamic>? additionalConfig,
  }) {
    return create(
      MpcProviderConfig(
        providerName: 'fordefi',
        apiUrl: apiUrl,
        apiKey: apiKey,
        additionalConfig: additionalConfig ?? {},
      ),
    );
  }
}
