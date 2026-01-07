import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/create_wallet_screen.dart';
import '../../features/onboarding/presentation/screens/import_wallet_screen.dart';
import '../../features/send/presentation/screens/send_screen.dart';
import '../../features/receive/presentation/screens/receive_screen.dart';
import '../../features/swap/presentation/screens/swap_screen.dart';
import '../../features/nft/presentation/screens/nft_gallery_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/history/presentation/screens/transaction_history_screen.dart';
import '../../features/connect/presentation/screens/connect_wallet_screen.dart';
import '../../features/smart_wallet/presentation/screens/smart_wallet_screen.dart';
import '../../shared/providers/wallet_provider.dart';

/// App router provider using GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  final hasWallet = ref.watch(hasWalletProvider);

  return GoRouter(
    initialLocation: hasWallet.when(
      data: (hasWallet) => hasWallet ? '/home' : '/onboarding',
      loading: () => '/onboarding',
      error: (_, __) => '/onboarding',
    ),
    routes: [
      // Onboarding flow
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/create-wallet',
        builder: (context, state) => const CreateWalletScreen(),
      ),
      GoRoute(
        path: '/import-wallet',
        builder: (context, state) => const ImportWalletScreen(),
      ),

      // Main app
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/send',
        builder: (context, state) => const SendScreen(),
      ),
      GoRoute(
        path: '/receive',
        builder: (context, state) => const ReceiveScreen(),
      ),
      GoRoute(
        path: '/swap',
        builder: (context, state) => const SwapScreen(),
      ),
      GoRoute(
        path: '/nft',
        builder: (context, state) => const NftGalleryScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/connect-wallet',
        builder: (context, state) => const ConnectWalletScreen(),
      ),
      GoRoute(
        path: '/smart-wallet',
        builder: (context, state) => const SmartWalletScreen(),
      ),
    ],
    redirect: (context, state) {
      // Add redirect logic if needed
      return null;
    },
  );
});
