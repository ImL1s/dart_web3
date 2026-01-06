/// Reown provider for WalletConnect v2 state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reown_service.dart';

// Re-export for convenience
export '../../core/services/reown_service.dart'
    show ReownConnectionStatus, ConnectedWallet;

/// Reown service provider (singleton).
final reownServiceProvider = Provider<ReownService>((ref) {
  return ReownService.instance;
});

/// Reown connection status provider.
final reownStatusProvider = StreamProvider<ReownConnectionStatus>((ref) async* {
  final service = ref.watch(reownServiceProvider);
  
  // Initial value
  yield service.status;
  
  // Listen to changes via ChangeNotifier
  await for (final _ in Stream.periodic(const Duration(milliseconds: 100))) {
    yield service.status;
  }
});

/// Connected wallet provider.
final connectedWalletProvider = Provider<ConnectedWallet?>((ref) {
  final service = ref.watch(reownServiceProvider);
  return service.connectedWallet;
});

/// Pairing URI provider for QR code display.
final pairingUriProvider = Provider<String?>((ref) {
  final service = ref.watch(reownServiceProvider);
  return service.pairingUri;
});

/// Error provider.
final reownErrorProvider = Provider<String?>((ref) {
  final service = ref.watch(reownServiceProvider);
  return service.error;
});
