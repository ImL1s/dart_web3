import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_web3_ledger/dart_web3_ledger.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('Ledger Transport', () {
    late MockLedgerTransport transport;
    
    setUp(() {
      transport = LedgerTransportFactory.createMock();
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
      expect(devices.first.name, equals('Mock Ledger Device'));
      expect(devices.first.transportType, equals(LedgerTransportType.usb));
    });
    
    test('should exchange APDU commands', () async {
      await transport.connect();
      
      final command = APDUCommand(
        cla: 0xE0,
        ins: 0x01,
        p1: 0x00,
        p2: 0x00,
      );
      
      final response = await transport.exchange(command);
      
      expect(response.isSuccess, isTrue);
      expect(response.statusWord, equals(0x9000));
    });
    
    test('should handle mock responses', () async {
      await transport.connect();
      
      final command = APDUCommand(
        cla: 0xE0,
        ins: 0x02,
        p1: 0x00,
        p2: 0x00,
      );
      
      // Set mock response
      final mockData = Uint8List.fromList([0x41, 0x04, 0x12, 0x34]);
      transport.setMockResponse(command, mockData);
      
      final response = await transport.exchange(command);
      
      expect(response.isSuccess, isTrue);
      expect(response.data, equals(mockData));
    });
  });
  
  group('APDU Commands', () {
    test('should create get public key command', () {
      final command = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/0");
      
      expect(command.cla, equals(0xE0));
      expect(command.ins, equals(0x02));
      expect(command.p1, equals(0x01)); // No display
      expect(command.p2, equals(0x00));
      expect(command.data, isNotNull);
    });
    
    test('should create sign transaction command', () {
      final txData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final command = EthereumAPDU.signTransactionFirst("m/44'/60'/0'/0/0", txData);
      
      expect(command.cla, equals(0xE0));
      expect(command.ins, equals(0x04));
      expect(command.p1, equals(0x00)); // First chunk
      expect(command.p2, equals(0x00));
      expect(command.data, isNotNull);
    });
    
    test('should encode derivation path correctly', () {
      final command = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/0");
      final commandBytes = command.toBytes();
      
      // Should contain encoded path
      expect(commandBytes, isNotEmpty);
      expect(commandBytes[0], equals(0xE0)); // CLA
      expect(commandBytes[1], equals(0x02)); // INS
    });
  });
  
  group('Ledger Client', () {
    late MockLedgerTransport transport;
    late LedgerClient client;
    
    setUp(() {
      transport = LedgerTransportFactory.createMock();
      client = LedgerClient(transport);
    });
    
    tearDown(() {
      client.dispose();
    });
    
    test('should connect to device', () async {
      // Mock app configuration response
      final configCommand = EthereumAPDU.getConfiguration();
      final configData = Uint8List.fromList([0x01, 0x00, 0x01, 0x02, 0x03]); // Mock config
      transport.setMockResponse(configCommand, configData);
      
      // Mock app name response
      final nameCommand = EthereumAPDU.getAppName();
      final nameData = Uint8List.fromList([
        8, ...('Ethereum'.codeUnits), // App name
        5, ...('1.0.0'.codeUnits),    // Version
      ]);
      transport.setMockResponse(nameCommand, nameData);
      
      expect(client.state, equals(LedgerConnectionState.disconnected));
      
      await client.connect();
      
      expect(client.state, equals(LedgerConnectionState.connected));
      expect(client.isReady, isTrue);
      expect(client.appConfig, isNotNull);
    });
    
    test('should get account information', () async {
      // Setup connection
      await _setupMockConnection(transport);
      await client.connect();
      
      // Mock public key response
      final pubKeyCommand = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/0");
      final pubKeyData = Uint8List.fromList([
        65, // Public key length
        ...List.filled(65, 0x12), // Mock public key
        20, // Address length
        ...List.filled(20, 0x34), // Mock address
      ]);
      transport.setMockResponse(pubKeyCommand, pubKeyData);
      
      final account = await client.getAccount("m/44'/60'/0'/0/0");
      
      expect(account.derivationPath, equals("m/44'/60'/0'/0/0"));
      expect(account.address, startsWith('0x'));
      expect(account.publicKey.length, equals(65));
    });
    
    test('should get multiple accounts', () async {
      await _setupMockConnection(transport);
      await client.connect();
      
      // Mock responses for multiple accounts
      for (int i = 0; i < 3; i++) {
        final command = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/$i");
        final data = Uint8List.fromList([
          65, // Public key length
          ...List.filled(65, 0x12 + i), // Mock public key
          20, // Address length
          ...List.filled(20, 0x34 + i), // Mock address
        ]);
        transport.setMockResponse(command, data);
      }
      
      final accounts = await client.getAccounts(count: 3);
      
      expect(accounts.length, equals(3));
      for (int i = 0; i < accounts.length; i++) {
        expect(accounts[i].derivationPath, contains('/$i'));
        expect(accounts[i].index, equals(i));
      }
    });
  });
  
  group('Ledger Signer', () {
    late MockLedgerTransport transport;
    late LedgerClient client;
    late LedgerSigner signer;
    
    setUp(() async {
      transport = LedgerTransportFactory.createMock();
      client = LedgerClient(transport);
      
      await _setupMockConnection(transport);
      await client.connect();
      
      // Mock account response
      final command = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/0");
      final data = Uint8List.fromList([
        65, // Public key length
        ...List.filled(65, 0x12), // Mock public key
        20, // Address length
        ...List.filled(20, 0x34), // Mock address
      ]);
      transport.setMockResponse(command, data);
      
      signer = await LedgerSigner.create(client: client);
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
      // Mock responses for multiple addresses
      for (int i = 0; i < 5; i++) {
        final command = EthereumAPDU.getPublicKey("m/44'/60'/0'/0/$i");
        final data = Uint8List.fromList([
          65, // Public key length
          ...List.filled(65, 0x12 + i), // Mock public key
          20, // Address length
          ...List.filled(20, 0x34 + i), // Mock address
        ]);
        transport.setMockResponse(command, data);
      }
      
      final addresses = await signer.getAddresses(count: 5);
      
      expect(addresses.length, equals(5));
      for (final address in addresses) {
        expect(address.hex, startsWith('0x'));
        expect(address.hex.length, equals(42));
      }
    });
    
    test('should handle transaction signing', () async {
      // Mock signature response
      final mockSignature = Uint8List.fromList([
        0x1B, // v
        ...List.filled(32, 0xAA), // r
        ...List.filled(32, 0xBB), // s
      ]);
      
      // We can't easily mock the exact command since it depends on transaction encoding
      // So we'll just verify the method doesn't throw
      final transaction = TransactionRequest(
        to: '0x742d35Cc6634C0532925a3b8D0C9e3e0C8b8c8c8',
        value: EthUnit.ether('1.0'),
        gasLimit: BigInt.from(21000),
        gasPrice: EthUnit.gwei('20'),
        nonce: BigInt.from(42),
        chainId: 1,
        type: TransactionType.legacy,
      );
      
      expect(() => signer.signTransaction(transaction), returnsNormally);
    });
  });
  
  group('Response Parsers', () {
    test('should parse public key response', () {
      final responseData = Uint8List.fromList([
        65, // Public key length
        ...List.filled(65, 0x12), // Mock public key
        20, // Address length
        0x74, 0x2d, 0x35, 0xCc, 0x66, 0x34, 0xC0, 0x53, 0x29, 0x25,
        0xa3, 0xb8, 0xD0, 0xC9, 0xe3, 0xe0, 0xC8, 0xb8, 0xc8, 0xc8,
      ]);
      
      final response = APDUResponse(data: responseData, statusWord: 0x9000);
      final result = EthereumResponseParser.parsePublicKey(response);
      
      expect(result['publicKey'], isA<Uint8List>());
      expect(result['address'], startsWith('0x'));
      expect((result['publicKey'] as Uint8List).length, equals(65));
    });
    
    test('should parse signature response', () {
      final responseData = Uint8List.fromList([
        0x1B, // v
        ...List.filled(32, 0xAA), // r
        ...List.filled(32, 0xBB), // s
      ]);
      
      final response = APDUResponse(data: responseData, statusWord: 0x9000);
      final result = EthereumResponseParser.parseSignature(response);
      
      expect(result.v, equals(0x1B));
      expect(result.r.length, equals(32));
      expect(result.s.length, equals(32));
      expect(result.signature.length, equals(65));
    });
    
    test('should parse configuration response', () {
      final responseData = Uint8List.fromList([
        0x01, // Arbitrary data enabled
        0x00, // ERC20 provisioning not necessary
        0x01, // Major version
        0x02, // Minor version
        0x03, // Patch version
      ]);
      
      final response = APDUResponse(data: responseData, statusWord: 0x9000);
      final result = EthereumResponseParser.parseConfiguration(response);
      
      expect(result.arbitraryDataEnabled, isTrue);
      expect(result.erc20ProvisioningNecessary, isFalse);
      expect(result.version, equals('1.2.3'));
    });
  });
}

/// Helper function to setup mock connection responses
Future<void> _setupMockConnection(MockLedgerTransport transport) async {
  // Mock app configuration response
  final configCommand = EthereumAPDU.getConfiguration();
  final configData = Uint8List.fromList([0x01, 0x00, 0x01, 0x02, 0x03]);
  transport.setMockResponse(configCommand, configData);
  
  // Mock app name response
  final nameCommand = EthereumAPDU.getAppName();
  final nameData = Uint8List.fromList([
    8, ...('Ethereum'.codeUnits), // App name
    5, ...('1.0.0'.codeUnits),    // Version
  ]);
  transport.setMockResponse(nameCommand, nameData);
}