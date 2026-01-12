
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3_wallet_app/shared/providers/nft_provider.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  group('NftNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is not configured', () {
      final state = container.read(nftProvider);
      expect(state.isConfigured, isFalse);
      expect(state.nfts, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('setApiKey updates configuration state', () async {
      final notifier = container.read(nftProvider.notifier);
      await notifier.setApiKey('test_api_key');
      
      final state = container.read(nftProvider);
      expect(state.isConfigured, isTrue);
      expect(state.error, isNull);
    });

    test('fetchNfts fails when not configured', () async {
      final notifier = container.read(nftProvider.notifier);
      await notifier.fetchNfts();
      
      final state = container.read(nftProvider);
      expect(state.error, contains('Please configure Alchemy API key'));
      expect(state.isConfigured, isFalse);
    });

    test('fetchNfts fails when no wallet is connected', () async {
      final notifier = container.read(nftProvider.notifier);
      await notifier.setApiKey('test_key');
      
      // Ensure wallet is empty
      final walletState = container.read(walletProvider);
      expect(walletState.selectedAccount, isNull);
      
      await notifier.fetchNfts();
      
      final state = container.read(nftProvider);
      expect(state.error, contains('No wallet connected'));
    });
  });
}
