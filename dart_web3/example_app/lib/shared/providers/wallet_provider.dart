/// Wallet provider for managing multi-chain accounts.
///
/// This provider wraps [WalletService] for Riverpod state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/wallet_service.dart';

// Re-export for convenience
export '../../core/wallet_service.dart'
    show ChainType, ChainConfig, Chains, Account;

/// Wallet state.
class WalletState {
  const WalletState({
    this.mnemonic,
    this.accounts = const [],
    this.selectedChain = ChainType.ethereum,
    this.isLoading = false,
    this.error,
  });

  final List<String>? mnemonic;
  final List<Account> accounts;
  final ChainType selectedChain;
  final bool isLoading;
  final String? error;

  bool get isInitialized => mnemonic != null;

  /// Get currently selected account
  Account? get selectedAccount {
    try {
      return accounts.firstWhere((a) => a.chain.type == selectedChain);
    } catch (_) {
      return accounts.isNotEmpty ? accounts.first : null;
    }
  }

  WalletState copyWith({
    List<String>? mnemonic,
    List<Account>? accounts,
    ChainType? selectedChain,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      mnemonic: mnemonic ?? this.mnemonic,
      accounts: accounts ?? this.accounts,
      selectedChain: selectedChain ?? this.selectedChain,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Wallet provider notifier using [WalletService].
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  final _service = WalletService.instance;

  /// Creates a new wallet with fresh mnemonic.
  Future<List<String>> createWallet() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final words = await _service.createWallet();
      final accounts = _service.getAllAccounts();

      state = state.copyWith(
        mnemonic: words,
        accounts: accounts,
        isLoading: false,
      );

      return words;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Imports wallet from mnemonic phrase.
  Future<void> importWallet(String mnemonicPhrase) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final words = mnemonicPhrase.trim().split(RegExp(r'\s+'));
      await _service.importWallet(words);
      final accounts = _service.getAllAccounts();

      state = state.copyWith(
        mnemonic: words,
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Loads wallet from secure storage.
  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final loaded = await _service.loadWallet();
      if (loaded) {
        final accounts = _service.getAllAccounts();
        state = state.copyWith(
          mnemonic: _service.mnemonic,
          accounts: accounts,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Selects a chain type.
  void selectChain(ChainType chain) {
    state = state.copyWith(selectedChain: chain);
  }

  /// Gets the chain config for the selected chain.
  ChainConfig get selectedChainConfig {
    return Chains.all.firstWhere(
      (c) => c.type == state.selectedChain,
      orElse: () => Chains.ethereum,
    );
  }

  /// Sends a transaction on the selected chain.
  Future<String> sendTransaction({
    required String to,
    required String amount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final chain = selectedChainConfig;
      final amountWei = _parseAmount(amount, chain.decimals);

      final txHash = await _service.sendTransaction(
        chain: chain,
        to: to,
        amount: amountWei,
      );

      state = state.copyWith(isLoading: false);
      return txHash;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Deletes wallet from storage.
  Future<void> deleteWallet() async {
    await _service.deleteWallet();
    state = const WalletState();
  }

  BigInt _parseAmount(String amount, int decimals) {
    final parts = amount.split('.');
    final whole = BigInt.parse(parts[0]);
    final multiplier = BigInt.from(10).pow(decimals);

    if (parts.length == 1) {
      return whole * multiplier;
    }

    var fraction = parts[1];
    if (fraction.length > decimals) {
      fraction = fraction.substring(0, decimals);
    }
    fraction = fraction.padRight(decimals, '0');

    return whole * multiplier + BigInt.parse(fraction);
  }
}

/// Wallet provider.
final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

/// Check if wallet exists in storage.
final hasWalletProvider = FutureProvider<bool>((ref) async {
  final loaded = await WalletService.instance.loadWallet();
  return loaded;
});
