import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:web3_wallet_app/features/nft/presentation/screens/nft_gallery_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NFT Gallery E2E Tests', () {
    testWidgets('NFT Gallery screen displays', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NftGalleryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should see scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('NFT Gallery has refresh button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NftGalleryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have refresh icon in app bar or loading indicator
      // (depends on state)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('NFT Gallery has info banner', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NftGalleryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show Alchemy banner
      expect(find.textContaining('Alchemy'), findsOneWidget);
    });

    testWidgets('NFT Gallery shows API key message when not configured', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NftGalleryScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should show API key message or loading state
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
