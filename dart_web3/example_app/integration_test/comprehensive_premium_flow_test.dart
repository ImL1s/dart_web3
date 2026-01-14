
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';
import 'package:web3_wallet_app/app.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Comprehensive Premium Features Flow Test', (tester) async {
    // Set surface size to large to avoid scrolling/overflow
    await tester.binding.setSurfaceSize(const Size(800, 2000));

    // 1. Launch App
    await tester.pumpWidget(
      const ProviderScope(
        child: Web3WalletApp(),
      ),
    );
    await tester.pumpAndSettle();
    
    final navigator = tester.element(find.byType(Navigator));
    final l10n = AppLocalizations.of(navigator)!;

    // Reset Wallet for clean state
    await ProviderScope.containerOf(navigator).read(walletProvider.notifier).deleteWallet();
    await tester.pumpAndSettle();

    // --- STEP 1: Onboarding & Asset Verification ---
    debugPrint('TEST: Verifying Onboarding Assets');
    final onboardingCreateBtn = find.text(l10n.onboardingCreateWallet);
    expect(onboardingCreateBtn, findsOneWidget);
    
    // Check for Onboarding Image
    bool foundOnboardingImage = false;
    for (final widget in tester.allWidgets) {
      if (widget is Image && widget.image is AssetImage) {
        final asset = widget.image as AssetImage;
        if (asset.assetName == 'assets/images/wallet_onboarding.png') {
          foundOnboardingImage = true;
        }
      }
    }
    expect(foundOnboardingImage, isTrue, reason: "Onboarding image assets/images/wallet_onboarding.png not found");

    // --- STEP 2: Create Wallet Flow (Premium UI) ---
    debugPrint('TEST: Creating Wallet with Premium UI');
    await tester.ensureVisible(onboardingCreateBtn);
    await tester.tap(onboardingCreateBtn);
    
    // Custom pump loop for navigation
    bool onNewScreen = false;
    for (int i = 0; i < 100; i++) {
       await tester.pump(const Duration(milliseconds: 50));
       if (find.text('New Wallet').evaluate().isNotEmpty) {
         onNewScreen = true;
         break;
       }
    }
    expect(onNewScreen, isTrue, reason: "Failed to navigate to New Wallet screen");

    // Verify Cloud Backup simulation
    final backupBtn = find.text('Cloud Backup');
    expect(backupBtn, findsOneWidget);
    await tester.tap(backupBtn);
    await tester.pump();
    
    // Wait for backup simulation to complete
    for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(Checkbox).evaluate().isNotEmpty) break;
    }
    
    // Confirm backup checkbox
    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    
    // Continue to Wallet
    final goBtn = find.widgetWithText(FilledButton, 'Go to Wallet');
    await tester.tap(goBtn);
    
    // Wait for Home Screen (Smart Wallet button)
    bool atHome = false;
    for (int i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text(l10n.smartWallet).evaluate().isNotEmpty) {
            atHome = true;
            break;
        }
    }
    if (!atHome) {
       debugPrint('Failed to reach Home screen. Dumping tree:');
       debugDumpApp();
    }
    expect(atHome, isTrue, reason: "Failed to navigate to Home screen");

    // --- STEP 3: Smart Wallet (AA) Flow ---
    debugPrint('TEST: Verifying Smart Wallet (AA) Features');
    final smartWalletBtn = find.text(l10n.smartWallet);
    await tester.ensureVisible(smartWalletBtn);
    await tester.tap(smartWalletBtn);
    await tester.pumpAndSettle();
    
    // Verify AA Illustration
    bool foundAaIllustration = false;
    for (final widget in tester.allWidgets) {
      if (widget is Image && widget.image is AssetImage) {
        final asset = widget.image as AssetImage;
        if (asset.assetName == 'assets/images/aa_illustration.png') {
          foundAaIllustration = true;
        }
      }
    }
    expect(foundAaIllustration, isTrue, reason: "AA illustration assets/images/aa_illustration.png not found");

    // Test Paymaster Toggle
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    
    // --- STEP 4: NFT Gallery Flow ---
    debugPrint('TEST: Verifying NFT Gallery Features');
    // Go back
    final backBtn = find.byIcon(Icons.arrow_back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
    }
    
    // Navigate to NFT Gallery
    final nftBtn = find.text(l10n.nftGallery);
    await tester.ensureVisible(nftBtn);
    await tester.tap(nftBtn);
    await tester.pumpAndSettle();
      
    // Check Empty State Image
    bool foundEmptyNftImage = false;
    for (final widget in tester.allWidgets) {
      if (widget is Image && widget.image is AssetImage) {
        final asset = widget.image as AssetImage;
        if (asset.assetName == 'assets/images/empty_nft.png') {
          foundEmptyNftImage = true;
        }
      }
    }
    expect(foundEmptyNftImage, isTrue, reason: "Empty NFT image assets/images/empty_nft.png not found");
      
    // Test search bar
    final searchField = find.byType(TextField);
    if (searchField.evaluate().isNotEmpty) {
      await tester.enterText(searchField, 'test search');
      await tester.pumpAndSettle();
    }

    // --- STEP 5: Transaction History (Glassmorphism) ---
    debugPrint('TEST: Verifying Transaction History UI');
    // Go back
    if (backBtn.evaluate().isNotEmpty) {
       await tester.tap(backBtn);
       await tester.pumpAndSettle();
    }

    // Navigate to History
    final historyBtn = find.text(l10n.transactionHistory);
    await tester.ensureVisible(historyBtn);
    await tester.tap(historyBtn);
    await tester.pumpAndSettle();
      
    // Check for glassmorphism elements (BackdropFilter)
    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));

    // --- STEP 6: Multi-language Support (ZH-TW) ---
    debugPrint('TEST: Verifying Multi-language Support (ZH-TW)');
    
    // Go back from History to Home
    final backToHomeFromHistory = find.byIcon(Icons.arrow_back);
    await tester.tap(backToHomeFromHistory);
    await tester.pumpAndSettle();

    // Navigate to Settings from Home
    final settingsIcon = find.byIcon(Icons.settings_outlined);
    expect(settingsIcon, findsOneWidget);
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();

    // Open language dialog
    final languageTile = find.text(l10n.language);
    await tester.tap(languageTile);
    await tester.pumpAndSettle();

    // Select Traditional Chinese
    final zhBtn = find.text('繁體中文');
    expect(zhBtn, findsOneWidget);
    await tester.tap(zhBtn);
    await tester.pumpAndSettle();

    // Verify Settings UI is now in Chinese
    // "設置" is settings in zh
    expect(find.text('設置'), findsOneWidget);

    // Go back to Home
    final backBtnToHome = find.byIcon(Icons.arrow_back);
    await tester.tap(backBtnToHome);
    await tester.pumpAndSettle();

    // Verify Home Screen is now in Chinese
    // "智能錢包" is smart wallet in zh
    expect(find.text('智能錢包'), findsOneWidget);
    expect(find.text('NFT 畫廊'), findsOneWidget);

    debugPrint('TEST: COMPREHENSIVE FLOW WITH ZH-TW PASSED');
  });
}
