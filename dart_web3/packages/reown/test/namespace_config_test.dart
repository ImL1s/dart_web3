import 'package:dart_web3_reown/dart_web3_reown.dart';
import 'package:test/test.dart';

void main() {
  group('NamespaceConfig', () {
    test('should create namespace config correctly', () {
      final config = NamespaceConfig(
        namespace: 'eip155',
        chains: ['eip155:1', 'eip155:137'],
        methods: ['eth_sendTransaction', 'personal_sign'],
        events: ['chainChanged', 'accountsChanged'],
        accounts: ['eip155:1:0x123'],
      );
      
      expect(config.namespace, equals('eip155'));
      expect(config.chains, hasLength(2));
      expect(config.methods, hasLength(2));
      expect(config.events, hasLength(2));
      expect(config.accounts, hasLength(1));
    });

    test('should convert to and from JSON', () {
      final config = NamespaceConfig(
        namespace: 'eip155',
        chains: ['eip155:1'],
        methods: ['eth_sendTransaction'],
        events: ['chainChanged'],
        accounts: ['eip155:1:0x123'],
      );
      
      final json = config.toJson();
      final restored = NamespaceConfig.fromJson('eip155', json);
      
      expect(restored.namespace, equals(config.namespace));
      expect(restored.chains, equals(config.chains));
      expect(restored.methods, equals(config.methods));
      expect(restored.events, equals(config.events));
      expect(restored.accounts, equals(config.accounts));
    });

    test('should check chain support correctly', () {
      final config = NamespaceConfig(
        namespace: 'eip155',
        chains: ['eip155:1', 'eip155:137'],
        methods: [],
        events: [],
      );
      
      expect(config.supportsChain('1'), isTrue);
      expect(config.supportsChain('137'), isTrue);
      expect(config.supportsChain('56'), isFalse);
    });

    test('should check method support correctly', () {
      final config = NamespaceConfig(
        namespace: 'eip155',
        chains: [],
        methods: ['eth_sendTransaction', 'personal_sign'],
        events: [],
      );
      
      expect(config.supportsMethod('eth_sendTransaction'), isTrue);
      expect(config.supportsMethod('personal_sign'), isTrue);
      expect(config.supportsMethod('eth_signTypedData'), isFalse);
    });

    test('should add and remove accounts', () {
      final config = NamespaceConfig(
        namespace: 'eip155',
        chains: [],
        methods: [],
        events: [],
        accounts: ['eip155:1:0x123'],
      );
      
      final withNewAccount = config.addAccount('eip155:1:0x456');
      expect(withNewAccount.accounts, hasLength(2));
      expect(withNewAccount.accounts, contains('eip155:1:0x456'));
      
      final withRemovedAccount = withNewAccount.removeAccount('eip155:1:0x123');
      expect(withRemovedAccount.accounts, hasLength(1));
      expect(withRemovedAccount.accounts, isNot(contains('eip155:1:0x123')));
    });
  });

  group('NamespaceConfigs', () {
    test('should create Ethereum namespace config', () {
      final config = NamespaceConfigs.ethereum();
      
      expect(config.namespace, equals('eip155'));
      expect(config.chains, contains('eip155:1'));
      expect(config.methods, contains('eth_sendTransaction'));
      expect(config.events, contains('chainChanged'));
    });

    test('should create multi-chain config', () {
      final configs = NamespaceConfigs.multiChain(
        includePolygon: true,
        includeSolana: true,
      );
      
      expect(configs, hasLength(3));
      expect(configs.any((c) => c.namespace == 'eip155'), isTrue);
      expect(configs.any((c) => c.namespace == 'solana'), isTrue);
    });

    test('should create custom EVM config', () {
      final config = NamespaceConfigs.customEvm(
        chainIds: ['1', '137', '56'],
      );
      
      expect(config.namespace, equals('eip155'));
      expect(config.chains, hasLength(3));
      expect(config.chains, contains('eip155:1'));
      expect(config.chains, contains('eip155:137'));
      expect(config.chains, contains('eip155:56'));
    });
  });

  group('CaipUtils', () {
    test('should parse chain ID correctly', () {
      final (namespace, reference) = CaipUtils.parseChainId('eip155:1');
      
      expect(namespace, equals('eip155'));
      expect(reference, equals('1'));
    });

    test('should parse account ID correctly', () {
      final (namespace, reference, address) = CaipUtils.parseAccountId('eip155:1:0x123');
      
      expect(namespace, equals('eip155'));
      expect(reference, equals('1'));
      expect(address, equals('0x123'));
    });

    test('should create chain ID correctly', () {
      final chainId = CaipUtils.createChainId('eip155', '1');
      expect(chainId, equals('eip155:1'));
    });

    test('should create account ID correctly', () {
      final accountId = CaipUtils.createAccountId('eip155', '1', '0x123');
      expect(accountId, equals('eip155:1:0x123'));
    });

    test('should extract chain ID from account ID', () {
      final chainId = CaipUtils.getChainIdFromAccount('eip155:1:0x123');
      expect(chainId, equals('eip155:1'));
    });

    test('should extract address from account ID', () {
      final address = CaipUtils.getAddressFromAccount('eip155:1:0x123');
      expect(address, equals('0x123'));
    });

    test('should validate CAIP formats', () {
      expect(CaipUtils.isValidChainId('eip155:1'), isTrue);
      expect(CaipUtils.isValidChainId('invalid'), isFalse);
      
      expect(CaipUtils.isValidAccountId('eip155:1:0x123'), isTrue);
      expect(CaipUtils.isValidAccountId('invalid'), isFalse);
    });

    test('should throw on invalid formats', () {
      expect(() => CaipUtils.parseChainId('invalid'), throwsArgumentError);
      expect(() => CaipUtils.parseAccountId('invalid'), throwsArgumentError);
    });
  });
}
