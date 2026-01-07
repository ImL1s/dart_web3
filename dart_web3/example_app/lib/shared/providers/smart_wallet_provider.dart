import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wallet_provider.dart';

/// Smart Wallet state for Account Abstraction features.
///
/// This is a simplified demo state. Full AA integration requires:
/// - BundlerClient with proper RPC endpoints
/// - Paymaster integration for sponsored transactions
/// - Proper gas estimation
class SmartWalletState {
  const SmartWalletState({
    this.smartAccountAddress,
    this.isDeployed = false,
    this.isLoading = false,
    this.error,
    this.pendingUserOpHash,
    this.lastTxHash,
  });

  final String? smartAccountAddress;
  final bool isDeployed;
  final bool isLoading;
  final String? error;
  final String? pendingUserOpHash;
  final String? lastTxHash;

  SmartWalletState copyWith({
    String? smartAccountAddress,
    bool? isDeployed,
    bool? isLoading,
    String? error,
    String? pendingUserOpHash,
    String? lastTxHash,
  }) {
    return SmartWalletState(
      smartAccountAddress: smartAccountAddress ?? this.smartAccountAddress,
      isDeployed: isDeployed ?? this.isDeployed,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingUserOpHash: pendingUserOpHash ?? this.pendingUserOpHash,
      lastTxHash: lastTxHash ?? this.lastTxHash,
    );
  }
}

/// Smart Wallet provider notifier.
///
/// This is a demo implementation. For production, integrate with:
/// - `web3_universal_aa` package for full ERC-4337 support
/// - A bundler service (Stackup, Pimlico, Alchemy)
/// - Paymaster for gas sponsorship
class SmartWalletNotifier extends StateNotifier<SmartWalletState> {
  SmartWalletNotifier(this._ref) : super(const SmartWalletState());

  final Ref _ref;

  // SimpleAccountFactory on Sepolia
  static const _factoryAddress = '0x9406Cc6185a346906296840746125a0E44976454';

  /// Initialize smart account from current wallet.
  ///
  /// Calculates the counterfactual Smart Account address based on the owner's EOA.
  Future<void> initializeSmartAccount() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final walletState = _ref.read(walletProvider);
      final account = walletState.selectedAccount;

      if (account == null) {
        throw Exception('No wallet account available');
      }

      // Calculate counterfactual Smart Account address
      // In production, use CREATE2 calculation from web3_universal_aa
      final eoaAddress = account.address;
      final smartAccountAddress = _calculateSmartAccountAddress(eoaAddress);

      state = state.copyWith(
        smartAccountAddress: smartAccountAddress,
        isDeployed: false, // Assume not deployed initially
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Calculate counterfactual Smart Account address.
  ///
  /// This is a simplified demo. For production, use proper CREATE2 calculation.
  String _calculateSmartAccountAddress(String ownerAddress) {
    // Demo: Generate a deterministic address based on owner
    // Real implementation uses CREATE2 with factory, salt, and initCode
    final cleanAddress = ownerAddress.toLowerCase().replaceFirst('0x', '');
    
    // Simple hash-like transformation for demo purposes
    final bytes = <int>[];
    for (var i = 0; i < cleanAddress.length; i += 2) {
      bytes.add(int.parse(cleanAddress.substring(i, i + 2), radix: 16));
    }
    
    // XOR with factory address bytes for differentiation
    final factoryBytes = _factoryAddress.replaceFirst('0x', '');
    for (var i = 0; i < bytes.length && i * 2 < factoryBytes.length; i++) {
      bytes[i] ^= int.parse(factoryBytes.substring(i * 2, i * 2 + 2), radix: 16);
    }
    
    final result = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$result';
  }

  /// Simulate sending a UserOperation.
  ///
  /// In production, this would:
  /// 1. Build UserOperation
  /// 2. Estimate gas via bundler
  /// 3. Sign with owner's private key
  /// 4. Submit to bundler
  Future<String?> sendUserOperation({
    required String to,
    required BigInt value,
    String data = '0x',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate UserOperation submission
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate mock UserOp hash
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mockHash = '0x${timestamp.toRadixString(16).padLeft(64, '0')}';

      state = state.copyWith(
        isLoading: false,
        pendingUserOpHash: mockHash,
      );

      return mockHash;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Refresh deployment status.
  Future<void> refreshDeploymentStatus() async {
    // In production, check on-chain if the smart account has code
    // For demo, keep as not deployed
    state = state.copyWith(isDeployed: false);
  }
}

/// Smart Wallet provider.
final smartWalletProvider =
    StateNotifierProvider<SmartWalletNotifier, SmartWalletState>((ref) {
  return SmartWalletNotifier(ref);
});
