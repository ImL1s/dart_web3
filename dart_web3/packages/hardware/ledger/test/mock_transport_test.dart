import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3_universal_ledger/web3_universal_ledger.dart';

void main() {
  group('TestLedgerTransport', () {
    late TestLedgerTransport transport;

    setUp(() {
      transport = TestLedgerTransport(
        mockAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD25',
      );
    });

    test('returns mock transport type', () {
      expect(transport.type, LedgerTransportType.mock);
    });

    test('is always supported and connected', () {
      expect(transport.isSupported, isTrue);
      expect(transport.isConnected, isTrue);
    });

    test('connect succeeds by default', () async {
      await expectLater(transport.connect(), completes);
    });

    test('connect throws when shouldFail is true', () async {
      final failingTransport = TestLedgerTransport(shouldFail: true);
      await expectLater(
        failingTransport.connect(),
        throwsA(isA<LedgerException>()),
      );
    });

    test('exchange records commands', () async {
      final command = APDUCommand(cla: 0xE0, ins: 0x02, p1: 0x00, p2: 0x00);
      await transport.exchange(command);

      expect(transport.recordedCommands, hasLength(1));
      expect(transport.recordedCommands.first.ins, 0x02);
    });

    test('exchange returns address for GET_ADDRESS command', () async {
      final command = APDUCommand(cla: 0xE0, ins: 0x02, p1: 0x00, p2: 0x00);
      final response = await transport.exchange(command);

      expect(response.isSuccess, isTrue);
      expect(response.data, isNotEmpty);
    });

    test('exchange returns signature for SIGN_TX command', () async {
      final command = APDUCommand(cla: 0xE0, ins: 0x04, p1: 0x00, p2: 0x00);
      final response = await transport.exchange(command);

      expect(response.isSuccess, isTrue);
      expect(response.data.length, 65); // v + r + s
    });

    test('custom responses override defaults', () async {
      final customData = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      transport.setCustomResponse(0x02, customData);

      final command = APDUCommand(cla: 0xE0, ins: 0x02, p1: 0x00, p2: 0x00);
      final response = await transport.exchange(command);

      expect(response.data, customData);
    });

    test('discoverDevices returns mock device', () async {
      final devices = await transport.discoverDevices();

      expect(devices, hasLength(1));
      expect(devices.first.name, 'Mock Ledger Nano X');
      expect(devices.first.deviceId, 'mock-device-001');
    });
  });

  group('LedgerClient with TestTransport', () {
    late LedgerClient client;
    late TestLedgerTransport transport;

    setUp(() {
      transport = TestLedgerTransport(
        mockAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD25',
      );
      client = LedgerClient(transport);
    });

    test('getAccount returns address after connect', () async {
      await client.connect();
      final account = await client.getAccount("m/44'/60'/0'/0/0");

      expect(account.address, isNotEmpty);
      expect(account.publicKey, isNotEmpty);
    });

    test('signTransaction returns signature after connect', () async {
      await client.connect();
      final txData = Uint8List.fromList([0x01, 0x02, 0x03]);
      final result = await client.signTransaction(txData, "m/44'/60'/0'/0/0");

      expect(result.signature, isNotEmpty);
    });

    test('signPersonalMessage returns signature after connect', () async {
      await client.connect();
      final message = Uint8List.fromList('Hello, Ledger!'.codeUnits);
      final result =
          await client.signPersonalMessage(message, "m/44'/60'/0'/0/0");

      expect(result.signature, isNotEmpty);
    });
  });

  group('Error Simulation', () {
    test('simulates connection failure', () async {
      final transport = TestLedgerTransport(
        shouldFail: true,
        failureType: LedgerErrorType.connectionFailed,
      );

      await expectLater(
        transport.connect(),
        throwsA(
          predicate<LedgerException>(
            (e) => e.type == LedgerErrorType.connectionFailed,
          ),
        ),
      );
    });

    test('simulates user denied error', () async {
      final transport = TestLedgerTransport(
        shouldFail: true,
        failureType: LedgerErrorType.userDenied,
      );

      await expectLater(
        transport.exchange(APDUCommand(cla: 0xE0, ins: 0x04, p1: 0, p2: 0)),
        throwsA(
          predicate<LedgerException>(
            (e) => e.type == LedgerErrorType.userDenied,
          ),
        ),
      );
    });
  });
}
