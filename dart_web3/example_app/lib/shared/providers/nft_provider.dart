import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nft_item.dart';
import '../../core/services/nft_service.dart';
import 'wallet_provider.dart';

/// NFT state for gallery.
class NftState {
  const NftState({
    this.nfts = const [],
    this.isLoading = false,
    this.error,
    this.isConfigured = false,
  });

  final List<NftItem> nfts;
  final bool isLoading;
  final String? error;
  final bool isConfigured;

  NftState copyWith({
    List<NftItem>? nfts,
    bool? isLoading,
    String? error,
    bool? isConfigured,
  }) {
    return NftState(
      nfts: nfts ?? this.nfts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

/// NFT provider notifier.
class NftNotifier extends StateNotifier<NftState> {
  NftNotifier(this._ref) : super(const NftState()) {
    _init();
  }

  final Ref _ref;
  final _service = NftService();

  Future<void> _init() async {
    await _service.loadApiKey();
    state = state.copyWith(isConfigured: _service.isConfigured);
  }

  /// Configure API key.
  Future<void> setApiKey(String apiKey) async {
    await _service.saveApiKey(apiKey);
    state = state.copyWith(isConfigured: _service.isConfigured, error: null);
  }

  /// Fetch NFTs for the current wallet address.
  Future<void> fetchNfts() async {
    if (!_service.isConfigured) {
      state = state.copyWith(
        error: 'Please configure Alchemy API key in Settings',
        isConfigured: false,
      );
      return;
    }

    final walletState = _ref.read(walletProvider);
    final account = walletState.selectedAccount;

    if (account == null) {
      state = state.copyWith(error: 'No wallet connected');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final nfts = await _service.getNftsForOwner(account.address);
      state = state.copyWith(
        nfts: nfts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh NFTs.
  Future<void> refresh() async {
    await _service.loadApiKey();
    state = state.copyWith(isConfigured: _service.isConfigured);
    await fetchNfts();
  }

  /// Check if API is configured.
  bool get isConfigured => _service.isConfigured;
}

/// NFT provider.
final nftProvider = StateNotifierProvider<NftNotifier, NftState>((ref) {
  return NftNotifier(ref);
});
