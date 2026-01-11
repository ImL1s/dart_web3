import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:web3_wallet_app/features/receive/presentation/screens/receive_screen.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Receive Flow E2E Tests', () {
    testWidgets('Receive screen displays correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const ReceiveScreen()));
      await tester.pumpAndSettle();

      // Should see scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Receive screen displays address label', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const ReceiveScreen()));
      await tester.pumpAndSettle();

      // Should see "Your Address" text
      expect(find.text('Your Address'), findsOneWidget);
    });

    testWidgets('Copy button is present', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const ReceiveScreen()));
      await tester.pumpAndSettle();

      // Should see copy icon
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('Share button is present', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const ReceiveScreen()));
      await tester.pumpAndSettle();

      // Should see share icon
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('Back button is present', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const ReceiveScreen()));
      await tester.pumpAndSettle();

      // Should see back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
