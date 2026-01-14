
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as lf;
import 'package:web3_universal/web3_universal.dart';
import 'package:web3_wallet_app/core/services/ledger_service.dart';

// --- Mocks ---

class MockLedgerWrapper implements LedgerInterfaceWrapper {
  final StreamController<lf.LedgerDevice> _scanController = StreamController.broadcast();
  MockLedgerConnection? nextConnection;
  Object? nextConnectError;

  void emitDevice(lf.LedgerDevice device) {
    _scanController.add(device);
  }

  @override
  Stream<lf.LedgerDevice> scan() => _scanController.stream;

  @override
  Future<LedgerConnectionInterface> connect(lf.LedgerDevice device) async {
    if (nextConnectError != null) {
      throw nextConnectError!;
    }
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
    if (_isDisconnected) {
      throw Exception('Disconnected');
    }
    
    // Inspect command
    final writer = lf.ByteDataWriter();
    await operation.write(writer);
    final apdu = writer.toBytes();
    final ins = apdu.length > 1 ? apdu[1] : 0;
    
    // Default success status
    final status = [0x90, 0x00];

    // GetConfiguration (0x01)
    if (ins == 0x01) {
      // arbitraryData=1, erc20=1, major=1, minor=2
      return Uint8List.fromList([1, 1, 1, 2, ...status]) as T;
    }
    
    // GetPublicKey (0x02)
    if (ins == 0x02) {
      final pubKey = List.filled(65, 0xAA);
      final address = List.filled(20, 0xBB);
      return Uint8List.fromList([65, ...pubKey, 20, ...address, ...status]) as T;
    }

    // SignTransaction (0x04) or SignPersonal (0x08)
    if (ins == 0x04 || ins == 0x08) {
       final signature = List.filled(65, 0x01); 
       return Uint8List.fromList([...signature, ...status]) as T;
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
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late LedgerService service;
  late MockLedgerWrapper mockLedger;

  setUp(() {
    mockLedger = MockLedgerWrapper();
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterLedger.setMockLedger(mockLedger);
    LedgerService.resetMockInstance(); 
    service = LedgerService.instance;
  });
  
  tearDown(() async {
    await service.disconnect();
  });

  group('LedgerService', () {
    test('initial state is disconnected', () {
      expect(service.status, LedgerStatus.disconnected);
      expect(service.discoveredDevices, isEmpty);
    });

    test('scanForDevices finds devices', () async {
      service.scanForDevices();
      
      // ignore: prefer_const_constructors
      mockLedger.emitDevice(lf.LedgerDevice(
        id: 'test_id',
        name: 'Nano X',
        connectionType: lf.ConnectionType.ble,
        deviceInfo: lf.LedgerDeviceType.nanoX,
      ));
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(service.status, LedgerStatus.scanning);
      expect(service.discoveredDevices.length, 1);
      expect(service.discoveredDevices.first.name, 'Nano X');
    });

    test('connect updates state', () async {
      final flutterDevice = FlutterLedgerDevice(
        // ignore: prefer_const_constructors
        lf.LedgerDevice(
          id: 'id', 
          name: 'Nano', 
          connectionType: lf.ConnectionType.ble,
          deviceInfo: lf.LedgerDeviceType.nanoX,
        )
      );
      
      await service.connect(flutterDevice);
      
      expect(service.status, LedgerStatus.connected);
      expect(service.connectedDevice!.deviceId, flutterDevice.deviceId);
    });

    test('connect handles errors', () async {
       mockLedger.nextConnectError = Exception('BLE Error');
       
       final flutterDevice = FlutterLedgerDevice(
        // ignore: prefer_const_constructors
        lf.LedgerDevice(
          id: 'id', 
          name: 'Nano', 
          connectionType: lf.ConnectionType.ble,
          deviceInfo: lf.LedgerDeviceType.nanoX,
        )
      );

       await service.connect(flutterDevice);
       
       expect(service.status, LedgerStatus.error);
       expect(service.error, contains('BLE Error'));
    });
    
    test('disconnect clears state', () async {
      final flutterDevice = FlutterLedgerDevice(
        // ignore: prefer_const_constructors
        lf.LedgerDevice(
          id: 'id', 
          name: 'Nano', 
          connectionType: lf.ConnectionType.ble,
          deviceInfo: lf.LedgerDeviceType.nanoX,
        )
      );
      await service.connect(flutterDevice);
      expect(service.status, LedgerStatus.connected);
      
      await service.disconnect();
      expect(service.status, LedgerStatus.disconnected);
      expect(service.connectedDevice, isNull);
    });
    
    test('signTransaction calls sendOperation', () async {
      // Connect
      final flutterDevice = FlutterLedgerDevice(
        // ignore: prefer_const_constructors
        lf.LedgerDevice(
          id: 'id', 
          name: 'Nano', 
          connectionType: lf.ConnectionType.ble,
          deviceInfo: lf.LedgerDeviceType.nanoX,
        )
      );
      await service.connect(flutterDevice);
      expect(service.status, LedgerStatus.connected);

      final txData = Uint8List.fromList([1, 2, 3]);
      final signature = await service.signTransaction(txData, "m/44'/60'/0'/0/0");
      
      expect(signature, isNotNull);
      expect(signature.length, 65);
    });
  });
}
