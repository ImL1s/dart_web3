
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';
import 'package:web3_wallet_app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Error Handling: Invalid Mnemonic Import', (tester) async {
    // 1. Launch App
    await tester.pumpWidget(
      const ProviderScope(
        child: Web3WalletApp(),
      ),
    );
    await tester.pumpAndSettle();
    
    final navigator = tester.element(find.byType(Navigator));
    final l10n = AppLocalizations.of(navigator)!;

    // 2. Navigate to Import Wallet
    final importBtn = find.text(l10n.onboardingImportWallet);
    await tester.ensureVisible(importBtn);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    // 3. Enter Invalid Mnemonic (12 words but wrong checksum/words)
    final mnemonicField = find.byType(TextField);
    expect(mnemonicField, findsOneWidget);
    
    const invalidMnemonic = 'one two three four five six seven eight nine ten eleven twelve';
    await tester.enterText(mnemonicField, invalidMnemonic);
    await tester.pumpAndSettle();

    // 4. Submit
    final submitBtn = find.widgetWithText(FilledButton, 'Import Wallet');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    
    // Wait for SnackBar
    bool foundError = false;
    for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
            foundError = true;
            break;
        }
    }
    
    expect(foundError, isTrue, reason: "Error SnackBar should be displayed");
    expect(find.textContaining('Invalid mnemonic phrase'), findsOneWidget);
    
    debugPrint('TEST: ERROR HANDLING PASSED');
  });
}
