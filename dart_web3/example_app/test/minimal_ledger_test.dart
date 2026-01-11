
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

class MockLedgerConnection implements LedgerConnection {
  @override
  bool get isDisconnected => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<T> sendOperation<T>(LedgerOperation<T> operation, {LedgerTransformer? transformer}) async {
    return Uint8List(0) as T;
  }
  
  @override
  ConnectionType get connectionType => ConnectionType.ble;

  @override
  LedgerDevice get device => LedgerDevice(
    id: 'mock', 
    name: 'mock', 
    connectionType: ConnectionType.ble,
    deviceInfo: LedgerDeviceType.nanoX,
  );
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('compile check', () {
    final m = MockLedgerConnection();
    expect(m.isDisconnected, false);
  });
}
