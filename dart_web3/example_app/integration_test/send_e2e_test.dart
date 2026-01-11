import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:web3_wallet_app/features/send/presentation/screens/send_screen.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Send Flow E2E Tests', () {
    testWidgets('Send screen displays form fields', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SendScreen()));
      await tester.pumpAndSettle();

      // Should see text fields
      expect(find.byType(TextField), findsAtLeast(1));
    });

    testWidgets('Address field accepts input', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SendScreen()));
      await tester.pumpAndSettle();

      // Find address text field and enter text
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(
          textFields.first,
          '0x742d35Cc6634C0532925a3b844Bc9e7595f0Ab1D',
        );
        await tester.pumpAndSettle();

        // Verify text was entered
        expect(
          find.text('0x742d35Cc6634C0532925a3b844Bc9e7595f0Ab1D'),
          findsOneWidget,
        );
      }
    });

    testWidgets('Amount field accepts numeric input', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SendScreen()));
      await tester.pumpAndSettle();

      // Find all text fields - second should be amount
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        await tester.enterText(textFields.at(1), '0.01');
        await tester.pumpAndSettle();

        expect(find.text('0.01'), findsOneWidget);
      }
    });

    testWidgets('Form has send button', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const SendScreen()));
      await tester.pumpAndSettle();

      // Should have a filled button
      expect(find.byType(FilledButton), findsAtLeast(1));
    });
  });
}
