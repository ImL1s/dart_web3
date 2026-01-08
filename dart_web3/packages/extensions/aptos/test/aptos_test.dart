import 'package:test/test.dart';
import 'package:web3_universal_aptos/web3_universal_aptos.dart';

void main() {
  group('AptosAddress', () {
    test('should create from hex string', () {
      final address = AptosAddress.fromHex(
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
      expect(address.bytes.length, equals(32));
    });

    test('should handle 0x prefix', () {
      final withPrefix = AptosAddress.fromHex('0x1');
      final withoutPrefix = AptosAddress.fromHex('1');
      expect(withPrefix.toFullHex(), equals(withoutPrefix.toFullHex()));
    });

    test('should pad short addresses', () {
      final address = AptosAddress.fromHex('0x1');
      expect(
        address.toFullHex(),
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        ),
      );
    });

    test('should display short format correctly', () {
      final address = AptosAddress.fromHex('0x1');
      expect(address.toHex(), equals('0x01'));
    });

    test('should convert to short string', () {
      final address = AptosAddress.fromHex(
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
      final short = address.toShortString();
      expect(short, contains('...'));
      expect(short.length, lessThan(address.toFullHex().length));
    });

    test('should support equality', () {
      final addr1 = AptosAddress.fromHex('0x1');
      final addr2 = AptosAddress.fromHex('0x1');
      final addr3 = AptosAddress.fromHex('0x2');
      expect(addr1, equals(addr2));
      expect(addr1, isNot(equals(addr3)));
    });

    test('should have framework address', () {
      expect(AptosAddress.framework.toHex(), equals('0x01'));
    });
  });

  group('AptosTypeTag', () {
    test('should have built-in types', () {
      expect(AptosTypeTag.u64.value, equals('u64'));
      expect(AptosTypeTag.address.value, equals('address'));
      expect(AptosTypeTag.bool_.value, equals('bool'));
    });

    test('should create vector type', () {
      final vecU64 = AptosTypeTag.vector(AptosTypeTag.u64);
      expect(vecU64.value, equals('vector<u64>'));
    });

    test('should create struct type', () {
      final coinType = AptosTypeTag.struct_('0x1', 'coin', 'CoinStore', [
        AptosTypeTag.struct_('0x1', 'aptos_coin', 'AptosCoin'),
      ]);
      expect(coinType.value, contains('0x1::coin::CoinStore'));
      expect(coinType.value, contains('0x1::aptos_coin::AptosCoin'));
    });

    test('should have APT coin type', () {
      expect(AptosTypeTag.aptCoin.value, contains('aptos_coin::AptosCoin'));
    });
  });

  group('AptosChains', () {
    test('should have mainnet configuration', () {
      expect(AptosChains.mainnet.name, equals('Aptos Mainnet'));
      expect(AptosChains.mainnet.chainId, equals(1));
      expect(AptosChains.mainnet.rpcUrl, contains('mainnet'));
      expect(AptosChains.mainnet.isTestnet, isFalse);
    });

    test('should have testnet configuration', () {
      expect(AptosChains.testnet.name, equals('Aptos Testnet'));
      expect(AptosChains.testnet.chainId, equals(2));
      expect(AptosChains.testnet.rpcUrl, contains('testnet'));
      expect(AptosChains.testnet.isTestnet, isTrue);
      expect(AptosChains.testnet.faucetUrl, isNotNull);
    });

    test('should have devnet configuration', () {
      expect(AptosChains.devnet.name, equals('Aptos Devnet'));
      expect(AptosChains.devnet.chainId, equals(58));
      expect(AptosChains.devnet.rpcUrl, contains('devnet'));
      expect(AptosChains.devnet.isTestnet, isTrue);
    });

    test('should have local configuration', () {
      expect(AptosChains.local.name, equals('Aptos Local'));
      expect(AptosChains.local.rpcUrl, contains('127.0.0.1'));
    });

    test('all should contain all networks', () {
      expect(AptosChains.all.length, equals(4));
    });

    test('getById should return correct chain', () {
      expect(AptosChains.getById(1), equals(AptosChains.mainnet));
      expect(AptosChains.getById(2), equals(AptosChains.testnet));
      expect(AptosChains.getById(999), isNull);
    });
  });

  group('AptosAccount', () {
    test('should parse from JSON', () {
      final account = AptosAccount.fromJson({
        'sequence_number': '42',
        'authentication_key':
            '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      });
      expect(account.sequenceNumber, equals(BigInt.from(42)));
      expect(account.authenticationKey, contains('0x1234'));
    });
  });

  group('AptosCoinStore', () {
    test('should parse from JSON', () {
      final coinStore = AptosCoinStore.fromJson({
        'coin': {'value': '1000000000'},
        'frozen': false,
      });
      expect(coinStore.coin.value, equals(BigInt.from(1000000000)));
      expect(coinStore.frozen, isFalse);
    });
  });

  group('AptosLedgerInfo', () {
    test('should parse from JSON', () {
      final info = AptosLedgerInfo.fromJson({
        'chain_id': 1,
        'epoch': '100',
        'ledger_version': '50000000',
        'oldest_ledger_version': '0',
        'ledger_timestamp': '1700000000000000',
        'node_role': 'full_node',
        'oldest_block_height': '0',
        'block_height': '10000000',
        'git_hash': 'abc123',
      });
      expect(info.chainId, equals(1));
      expect(info.epoch, equals(BigInt.from(100)));
      expect(info.blockHeight, equals(BigInt.from(10000000)));
    });
  });

  group('AptosGasEstimation', () {
    test('should parse from JSON', () {
      final estimation = AptosGasEstimation.fromJson({
        'gas_estimate': 100,
        'deprioritized_gas_estimate': 50,
        'prioritized_gas_estimate': 200,
      });
      expect(estimation.gasEstimate, equals(100));
      expect(estimation.deprioritizedGasEstimate, equals(50));
      expect(estimation.prioritizedGasEstimate, equals(200));
    });
  });

  group('EntryFunctionPayload', () {
    test('should create transfer payload', () {
      final payload = AptosPayloads.transferApt(
        to: AptosAddress.fromHex('0x2'),
        amount: BigInt.from(1000000),
      );
      expect(payload.function, equals('0x1::aptos_account::transfer'));
      expect(payload.typeArguments, isEmpty);
      expect(payload.arguments.length, equals(2));
    });

    test('should convert to JSON', () {
      final payload = EntryFunctionPayload(
        function: '0x1::coin::transfer',
        typeArguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: ['0x2', '1000000'],
      );
      final json = payload.toJson();
      expect(json['type'], equals('entry_function_payload'));
      expect(json['function'], equals('0x1::coin::transfer'));
    });
  });

  group('AptosTransactionBuilder', () {
    test('should build simple transaction', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );

      final tx = builder
          .sequenceNumber(BigInt.zero)
          .maxGasAmount(BigInt.from(10000))
          .gasUnitPrice(BigInt.from(100))
          .expiresIn(const Duration(seconds: 30))
          .entryFunction(
            function: '0x1::aptos_account::transfer',
            arguments: ['0x2', '1000000'],
          )
          .build();

      expect(tx.sender, equals(AptosAddress.fromHex('0x1')));
      expect(tx.sequenceNumber, equals(BigInt.zero));
      expect(tx.chainId, equals(1));
    });

    test('should throw without sequence number', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.entryFunction(function: '0x1::test::test');
      expect(() => builder.build(), throwsStateError);
    });

    test('should throw without payload', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.sequenceNumber(BigInt.zero);
      expect(() => builder.build(), throwsStateError);
    });
  });

  group('AptosSignatureScheme', () {
    test('should have correct values', () {
      expect(AptosSignatureScheme.ed25519.value, equals(0));
      expect(AptosSignatureScheme.multiEd25519.value, equals(1));
      expect(AptosSignatureScheme.singleKey.value, equals(2));
      expect(AptosSignatureScheme.multiKey.value, equals(3));
    });
  });

  group('AptosPublicKeyType', () {
    test('should have correct values', () {
      expect(AptosPublicKeyType.ed25519.value, equals(0));
      expect(AptosPublicKeyType.secp256k1Ecdsa.value, equals(1));
      expect(AptosPublicKeyType.secp256r1Ecdsa.value, equals(2));
      expect(AptosPublicKeyType.keyless.value, equals(3));
    });
  });

  group('AptosClient', () {
    test('should create from chain config', () {
      final client = AptosClient.fromChain(AptosChains.mainnet);
      expect(client.rpcUrl, equals(AptosChains.mainnet.rpcUrl));
      client.close();
    });

    test('should create mainnet client', () {
      final client = AptosClient.mainnet();
      expect(client.rpcUrl, contains('mainnet'));
      client.close();
    });

    test('should create testnet client', () {
      final client = AptosClient.testnet();
      expect(client.rpcUrl, contains('testnet'));
      client.close();
    });

    test('should create devnet client', () {
      final client = AptosClient.devnet();
      expect(client.rpcUrl, contains('devnet'));
      client.close();
    });
  });

  group('AptosTransactionResponse', () {
    test('should parse from JSON', () {
      final response = AptosTransactionResponse.fromJson({
        'version': '12345',
        'hash': '0xabc123',
        'state_change_hash': '0xdef456',
        'event_root_hash': '0x789',
        'state_checkpoint_hash': '0xcheckpoint',
        'gas_used': '100',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0xaccumulator',
        'timestamp': '1700000000000000',
      });
      expect(response.version, equals(BigInt.from(12345)));
      expect(response.success, isTrue);
      expect(response.gasUsed, equals(BigInt.from(100)));
    });
  });

  group('AptosEvent', () {
    test('should parse from JSON', () {
      final event = AptosEvent.fromJson({
        'guid': {
          'creation_number': '1',
          'account_address': '0x1',
        },
        'sequence_number': '0',
        'type': '0x1::coin::DepositEvent',
        'data': {'amount': '1000'},
      });
      expect(event.type, equals('0x1::coin::DepositEvent'));
      expect(event.sequenceNumber, equals(BigInt.zero));
    });
  });

  group('AptosBlock', () {
    test('should parse from JSON', () {
      final block = AptosBlock.fromJson({
        'block_height': '1000000',
        'block_hash': '0xblockhash',
        'block_timestamp': '1700000000000000',
        'first_version': '5000000',
        'last_version': '5001000',
      });
      expect(block.blockHeight, equals(BigInt.from(1000000)));
      expect(block.firstVersion, equals(BigInt.from(5000000)));
    });
  });

  group('AptosPayloads', () {
    test('should create APT transfer payload', () {
      final payload = AptosPayloads.transferApt(
        to: AptosAddress.fromHex('0x123'),
        amount: BigInt.from(100000000), // 1 APT
      );
      expect(payload.function, contains('transfer'));
    });

    test('should create coin transfer payload', () {
      final payload = AptosPayloads.transferCoin(
        coinType: '0x1::aptos_coin::AptosCoin',
        to: AptosAddress.fromHex('0x123'),
        amount: BigInt.from(100000000),
      );
      expect(payload.function, contains('transfer_coins'));
      expect(payload.typeArguments, contains('0x1::aptos_coin::AptosCoin'));
    });

    test('should create coin register payload', () {
      final payload = AptosPayloads.registerCoin(
        coinType: '0x1::aptos_coin::AptosCoin',
      );
      expect(payload.function, contains('register'));
    });
  });
}
