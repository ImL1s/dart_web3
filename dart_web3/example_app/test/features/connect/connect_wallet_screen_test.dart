/// Widget tests for ConnectWalletScreen.
///
/// Tests cover:
/// - Provider definitions
/// - Data class structures
/// - Connection status enum
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:web3_wallet_app/shared/providers/reown_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReownConnectionStatus', () {
    test('has all expected values', () {
      expect(ReownConnectionStatus.values.length, 5);
      expect(ReownConnectionStatus.disconnected.index, 0);
      expect(ReownConnectionStatus.connecting.index, 1);
      expect(ReownConnectionStatus.connected.index, 2);
      expect(ReownConnectionStatus.sessionPending.index, 3);
      expect(ReownConnectionStatus.sessionActive.index, 4);
    });
  });

  group('ConnectedWallet', () {
    test('stores address correctly', () {
      const wallet = ConnectedWallet(
        address: '0x742d35Cc6634C0532925a3b844Bc9e7595f1B2f9',
        chainId: 1,
        sessionTopic: 'topic123',
      );

      expect(wallet.address, contains('0x742d35'));
      expect(wallet.chainId, 1);
    });

    test('stores wallet metadata', () {
      const wallet = ConnectedWallet(
        address: '0xabc',
        chainId: 137,
        sessionTopic: 'polygon_session',
        walletName: 'Trust Wallet',
        walletIcon: 'https://trustwallet.com/icon.png',
      );

      expect(wallet.walletName, 'Trust Wallet');
      expect(wallet.walletIcon, contains('trustwallet'));
    });
  });

  group('ReownProvider types', () {
    test('reownServiceProvider is defined', () {
      expect(reownServiceProvider, isNotNull);
    });

    test('connectedWalletProvider is defined', () {
      expect(connectedWalletProvider, isNotNull);
    });

    test('pairingUriProvider is defined', () {
      expect(pairingUriProvider, isNotNull);
    });

    test('reownErrorProvider is defined', () {
      expect(reownErrorProvider, isNotNull);
    });
  });
}
