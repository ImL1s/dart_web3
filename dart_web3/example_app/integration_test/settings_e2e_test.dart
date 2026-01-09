import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

import 'package:web3_wallet_app/features/settings/presentation/screens/settings_screen.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings E2E Tests', () {
    testWidgets('Settings screen displays all sections', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Should see section headers
      expect(find.text(l10n.settingsPreferences), findsOneWidget);
    });

    testWidgets('Settings has language option', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      // Should see language icon
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('Settings has API configuration section', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Scroll if needed
      await tester.scrollUntilVisible(
        find.text(l10n.settingsApiConfiguration),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Should see API Configuration
      expect(find.text(l10n.settingsApiConfiguration), findsOneWidget);
    });

    testWidgets('Settings has security section', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Scroll to Security
      await tester.scrollUntilVisible(
        find.text(l10n.settingsSecurity),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsSecurity), findsOneWidget);
    });

    testWidgets('Settings has about section', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Scroll to About
      await tester.scrollUntilVisible(
        find.text(l10n.settingsAbout),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsAbout), findsOneWidget);
    });

    testWidgets('API key dialog opens when tapped', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final navigator = tester.element(find.byType(Navigator));
      final l10n = AppLocalizations.of(navigator)!;

      // Scroll to and tap API key option
      await tester.scrollUntilVisible(
        find.text(l10n.settingsAlchemyApiKey),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsAlchemyApiKey));
      await tester.pumpAndSettle();

      // Should see dialog
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Language dialog opens when tapped', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsScreen));
      final l10n = AppLocalizations.of(context)!;

      // Find language tile by icon and tap
      final languageIcon = find.byIcon(Icons.language);
      expect(languageIcon, findsOneWidget);
      
      await tester.tap(languageIcon);
      await tester.pumpAndSettle();

      // Should see language dialog with options
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('繁體中文'), findsOneWidget);
    });
  });
}
