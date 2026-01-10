import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_universal_swap/web3_universal_swap.dart';

import '../../core/services/swap_service.dart';
import 'wallet_provider.dart';

/// Swap state
class SwapState {
  const SwapState({
    this.isLoading = false,
    this.error,
    this.isConfigured = false,
    this.quote,
    this.supportedTokens = const [],
  });

  final bool isLoading;
  final String? error;
  final bool isConfigured;
  final SwapQuote? quote;
  final List<SwapToken> supportedTokens;

  SwapState copyWith({
    bool? isLoading,
    String? error,
    bool? isConfigured,
    SwapQuote? quote,
    List<SwapToken>? supportedTokens,
  }) {
    return SwapState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConfigured: isConfigured ?? this.isConfigured,
      quote: quote ?? this.quote,
      supportedTokens: supportedTokens ?? this.supportedTokens,
    );
  }
}

/// Swap provider notifier
class SwapNotifier extends StateNotifier<SwapState> {
  SwapNotifier(this._ref) : super(const SwapState()) {
    _init();
  }

  final Ref _ref;
  final _service = SwapService();

  Future<void> _init() async {
    await _service.loadApiKey();
    state = state.copyWith(isConfigured: _service.isConfigured);
  }

  /// Configure API key
  Future<void> setApiKey(String apiKey) async {
    await _service.saveApiKey(apiKey);
    state = state.copyWith(isConfigured: _service.isConfigured, error: null);
  }
  
  /// Get quote
  Future<void> getQuote({
      required SwapToken fromToken, 
      required SwapToken toToken, 
      required BigInt amount,
  }) async {
      final wallet = _ref.read(walletProvider);
      if (wallet.selectedAccount == null) {
          state = state.copyWith(error: "No wallet connected");
          return;
      }
      
      state = state.copyWith(isLoading: true, error: null, quote: null);
      
      try {
          final quote = await _service.getQuote(
              fromToken: fromToken,
              toToken: toToken,
              amount: amount,
              fromAddress: wallet.selectedAccount!.address,
          );
          state = state.copyWith(quote: quote, isLoading: false);
      } catch (e) {
          state = state.copyWith(error: e.toString(), isLoading: false);
      }
  }
  
  /// Clear quote
  void clearQuote() {
      state = state.copyWith(quote: null, error: null);
  }
}

/// Swap provider
final swapProvider = StateNotifierProvider<SwapNotifier, SwapState>((ref) {
  return SwapNotifier(ref);
});
