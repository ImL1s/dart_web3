/// Balance provider for multi-chain wallet.
///
/// Provides real-time balance updates for all supported chains.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/wallet_service.dart';
import 'wallet_provider.dart';

/// Balance result for a single chain.
class BalanceResult {
  const BalanceResult({
    required this.chain,
    required this.balance,
    this.usdValue,
  });

  final ChainConfig chain;
  final BigInt balance;
  final double? usdValue;

  /// Formatted balance string.
  String get formatted {
    final value = balance / BigInt.from(10).pow(chain.decimals);
    return '${value.toStringAsFixed(4)} ${chain.symbol}';
  }
}

/// Balance state for all chains.
class BalanceState {
  const BalanceState({
    this.balances = const {},
    this.isLoading = false,
    this.lastUpdated,
    this.error,
  });

  final Map<ChainType, BalanceResult> balances;
  final bool isLoading;
  final DateTime? lastUpdated;
  final String? error;

  /// Total USD value (if available).
  double get totalUsdValue {
    return balances.values
        .where((b) => b.usdValue != null)
        .map((b) => b.usdValue!)
        .fold(0.0, (a, b) => a + b);
  }

  /// Get balance for a specific chain type.
  BalanceResult? getBalance(ChainType type) => balances[type];

  /// Copy with updated fields.
  BalanceState copyWith({
    Map<ChainType, BalanceResult>? balances,
    bool? isLoading,
    DateTime? lastUpdated,
    String? error,
  }) {
    return BalanceState(
      balances: balances ?? this.balances,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      error: error,
    );
  }
}

/// Balance provider notifier.
class BalanceNotifier extends StateNotifier<BalanceState> {
  BalanceNotifier(this._ref) : super(const BalanceState());

  final Ref _ref;
  Timer? _refreshTimer;
  final _service = WalletService.instance;

  /// Refresh all balances.
  Future<void> refresh() async {
    final walletState = _ref.read(walletProvider);
    if (!walletState.isInitialized) {
      state = const BalanceState(error: 'No wallet loaded');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    if (!mounted) return;

    try {
      final newBalances = <ChainType, BalanceResult>{};

      for (final account in walletState.accounts) {
        try {
          final balance = await _service.getBalance(account);
          if (!mounted) return;
          newBalances[account.chain.type] = BalanceResult(
            chain: account.chain,
            balance: balance,
          );
        } catch (_) {
          // Skip failed chains
        }
      }

      state = BalanceState(
        balances: newBalances,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh balance for a specific chain.
  Future<void> refreshChain(ChainType type) async {
    final walletState = _ref.read(walletProvider);
    final account =
        walletState.accounts.where((a) => a.chain.type == type).firstOrNull;
    if (account == null) return;

    try {
      final balance = await _service.getBalance(account);
      if (!mounted) return;
      final newBalances = Map<ChainType, BalanceResult>.from(state.balances);
      newBalances[type] = BalanceResult(
        chain: account.chain,
        balance: balance,
      );

      state = state.copyWith(
        balances: newBalances,
        lastUpdated: DateTime.now(),
      );
    } catch (_) {
      // Keep existing balance
    }
  }

  /// Start auto-refresh timer.
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(interval, (_) => refresh());
  }

  /// Stop auto-refresh timer.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

/// Balance provider.
final balanceProvider =
    StateNotifierProvider<BalanceNotifier, BalanceState>((ref) {
  return BalanceNotifier(ref);
});

/// Selected chain balance provider.
final selectedChainBalanceProvider = Provider<BalanceResult?>((ref) {
  final balanceState = ref.watch(balanceProvider);
  final walletState = ref.watch(walletProvider);

  return balanceState.getBalance(walletState.selectedChain);
});
