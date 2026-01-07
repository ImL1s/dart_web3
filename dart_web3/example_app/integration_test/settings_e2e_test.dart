import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:web3_wallet_app/features/settings/presentation/screens/settings_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings E2E Tests', () {
    testWidgets('Settings screen displays all sections', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should see section headers
      expect(find.text('Preferences'), findsOneWidget);
    });

    testWidgets('Settings has language option', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should see language icon
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('Settings has API configuration section', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll if needed
      await tester.scrollUntilVisible(
        find.text('API Configuration'),
        50,
        scrollable: find.byType(Scrollable).first,
      );

      // Should see API Configuration
      expect(find.text('API Configuration'), findsOneWidget);
    });

    testWidgets('Settings has security section', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Security
      await tester.scrollUntilVisible(
        find.text('Security'),
        50,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('Settings has about section', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to About
      await tester.scrollUntilVisible(
        find.text('About'),
        50,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('API key dialog opens when tapped', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to and tap API key option
      await tester.scrollUntilVisible(
        find.text('Alchemy API Key'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Alchemy API Key'));
      await tester.pumpAndSettle();

      // Should see dialog
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Language dialog opens when tapped', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find language tile by icon and tap
      final languageIcon = find.byIcon(Icons.language);
      expect(languageIcon, findsOneWidget);
      
      await tester.tap(languageIcon);
      await tester.pumpAndSettle();

      // Should see language dialog with options
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('繁體中文'), findsOneWidget);
    });
  });
}
