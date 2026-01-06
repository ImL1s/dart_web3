/// Providers for Ledger Hardware Wallet integration.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ledger_service.dart';

/// Provider for the LedgerService singleton.
final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService.instance;
});

/// Provider for the current Ledger connection status.
final ledgerStatusProvider = ChangeNotifierProvider((ref) { // Using ChangeNotifierProvider simply to listen? No, usually we Stream/StateProvider
  // Better: expose a StateProvider that updates from the service listener
  // But for now, let's just use the service provider and watch it in UI?
  // Actually, ChangeNotifierProvider on the service itself works if we used it.
  // ReownService used ChangeNotifier, did I use it for LedgerService? Yes.
  return LedgerService.instance;
});

// To match Reown pattern more closely:
final ledgerConnectionStatusProvider = Provider<LedgerStatus>((ref) {
  final service = ref.watch(ledgerStatusProvider);
  return service.status;
});

final discoveredDevicesProvider = Provider((ref) {
  final service = ref.watch(ledgerStatusProvider);
  return service.discoveredDevices;
});

final connectedLedgerDeviceProvider = Provider((ref) {
  final service = ref.watch(ledgerStatusProvider);
  return service.connectedDevice;
});

final ledgerErrorProvider = Provider<String?>((ref) {
  final service = ref.watch(ledgerStatusProvider);
  return service.error;
});
