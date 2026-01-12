import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wallet_provider.dart';

/// UserOperation execution steps.
enum UserOpStep {
  building,
  sponsoring,
  signing,
  bundling,
  completed,
}

/// Smart Wallet state for Account Abstraction features.
class SmartWalletState {
  const SmartWalletState({
    this.smartAccountAddress,
    this.isDeployed = false,
    this.isLoading = false,
    this.error,
    this.pendingUserOpHash,
    this.lastTxHash,
    this.paymasterEnabled = true, // Default to sponsored
    this.currentStep,
  });

  final String? smartAccountAddress;
  final bool isDeployed;
  final bool isLoading;
  final String? error;
  final String? pendingUserOpHash;
  final String? lastTxHash;
  final bool paymasterEnabled;
  final UserOpStep? currentStep;

  SmartWalletState copyWith({
    String? smartAccountAddress,
    bool? isDeployed,
    bool? isLoading,
    String? error,
    String? pendingUserOpHash,
    String? lastTxHash,
    bool? paymasterEnabled,
    UserOpStep? currentStep,
    bool clearError = false,
  }) {
    return SmartWalletState(
      smartAccountAddress: smartAccountAddress ?? this.smartAccountAddress,
      isDeployed: isDeployed ?? this.isDeployed,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingUserOpHash: pendingUserOpHash ?? this.pendingUserOpHash,
      lastTxHash: lastTxHash ?? this.lastTxHash,
      paymasterEnabled: paymasterEnabled ?? this.paymasterEnabled,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Smart Wallet provider notifier.
class SmartWalletNotifier extends StateNotifier<SmartWalletState> {
  SmartWalletNotifier(this._ref) : super(const SmartWalletState());

  final Ref _ref;

  // SimpleAccountFactory on Sepolia
  static const _factoryAddress = '0x9406Cc6185a346906296840746125a0E44976454';

  /// Toggle Paymaster sponsorship.
  void togglePaymaster(bool enabled) {
    state = state.copyWith(paymasterEnabled: enabled);
  }

  /// Initialize smart account from current wallet.
  Future<void> initializeSmartAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final walletState = _ref.read(walletProvider);
      final account = walletState.selectedAccount;

      if (account == null) {
        throw Exception('No wallet account available');
      }

      final eoaAddress = account.address;
      final smartAccountAddress = _calculateSmartAccountAddress(eoaAddress);

      state = state.copyWith(
        smartAccountAddress: smartAccountAddress,
        isDeployed: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  String _calculateSmartAccountAddress(String ownerAddress) {
    final cleanAddress = ownerAddress.toLowerCase().replaceFirst('0x', '');
    final bytes = <int>[];
    for (var i = 0; i < cleanAddress.length; i += 2) {
      bytes.add(int.parse(cleanAddress.substring(i, i + 2), radix: 16));
    }
    
    final factoryBytes = _factoryAddress.replaceFirst('0x', '');
    for (var i = 0; i < bytes.length && i * 2 < factoryBytes.length; i++) {
      bytes[i] ^= int.parse(factoryBytes.substring(i * 2, i * 2 + 2), radix: 16);
    }
    
    final result = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$result';
  }

  /// Simulate sending a UserOperation with step-by-step progress.
  Future<String?> sendUserOperation({
    required String to,
    required BigInt value,
    String data = '0x',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, currentStep: UserOpStep.building);

    try {
      // Step 1: Building
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Step 2: Sponsoring (if enabled)
      if (state.paymasterEnabled) {
        state = state.copyWith(currentStep: UserOpStep.sponsoring);
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Step 3: Signing
      state = state.copyWith(currentStep: UserOpStep.signing);
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 4: Bundling
      state = state.copyWith(currentStep: UserOpStep.bundling);
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate mock UserOp hash
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mockHash = '0x${timestamp.toRadixString(16).padLeft(64, '0')}';

      state = state.copyWith(
        isLoading: false,
        pendingUserOpHash: mockHash,
        currentStep: UserOpStep.completed,
      );

      return mockHash;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString(), currentStep: null);
      return null;
    }
  }

  Future<void> refreshDeploymentStatus() async {
    state = state.copyWith(isDeployed: false);
  }
}

/// Smart Wallet provider.
final smartWalletProvider =
    StateNotifierProvider<SmartWalletNotifier, SmartWalletState>((ref) {
  return SmartWalletNotifier(ref);
});
