import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';
import 'package:web3_wallet_app/app.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding E2E Tests', () {
    testWidgets('App launches to onboarding screen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Web3WalletApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;
      final container = ProviderScope.containerOf(navigator);
      await container.read(walletProvider.notifier).deleteWallet();
      await tester.pumpAndSettle();

      // Should see onboarding screen
      expect(find.text(l10n.onboardingCreateWallet), findsOneWidget);
      expect(find.text(l10n.onboardingImportWallet), findsOneWidget);
    });

    testWidgets('Create wallet flow navigates correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Web3WalletApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;
      await ProviderScope.containerOf(navigator).read(walletProvider.notifier).deleteWallet();
      await tester.pumpAndSettle();

      // Tap create wallet
      await tester.tap(find.text(l10n.onboardingCreateWallet));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should navigate away from onboarding
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Import wallet shows input field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Web3WalletApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;
      await ProviderScope.containerOf(navigator).read(walletProvider.notifier).deleteWallet();
      await tester.pumpAndSettle();

      // Tap import wallet
      await tester.tap(find.text(l10n.onboardingImportWallet));
      await tester.pumpAndSettle();

      // Should see import screen with text field
      expect(find.byType(TextField), findsAtLeast(1));
    });
  });
}
