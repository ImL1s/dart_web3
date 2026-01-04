import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart' as abi;
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_trezor/web3_universal_trezor.dart';

void main() {
  group('Trezor Transport', () {
    late MockTrezorTransport transport;
    
    setUp(() {
      transport = createMockTrezorTransport();
    });
    
    tearDown(() {
      transport.dispose();
    });
    
    test('should connect and disconnect', () async {
      expect(transport.isConnected, isFalse);
      
      await transport.connect();
      expect(transport.isConnected, isTrue);
      
      await transport.disconnect();
      expect(transport.isConnected, isFalse);
    });
    
    test('should discover devices', () async {
      final devices = await transport.discoverDevices();
      
      expect(devices, isNotEmpty);
      expect(devices.first.model, equals('Mock Trezor Device'));
    });
    
    test('should exchange messages', () async {
      await transport.connect();
      
      final message = TrezorMessage(
        type: TrezorMessageType.initialize,
        data: Uint8List(0),
      );
      
      final response = await transport.exchange(message);
      
      expect(response.type, equals(TrezorMessageType.features));
    });
    
    test('should handle mock responses', () async {
      await transport.connect();
      
      final customResponse = TrezorMessage(
        type: TrezorMessageType.success,
        data: Uint8List.fromList([0x01, 0x02, 0x03]),
      );
      
      transport.setMockResponse(TrezorMessageType.getFeatures, customResponse);
      
      final request = TrezorMessage(
        type: TrezorMessageType.getFeatures,
        data: Uint8List(0),
      );
      
      final response = await transport.exchange(request);
      
      expect(response.type, equals(TrezorMessageType.success));
      expect(response.data, equals(customResponse.data));
    });
  });
  
  group('Trezor Message', () {
    test('should serialize to wire format', () {
      final message = TrezorMessage(
        type: TrezorMessageType.initialize,
        data: Uint8List.fromList([0x01, 0x02, 0x03]),
      );
      
      final wireData = message.toWireFormat();
      
      expect(wireData.length, equals(9 + 3)); // Header + data
      expect(wireData[0], equals(0x23)); // Magic byte 1
      expect(wireData[1], equals(0x23)); // Magic byte 2
      expect(wireData[2], equals(0x00)); // Message type high byte
      expect(wireData[3], equals(0x00)); // Message type low byte (Initialize = 0)
      expect(wireData[7], equals(0x03)); // Data length low byte
    });
    
    test('should parse from wire format', () {
      final wireData = Uint8List.fromList([
        0x23, 0x23, // Magic bytes
        0x00, 0x11, // Message type (Features = 17)
        0x00, 0x00, 0x00, 0x02, // Data length (2)
        0x00, // Session ID
        0xAA, 0xBB, // Data
      ]);
      
      final message = TrezorMessage.fromWireFormat(wireData);
      
      expect(message.type, equals(TrezorMessageType.features));
      expect(message.data, equals(Uint8List.fromList([0xAA, 0xBB])));
    });
    
    test('should handle invalid wire format', () {
      final invalidWireData = Uint8List.fromList([0x00, 0x00]); // Too short
      
      expect(
        () => TrezorMessage.fromWireFormat(invalidWireData),
        throwsA(isA<TrezorException>()),
      );
    });
  });
  
  group('Protobuf Messages', () {
    test('should encode EthereumGetAddress', () {
      final encoded = encodeEthereumGetAddress(
        derivationPath: "m/44'/60'/0'/0/0",
        showDisplay: true,
      );
      
      expect(encoded, isNotEmpty);
      // Should contain encoded derivation path and display flag
    });
    
    test('should encode EthereumSignTx', () {
      final encoded = encodeEthereumSignTx(
        derivationPath: "m/44'/60'/0'/0/0",
        nonce: Uint8List.fromList([0x01]),
        gasPrice: Uint8List.fromList([0x02]),
        gasLimit: Uint8List.fromList([0x03]),
        to: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        value: Uint8List.fromList([0x04]),
        chainId: 1,
      );
      
      expect(encoded, isNotEmpty);
    });
    
    test('should decode Features', () {
      final mockData = Uint8List.fromList([0x08, 0x01]);
      final features = decodeFeatures(mockData);
      
      expect(features.vendor, equals('trezor.io'));
      expect(features.majorVersion, equals(2));
      expect(features.supportsEthereum, isTrue);
    });
  });
  
  group('Trezor Client', () {
    late MockTrezorTransport transport;
    late TrezorClient client;
    
    setUp(() {
      transport = createMockTrezorTransport();
      client = TrezorClient(transport);
    });
    
    tearDown(() {
      client.dispose();
    });
    
    test('should connect to device', () async {
      expect(client.state, equals(TrezorConnectionState.disconnected));
      
      await client.connect();
      
      expect(client.state, equals(TrezorConnectionState.connected));
      expect(client.isReady, isTrue);
      expect(client.features, isNotNull);
    });
    
    test('should get account information', () async {
      await client.connect();
      
      final account = await client.getAccount("m/44'/60'/0'/0/0");
      
      expect(account.derivationPath, equals("m/44'/60'/0'/0/0"));
      expect(account.address, startsWith('0x'));
      expect(account.publicKey.length, equals(64));
    });
    
    test('should get multiple accounts', () async {
      await client.connect();
      
      final accounts = await client.getAccounts(count: 3);
      
      expect(accounts.length, equals(3));
      for (var i = 0; i < accounts.length; i++) {
        expect(accounts[i].derivationPath, contains('/$i'));
        expect(accounts[i].index, equals(i));
      }
    });
    
    test('should handle button request during signing', () async {
      await client.connect();
      
      // The mock transport will return a button request first
      final signResponse = await client.signMessage(
        derivationPath: "m/44'/60'/0'/0/0",
        message: Uint8List.fromList('Hello World'.codeUnits),
      );
      
      expect(signResponse.signatureHex, startsWith('0x'));
      expect(signResponse.address, startsWith('0x'));
    });
  });
  
  group('Trezor Signer', () {
    late MockTrezorTransport transport;
    late TrezorClient client;
    late TrezorSigner signer;
    
    setUp(() async {
      transport = createMockTrezorTransport();
      client = TrezorClient(transport);
      await client.connect();
      signer = await TrezorSigner.create(client: client);
    });
    
    tearDown(() {
      client.dispose();
    });
    
    test('should have valid address', () {
      expect(signer.address.hex, startsWith('0x'));
      expect(signer.address.hex.length, equals(42));
    });
    
    test('should check connection state', () async {
      expect(await signer.isConnected(), isTrue);
      
      await signer.disconnect();
      expect(await signer.isConnected(), isFalse);
    });
    
    test('should get multiple addresses', () async {
      final addresses = await signer.getAddresses();
      
      expect(addresses.length, equals(5));
      for (final address in addresses) {
        expect(address.hex, startsWith('0x'));
        expect(address.hex.length, equals(42));
      }
    });
    
    test('should sign transaction', () async {
      final transaction = TransactionRequest(
        to: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        value: EthUnit.ether('1.0'),
        gasLimit: BigInt.from(21000),
        gasPrice: EthUnit.gwei('20'),
        nonce: BigInt.from(42),
        chainId: 1,
        type: TransactionType.legacy,
      );
      
      final signature = await signer.signTransaction(transaction);
      
      expect(signature, isA<Uint8List>());
      expect(signature.length, greaterThan(0));
      
      // Convert to hex for additional validation
      final signatureHex = HexUtils.encode(signature);
      expect(signatureHex, startsWith('0x'));
      expect(signatureHex.length, greaterThan(10));
    });
    
    test('should sign message', () async {
      final signature = await signer.signMessage('Hello World');
      
      expect(signature, isA<Uint8List>());
      expect(signature.length, greaterThan(0));
      
      // Convert to hex for additional validation
      final signatureHex = HexUtils.encode(signature);
      expect(signatureHex, startsWith('0x'));
      expect(signatureHex.length, greaterThan(10));
    });
    
    test('should throw for unsupported operations', () async {
      final typedData = abi.TypedData(
        domain: {'name': 'Test'},
        types: {
          'Test': [
            abi.TypedDataField(name: 'value', type: 'uint256'),
          ],
        },
        primaryType: 'Test',
        message: {'value': 123},
      );
      
      expect(
        () => signer.signTypedData(typedData),
        throwsA(isA<TrezorException>()),
      );
      
      final authorization = Authorization(
        chainId: 1,
        address: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        nonce: BigInt.zero,
        yParity: 0,
        r: BigInt.zero,
        s: BigInt.zero,
      );
      
      expect(
        () => signer.signAuthorization(authorization),
        throwsA(isA<TrezorException>()),
      );
    });
  });
  
  group('Trezor Types', () {
    test('should create TrezorDevice', () {
      final device = TrezorDevice(
        deviceId: 'test-device',
        model: 'Trezor Model T',
        label: 'My Trezor',
        firmwareVersion: '2.1.0',
      );
      
      expect(device.deviceId, equals('test-device'));
      expect(device.model, equals('Trezor Model T'));
      expect(device.firmwareVersion, equals('2.1.0'));
    });
    
    test('should create TrezorFeatures', () {
      final features = TrezorFeatures(
        vendor: 'trezor.io',
        majorVersion: 2,
        minorVersion: 1,
        patchVersion: 0,
        bootloaderMode: false,
        pinProtection: true,
        passphraseProtection: false,
        initialized: true,
        coins: [0, 60], // Bitcoin and Ethereum
      );
      
      expect(features.firmwareVersion, equals('2.1.0'));
      expect(features.supportsEthereum, isTrue);
    });
    
    test('should handle TrezorException', () {
      final exception = TrezorException(
        TrezorErrorType.deviceNotFound,
        'Device not found',
        code: 404,
      );
      
      expect(exception.type, equals(TrezorErrorType.deviceNotFound));
      expect(exception.message, equals('Device not found'));
      expect(exception.code, equals(404));
      expect(exception.toString(), contains('TrezorException'));
    });
  });
}
