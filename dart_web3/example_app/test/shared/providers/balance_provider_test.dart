import 'package:flutter_test/flutter_test.dart';
import 'package:web3_wallet_app/shared/providers/balance_provider.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  group('BalanceState', () {
    test('initial state has correct defaults', () {
      const state = BalanceState();
      
      expect(state.isLoading, isFalse);
      expect(state.lastUpdated, isNull);
      expect(state.error, isNull);
      expect(state.balances, isEmpty);
    });

    test('getBalance returns null for unknown chain', () {
      const state = BalanceState();
      
      expect(state.getBalance(ChainType.ethereum), isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const initial = BalanceState();
      final updated = initial.copyWith(isLoading: true);
      
      expect(updated.isLoading, isTrue);
      expect(updated.error, isNull);
      expect(updated.balances, isEmpty);
    });

    test('copyWith can set error', () {
      const initial = BalanceState();
      final updated = initial.copyWith(error: 'Network error');
      
      expect(updated.error, 'Network error');
      expect(updated.isLoading, isFalse);
    });

    test('totalUsdValue returns 0 for empty balances', () {
      const state = BalanceState();
      
      expect(state.totalUsdValue, 0.0);
    });
  });
}
