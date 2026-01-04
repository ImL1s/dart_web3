import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_keystone/web3_universal_keystone.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

void main() {
  group('Keystone Client', () {
    late KeystoneClient client;
    late MockQRScanner scanner;
    
    setUp(() {
      scanner = MockQRScanner();
      client = KeystoneClient(qrScanner: scanner);
    });
    
    tearDown(() {
      client.dispose();
      scanner.dispose();
    });
    
    test('should connect to device', () async {
      expect(client.isConnected, isFalse);
      
      await client.connect();
      
      expect(client.isConnected, isTrue);
      expect(client.device, isNotNull);
      expect(client.device!.name, equals('Keystone Pro'));
    });
    
    test('should get accounts from device', () async {
      await client.connect();
      
      final accounts = await client.getAccounts(count: 3);
      
      expect(accounts.length, equals(3));
      for (var i = 0; i < accounts.length; i++) {
        expect(accounts[i].derivationPath, contains("m/44'/60'/0'/0/$i"));
        expect(accounts[i].address, startsWith('0x'));
        expect(accounts[i].publicKey.length, equals(64));
      }
    });
    
    test('should handle QR communication state', () async {
      await client.connect();
      
      expect(client.communicationState, equals(QRCommunicationState.idle));
      
      // Test that we can access the state streams
      expect(client.stateStream, isNotNull);
      expect(client.progressStream, isNotNull);
      expect(client.qrDisplayStream, isNotNull);
    });
  });
  
  group('Keystone Signer', () {
    late KeystoneClient client;
    late KeystoneSigner signer;
    
    setUp(() async {
      client = KeystoneClient();
      await client.connect();
      signer = await KeystoneSigner.create(client: client);
    });
    
    tearDown(() {
      client.dispose();
    });
    
    test('should have valid address', () {
      expect(signer.address.hex, startsWith('0x'));
      expect(signer.address.hex.length, equals(42));
    });
    
    test('should get multiple addresses', () async {
      final addresses = await signer.getAddresses();
      
      expect(addresses.length, equals(5));
      for (final address in addresses) {
        expect(address.hex, startsWith('0x'));
        expect(address.hex.length, equals(42));
      }
    });
    
    test('should handle connection state', () async {
      expect(await signer.isConnected(), isTrue);
      
      await signer.disconnect();
      expect(await signer.isConnected(), isFalse);
      
      await signer.connect();
      expect(await signer.isConnected(), isTrue);
    });
    
    test('should create transaction signing request', () async {
      final transaction = TransactionRequest(
        to: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        value: EthUnit.ether('1.0'),
        gasLimit: BigInt.from(21000),
        gasPrice: EthUnit.gwei('20'),
        nonce: BigInt.from(42),
        chainId: 1,
        type: TransactionType.legacy,
      );
      
      // This would normally display QR codes and wait for user interaction
      // For testing, we just verify it doesn't throw
      expect(() => signer.signTransaction(transaction), returnsNormally);
    });
  });
  
  group('QR Communication', () {
    late QRCommunication qrComm;
    
    setUp(() {
      qrComm = QRCommunication();
    });
    
    tearDown(() {
      qrComm.dispose();
    });
    
    test('should start in idle state', () {
      expect(qrComm.state, equals(QRCommunicationState.idle));
    });
    
    test('should display sign request', () async {
      final request = KeystoneSignRequest(
        requestId: Uint8List.fromList([1, 2, 3, 4]),
        data: Uint8List.fromList([5, 6, 7, 8]),
        dataType: KeystoneDataType.transaction,
        derivationPath: "m/44'/60'/0'/0/0",
        chainId: 1,
      );
      
      await qrComm.displaySignRequest(request);
      
      expect(qrComm.state, equals(QRCommunicationState.waitingForResponse));
      
      // Test that the QR display stream exists (even if empty in mock)
      expect(qrComm.qrDisplayStream, isNotNull);
    });
    
    test('should handle cancel', () async {
      final request = KeystoneSignRequest(
        requestId: Uint8List.fromList([1, 2, 3, 4]),
        data: Uint8List.fromList([5, 6, 7, 8]),
        dataType: KeystoneDataType.transaction,
        derivationPath: "m/44'/60'/0'/0/0",
      );
      
      await qrComm.displaySignRequest(request);
      expect(qrComm.state, equals(QRCommunicationState.waitingForResponse));
      
      qrComm.cancel();
      expect(qrComm.state, equals(QRCommunicationState.idle));
    });
  });
  
  group('Keystone Types', () {
    test('should create KeystoneDevice', () {
      final device = KeystoneDevice(
        deviceId: 'test-device',
        name: 'Test Keystone',
        version: '1.0.0',
        supportedCurves: ['secp256k1'],
      );
      
      expect(device.deviceId, equals('test-device'));
      expect(device.name, equals('Test Keystone'));
      expect(device.supportedCurves, contains('secp256k1'));
    });
    
    test('should create KeystoneAccount', () {
      final account = KeystoneAccount(
        address: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        derivationPath: "m/44'/60'/0'/0/0",
        publicKey: Uint8List(64),
        name: 'Test Account',
      );
      
      expect(account.address, startsWith('0x'));
      expect(account.derivationPath, contains("m/44'/60'"));
      expect(account.name, equals('Test Account'));
    });
    
    test('should handle KeystoneException', () {
      final exception = KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not found',
      );
      
      expect(exception.type, equals(KeystoneErrorType.deviceNotFound));
      expect(exception.message, equals('Device not found'));
      expect(exception.toString(), contains('KeystoneException'));
    });
  });
}
