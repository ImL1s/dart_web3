import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';
import 'package:web3_wallet_app/features/smart_wallet/presentation/screens/smart_wallet_screen.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Wallet E2E Tests', () {
    testWidgets('Smart Wallet screen displays', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SmartWalletScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      expect(find.text(l10n.smartWallet), findsAtLeast(1));
    });

    testWidgets('Smart Wallet has cards', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SmartWalletScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Card), findsAtLeast(1));
    });

    testWidgets('Smart Wallet has UserOp form', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SmartWalletScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(TextField), findsAtLeast(2)); // Recipient and Amount
    });

    testWidgets('Smart Wallet has send button', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SmartWalletScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Wait for initialization
      bool found = false;
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text(l10n.sendUserOp).evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }

      expect(found, isTrue, reason: 'Send button should eventually appear');
      expect(find.text(l10n.sendUserOp), findsOneWidget);
    });

    testWidgets('Smart Wallet has ERC-4337 info', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SmartWalletScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('ERC-4337'), findsAtLeast(1));
    });
  });
}
