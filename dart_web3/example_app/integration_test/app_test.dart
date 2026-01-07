/// Main entry point for all E2E integration tests.
///
/// Run with: flutter test integration_test/app_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import all test files
import 'onboarding_e2e_test.dart' as onboarding;
import 'home_e2e_test.dart' as home;
import 'send_e2e_test.dart' as send;
import 'receive_e2e_test.dart' as receive;
import 'nft_gallery_e2e_test.dart' as nft;
import 'smart_wallet_e2e_test.dart' as smart_wallet;
import 'settings_e2e_test.dart' as settings;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Web3 Wallet App E2E Tests', () {
    onboarding.main();
    home.main();
    send.main();
    receive.main();
    nft.main();
    smart_wallet.main();
    settings.main();
  });
}
