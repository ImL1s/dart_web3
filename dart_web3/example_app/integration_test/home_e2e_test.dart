import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:web3_wallet_app/app.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen E2E Tests', () {
    testWidgets('Home screen displays when wallet exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasWalletProvider.overrideWith((ref) async => true),
          ],
          child: const Web3WalletApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should see home screen with scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('App shows onboarding when no wallet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasWalletProvider.overrideWith((ref) async => false),
          ],
          child: const Web3WalletApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should see onboarding
      expect(find.text('Create New Wallet'), findsOneWidget);
    });
  });
}
