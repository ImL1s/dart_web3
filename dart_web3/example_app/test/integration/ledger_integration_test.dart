// Integration tests for Ledger hardware wallet using TestLedgerTransport.
//
// These tests verify the complete flow without requiring a physical device.
// The main unit tests are in packages/hardware/ledger/test/mock_transport_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:web3_universal/web3_universal.dart';

void main() {
  group('TestLedgerTransport Direct Tests', () {
    test('TestLedgerTransport returns mock address', () async {
      final transport = TestLedgerTransport(
        mockAddress: '0x1234567890123456789012345678901234567890',
      );

      final devices = await transport.discoverDevices();
      expect(devices, hasLength(1));
      expect(devices.first.name, 'Mock Ledger Nano X');
    });

    test('TestLedgerTransport exchange returns success', () async {
      final transport = TestLedgerTransport();

      await transport.connect();
      final response = await transport.exchange(
        APDUCommand(cla: 0xE0, ins: 0x02, p1: 0, p2: 0),
      );

      expect(response.isSuccess, isTrue);
      expect(response.statusWord, 0x9000);
    });

    test('TestLedgerTransport simulates failure', () async {
      final transport = TestLedgerTransport(
        shouldFail: true,
        failureType: LedgerErrorType.userDenied,
      );

      expect(
        () =>
            transport.exchange(APDUCommand(cla: 0xE0, ins: 0x04, p1: 0, p2: 0)),
        throwsA(isA<LedgerException>()),
      );
    });

    test('TestLedgerTransport with LedgerClient', () async {
      final transport = TestLedgerTransport(
        mockAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD25',
      );
      final client = LedgerClient(transport);

      await client.connect();
      expect(client.state, LedgerConnectionState.connected);

      final account = await client.getAccount("m/44'/60'/0'/0/0");
      expect(account.address, isNotEmpty);
      expect(account.publicKey, isNotEmpty);
    });
  });
}
