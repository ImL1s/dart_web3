import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3_wallet_app/shared/providers/transaction_history_provider.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

// Mock WalletNotifier to provide controlled state
class MockWalletNotifier extends WalletNotifier {
  MockWalletNotifier() : super();

  // Override to do nothing (mocks)
  @override
  Future<List<String>> createWallet() async => [];
  @override
  Future<void> importWallet(String mnemonic) async {}
  @override
  Future<void> loadWallet() async {}
  @override
  void selectChain(ChainType chain) {
    state = state.copyWith(selectedChain: chain);
  }
  @override
  ChainConfig get selectedChainConfig => Chains.ethereum; // Default
  @override
  Future<String> sendTransaction({required String to, required String amount}) async => '';
  @override
  Future<void> deleteWallet() async {}
  
  // Helper to set state directly for testing
  void setAccounts(List<Account> accounts) {
    state = state.copyWith(accounts: accounts);
  }
  
  void setChain(ChainType chain) {
    state = state.copyWith(selectedChain: chain);
  }
}

void main() {
  group('TransactionHistoryProvider Tests', () {
    late ProviderContainer container;
    late MockWalletNotifier mockWalletNotifier;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      mockWalletNotifier = MockWalletNotifier();
      
      container = ProviderContainer(
        overrides: [
          walletProvider.overrideWith((ref) => mockWalletNotifier),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is empty', () {
      final state = container.read(transactionHistoryProvider);
      expect(state.isLoading, false);
      expect(state.transactions, isEmpty);
      expect(state.error, null);
    });

    test('Refresh updates state with mock transactions (Ethereum)', () async {
      // Setup mock wallet state
      const account = Account(
        address: '0x123...',
        chain: Chains.ethereum,
      );
      mockWalletNotifier.setAccounts([account]);
      mockWalletNotifier.setChain(ChainType.ethereum);
      
      await container.read(transactionHistoryProvider.notifier).refresh();
      
      final state = container.read(transactionHistoryProvider);
      
      expect(state.isLoading, false);
      expect(state.transactions, isNotEmpty);
      final tx = state.transactions.first;
      expect(tx.hash, contains('eth...mock'));
    });

    test('Can fetch Bitcoin transactions', () async {
      const account = Account(
        address: 'bc1q...',
        chain: Chains.bitcoin,
      );
      mockWalletNotifier.setAccounts([account]);
      mockWalletNotifier.setChain(ChainType.bitcoin);
      
      await container.read(transactionHistoryProvider.notifier).refresh();
      
      final state = container.read(transactionHistoryProvider);
      
      expect(state.transactions, isNotEmpty);
      expect(state.transactions.first.hash, contains('btc...mock'));
    });

    test('Can fetch Solana transactions', () async {
      const account = Account(
        address: 'SolAddr...',
        chain: Chains.solana,
      );
      mockWalletNotifier.setAccounts([account]);
      mockWalletNotifier.setChain(ChainType.solana);
      
      await container.read(transactionHistoryProvider.notifier).refresh();
      
      final state = container.read(transactionHistoryProvider);
      
      expect(state.transactions, isNotEmpty);
      expect(state.transactions.first.hash, contains('sol...mock'));
    });
  });
}
