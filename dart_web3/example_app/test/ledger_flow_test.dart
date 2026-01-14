
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as lf;
import 'package:web3_universal/web3_universal.dart';
import 'package:web3_wallet_app/core/services/ledger_service.dart';
import 'package:web3_wallet_app/features/connect/presentation/screens/connect_wallet_screen.dart';

// --- Mocks ---

class MockLedgerWrapper implements LedgerInterfaceWrapper {
  final StreamController<lf.LedgerDevice> _scanController = StreamController.broadcast();
  MockLedgerConnection? nextConnection;
  

  void emitDevice(lf.LedgerDevice device) {
    _scanController.add(device);
  }

  @override
  Stream<lf.LedgerDevice> scan() => _scanController.stream;

  @override
  Future<LedgerConnectionInterface> connect(lf.LedgerDevice device) async {
    return nextConnection ?? MockLedgerConnection();
  }
}

class MockLedgerConnection implements LedgerConnectionInterface {
  bool _isDisconnected = false;
  
  @override
  bool get isDisconnected => _isDisconnected;

  @override
  Future<void> disconnect() async {
    _isDisconnected = true;
  }

  @override
  // ignore: deprecated_member_use
  Future<T> sendOperation<T>(lf.LedgerOperation<T> operation) async {
    if (_isDisconnected) throw Exception('Disconnected');
    
    // Inspect command (ByteDataWriter logic is internal to sdk, just return MOCK data)
    final writer = lf.ByteDataWriter();
    await operation.write(writer);
    final apdu = writer.toBytes();
    final ins = apdu.length > 1 ? apdu[1] : 0;
    
    final status = [0x90, 0x00];

    // GetConfiguration (0x01)
    if (ins == 0x01) {
      return Uint8List.fromList([1, 1, 1, 2, ...status]) as T;
    }
    
    // GetPublicKey (0x02)
    if (ins == 0x02) {
      final pubKey = List.filled(65, 0xAA);
      final address = List.filled(20, 0xBB);
      return Uint8List.fromList([65, ...pubKey, 20, ...address, ...status]) as T;
    }

    // GetAppName (0x06)
    if (ins == 0x06) {
       final name = "Ethereum".codeUnits;
       final ver = "1.0.0".codeUnits;
       return Uint8List.fromList([name.length, ...name, ver.length, ...ver, ...status]) as T;
    }

    return Uint8List.fromList(status) as T; 
  }
}

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized(); // Removed for Unit/Widget test mode

  testWidgets('Ledger E2E Connect Flow', (tester) async {
    // Setup Mock
    final mockLedger = MockLedgerWrapper();
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterLedger.setMockLedger(mockLedger);
    LedgerService.resetMockInstance();

    // Pump Widget
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ConnectWalletScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Switch to Hardware Tab
    final hardwareTab = find.text('Hardware');
    expect(hardwareTab, findsOneWidget);
    await tester.tap(hardwareTab);
    await tester.pumpAndSettle();

    // 2. Verify "Scan for Devices" button exists
    final scanButton = find.text('Scan for Devices');
    expect(scanButton, findsOneWidget);

    // 3. Tap Scan
    await tester.tap(scanButton);
    await tester.pump(); // Trigger scan

    // 4. Emit Device from Mock
    // ignore: prefer_const_constructors
    mockLedger.emitDevice(lf.LedgerDevice(
      id: 'mock_nano_x',
      name: 'Nano X Mock',
      connectionType: lf.ConnectionType.ble,
      deviceInfo: lf.LedgerDeviceType.nanoX,
    ));
    await tester.pumpAndSettle(); 

    // 5. Verify Device List Item appears
    final deviceItem = find.text('Nano X Mock');
    expect(deviceItem, findsOneWidget);

    // 6. Tap Device to Connect
    await tester.tap(deviceItem);
    await tester.pump(); // Start connection
    // Connection is async involving multiple steps (Config, AppName, PublicKey)
    // We mock them to be fast, but need to wait for UI update
    await tester.pumpAndSettle(); 

    // 7. Verify Connected State
    expect(find.text('Ledger Connected!'), findsOneWidget);
    expect(find.text('Nano X Mock'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    // 8. Disconnect
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    // 9. Verify disconnected state (Back to Scan button)
    expect(find.text('Scan for Devices'), findsOneWidget);
    expect(find.text('Ledger Connected!'), findsNothing);
  }, skip: true);
}
