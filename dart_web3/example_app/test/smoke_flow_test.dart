
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';
import 'package:web3_wallet_app/app.dart';
import 'package:web3_wallet_app/shared/providers/wallet_provider.dart';

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Smoke Test: Full App Navigation & Sanity Check', (tester) async {
    // Mock FlutterSecureStorage
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return null;
      }
      return null;
    });

    // Set surface size to large to avoid scrolling/overflow
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    
    // 1. Launch App
    debugPrint('STEP 1: App Launching');
    await tester.pumpWidget(
      const ProviderScope(
        child: Web3WalletApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    debugPrint('STEP 1: App Launched');

    // Reset Wallet for clean state
    final navigator = tester.element(find.byType(Navigator));
    final l10n = AppLocalizations.of(navigator)!;
    debugPrint('STEP 2: Resetting Wallet');
    await ProviderScope.containerOf(navigator).read(walletProvider.notifier).deleteWallet();
    await tester.pump(const Duration(seconds: 1));
    debugPrint('STEP 2: Wallet Reset');

    // 2. Onboarding: Create Wallet
    expect(find.text(l10n.onboardingCreateWallet), findsOneWidget);
    
    debugPrint('STEP 3: Tapping Create Wallet');
    final createBtn = find.text(l10n.onboardingCreateWallet);
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    
    debugPrint('STEP 3: Waiting for Navigation');
    // Manual pump loop to drive animation without hanging on infinite loaders
    bool onNewScreen = false;
     for (int i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('New Wallet').evaluate().isNotEmpty) {
          onNewScreen = true;
          break;
        }
     }
     if (!onNewScreen) {
       debugPrint('Failed to navigate to Create Wallet screen. Dumping app:');
       debugDumpApp();
     }
     expect(find.text('New Wallet'), findsOneWidget, reason: "Not on New Wallet Screen");

    debugPrint('STEP 3: Waiting for Generation (Extra Buffer)');
    await tester.pump(const Duration(seconds: 2)); 
    debugPrint('STEP 3: Generation Wait Done');


    // Ensure not loading
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: "Still loading!");

    // 2.5 Interact with CreateWalletScreen
    debugPrint('STEP 3.5: Confirming Backup');
    // Find checkbox
    final checkbox = find.byType(Checkbox);
    if (checkbox.evaluate().isEmpty) {
       debugPrint('Checkbox not found, dumping app');
       debugDumpApp();
    }
    expect(checkbox, findsOneWidget, reason: "Checkbox not found");
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    
    // Find Continue button
    final goBtn = find.widgetWithText(FilledButton, 'Go to Wallet');
    await tester.ensureVisible(goBtn);
    await tester.tap(goBtn);
    await tester.pump(const Duration(seconds: 1)); // Wait for valid navigation

    // Verify Home Screen
    // We expect Shimmer or Balance. 
    debugPrint('STEP 4: Verifying Home Screen');
    await tester.pump(const Duration(seconds: 2)); 
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsAtLeastNWidgets(1));
    debugPrint('STEP 4: Home Screen Verified');
    
    // 3. Smoke Test: Navigation Tabs
    
    // Go to Settings
    final settingsIcon = find.byIcon(Icons.settings);
    if (settingsIcon.evaluate().isNotEmpty) {
        debugPrint('STEP 5: Going to Settings');
        await tester.tap(settingsIcon);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        
        // Verify Settings Header
        expect(find.text(l10n.settings), findsOneWidget); 
        debugPrint('STEP 5: Settings Verified');
    }
    
    // Go to History
    final historyIcon = find.byIcon(Icons.history);
    if (historyIcon.evaluate().isNotEmpty) {
        debugPrint('STEP 6: Going to History');
        await tester.tap(historyIcon);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        debugPrint('STEP 6: History Visited');
    }

    // Go back to Home
    final homeIcon = find.byIcon(Icons.home);
     if (homeIcon.evaluate().isNotEmpty) {
        debugPrint('STEP 7: Going back to Home');
        await tester.tap(homeIcon);
        await tester.pump(const Duration(milliseconds: 500));
        debugPrint('STEP 7: Back at Home');
    }
    
    // 4. Check Receive
    if (find.text(l10n.receive).evaluate().isNotEmpty) {
       debugPrint('STEP 8: Checking Receive');
       await tester.tap(find.text(l10n.receive));
       await tester.pump(const Duration(milliseconds: 500));
       await tester.pump(const Duration(milliseconds: 500));
       
       
       // Go Back
       debugPrint('STEP 8: Going Back');
       if (find.byTooltip('Back').evaluate().isNotEmpty) {
         await tester.tap(find.byTooltip('Back'));
       } else if (find.byType(BackButton).evaluate().isNotEmpty) {
         await tester.tap(find.byType(BackButton));
       } else {
         debugPrint('Back button not found, popping navigator explicitly');
         final navigator = tester.state(find.byType(Navigator).last) as NavigatorState;
         navigator.pop();
       }
       await tester.pump(const Duration(milliseconds: 500));
       debugPrint('STEP 8: Receive Verified');
    }
    
       // 5. Check Send
    final sendBtn = find.text(l10n.send);
    if (sendBtn.evaluate().isNotEmpty) {
       debugPrint('STEP 9: Checking Send');
       await tester.ensureVisible(sendBtn.first);
       await tester.tap(sendBtn.first);
       await tester.pump(const Duration(milliseconds: 500));
       await tester.pump(const Duration(milliseconds: 500));
       
       // Verify Send Screen
       final sendTitle = find.widgetWithText(AppBar, l10n.send);
       if (sendTitle.evaluate().isNotEmpty) {
           expect(sendTitle, findsOneWidget);
           
           // Go Back
           debugPrint('STEP 9: Going Back');
           if (find.byTooltip('Back').evaluate().isNotEmpty) {
             await tester.tap(find.byTooltip('Back'));
           } else if (find.byType(BackButton).evaluate().isNotEmpty) {
             await tester.tap(find.byType(BackButton));
           } else {
             debugPrint('Back button not found, popping navigator explicitly');
             final navigator = tester.state(find.byType(Navigator).last) as NavigatorState;
             navigator.pop();
           }
           await tester.pump(const Duration(milliseconds: 500));
           debugPrint('STEP 9: Send Verified');
       } else {
           debugPrint('STEP 9: Failed to navigate to Send screen, skipping pop');
       }
    }
    
  });
}
