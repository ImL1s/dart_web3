import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:web3_wallet_app/features/smart_wallet/presentation/screens/smart_wallet_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Wallet E2E Tests', () {
    testWidgets('Smart Wallet screen displays', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmartWalletScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should see scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Smart Wallet has cards', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmartWalletScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should have card widgets
      expect(find.byType(Card), findsAtLeast(1));
    });

    testWidgets('Smart Wallet has UserOp form', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmartWalletScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should have text fields for UserOp
      expect(find.byType(TextField), findsAtLeast(1));
    });

    testWidgets('Smart Wallet has send button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmartWalletScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should have send button
      expect(find.byType(FilledButton), findsAtLeast(1));
    });

    testWidgets('Smart Wallet has ERC-4337 info', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmartWalletScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should have ERC-4337 info
      expect(find.textContaining('ERC-4337'), findsOneWidget);
    });
  });
}
