import 'package:flutter_test/flutter_test.dart';
import 'package:web3_wallet_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: Web3WalletApp(),
      ),
    );

    // Verify that theme is loaded (or just that it didn't crash)
    expect(find.byType(Web3WalletApp), findsOneWidget);
  });
}
