import 'package:dart_web3_sui/dart_web3_sui.dart';
import 'package:test/test.dart';

void main() {
  group('SuiAddress', () {
    test('should create from hex string', () {
      final address = SuiAddress.fromHex(
        '0x02a212de6a9dfa3a69e22387acfbafbb1a9e591bd9d636e7895dcfc8de05f331',
      );
      expect(address.bytes.length, equals(32));
    });

    test('should handle 0x prefix', () {
      final withPrefix = SuiAddress.fromHex('0x1234');
      final withoutPrefix = SuiAddress.fromHex('1234');
      expect(withPrefix.toHex(), equals(withoutPrefix.toHex()));
    });

    test('should pad short addresses', () {
      final address = SuiAddress.fromHex('0x1');
      expect(
        address.toHex(),
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        ),
      );
    });

    test('should convert to short string', () {
      final address = SuiAddress.fromHex(
        '0x02a212de6a9dfa3a69e22387acfbafbb1a9e591bd9d636e7895dcfc8de05f331',
      );
      final short = address.toShortString();
      expect(short, contains('...'));
      expect(short.length, lessThan(address.toHex().length));
    });

    test('should support equality', () {
      final addr1 = SuiAddress.fromHex('0x1');
      final addr2 = SuiAddress.fromHex('0x1');
      final addr3 = SuiAddress.fromHex('0x2');
      expect(addr1, equals(addr2));
      expect(addr1, isNot(equals(addr3)));
    });
  });

  group('SuiTypeTag', () {
    test('should have built-in types', () {
      expect(SuiTypeTag.u64.value, equals('u64'));
      expect(SuiTypeTag.address.value, equals('address'));
      expect(SuiTypeTag.bool_.value, equals('bool'));
    });

    test('should create vector type', () {
      final vecU64 = SuiTypeTag.vector(SuiTypeTag.u64);
      expect(vecU64.value, equals('vector<u64>'));
    });

    test('should create struct type', () {
      final coinType = SuiTypeTag.struct_('0x2', 'coin', 'Coin', [
        SuiTypeTag.struct_('0x2', 'sui', 'SUI'),
      ]);
      expect(coinType.value, contains('0x2::coin::Coin'));
      expect(coinType.value, contains('0x2::sui::SUI'));
    });
  });

  group('SuiOwner', () {
    test('should create AddressOwner', () {
      final owner = AddressOwner(SuiAddress.fromHex('0x1'));
      expect(owner, isA<SuiOwner>());
      expect(owner.address.toHex(), contains('0x'));
    });

    test('should create SharedOwner', () {
      final owner = SharedOwner(initialSharedVersion: BigInt.from(100));
      expect(owner, isA<SuiOwner>());
      expect(owner.initialSharedVersion, equals(BigInt.from(100)));
    });

    test('should create ImmutableOwner', () {
      const owner = ImmutableOwner();
      expect(owner, isA<SuiOwner>());
    });
  });

  group('SuiChains', () {
    test('should have mainnet configuration', () {
      expect(SuiChains.mainnet.name, equals('Sui Mainnet'));
      expect(SuiChains.mainnet.rpcUrl, contains('mainnet'));
      expect(SuiChains.mainnet.isTestnet, isFalse);
    });

    test('should have testnet configuration', () {
      expect(SuiChains.testnet.name, equals('Sui Testnet'));
      expect(SuiChains.testnet.rpcUrl, contains('testnet'));
      expect(SuiChains.testnet.isTestnet, isTrue);
      expect(SuiChains.testnet.faucetUrl, isNotNull);
    });

    test('should have devnet configuration', () {
      expect(SuiChains.devnet.name, equals('Sui Devnet'));
      expect(SuiChains.devnet.rpcUrl, contains('devnet'));
      expect(SuiChains.devnet.isTestnet, isTrue);
    });

    test('should have local configuration', () {
      expect(SuiChains.local.name, equals('Sui Local'));
      expect(SuiChains.local.rpcUrl, contains('127.0.0.1'));
    });

    test('all should contain all networks', () {
      expect(SuiChains.all.length, equals(4));
    });
  });

  group('PureArg', () {
    test('should create u64 argument', () {
      final arg = PureArg.u64(BigInt.from(1000));
      expect(arg.value.length, equals(8));
    });

    test('should create bool argument', () {
      final trueArg = PureArg.bool_(true);
      final falseArg = PureArg.bool_(false);
      expect(trueArg.value[0], equals(1));
      expect(falseArg.value[0], equals(0));
    });

    test('should create address argument', () {
      final address = SuiAddress.fromHex('0x1');
      final arg = PureArg.address(address);
      expect(arg.value.length, equals(32));
    });
  });

  group('SuiCommand types', () {
    test('should create MoveCallCommand', () {
      final cmd = MoveCallCommand(
        package: SuiAddress.fromHex('0x2'),
        module: 'coin',
        function: 'transfer',
        typeArguments: [SuiTypeTag.struct_('0x2', 'sui', 'SUI')],
        arguments: [const InputArg(0), const InputArg(1)],
      );
      expect(cmd.module, equals('coin'));
      expect(cmd.function, equals('transfer'));
    });

    test('should create TransferObjectsCommand', () {
      const cmd = TransferObjectsCommand(
        objects: [ResultArg(0)],
        address: InputArg(1),
      );
      expect(cmd.objects.length, equals(1));
    });

    test('should create SplitCoinsCommand', () {
      const cmd = SplitCoinsCommand(
        coin: GasCoinArg(),
        amounts: [InputArg(0)],
      );
      expect(cmd.coin, isA<GasCoinArg>());
    });
  });

  group('TransactionBlockBuilder', () {
    test('should build simple transaction', () {
      final builder = TransactionBlockBuilder();
      builder.setSender(SuiAddress.fromHex('0x1'));
      builder.setGasData(
        SuiGasData(
          payment: [],
          owner: SuiAddress.fromHex('0x1'),
          price: BigInt.from(1000),
          budget: BigInt.from(10000000),
        ),
      );

      final amountArg = builder.addPure(
        PureArg.u64(BigInt.from(1000000)).value,
      );
      final coins = builder.splitCoins(builder.gas, [amountArg]);

      final recipientArg = builder.addPure(
        PureArg.address(SuiAddress.fromHex('0x2')).value,
      );
      builder.transferObjects(
        [NestedResultArg((coins as ResultArg).index, 0)],
        recipientArg,
      );

      final txData = builder.build();
      expect(txData.kind, isA<ProgrammableTransaction>());
    });

    test('should throw without sender', () {
      final builder = TransactionBlockBuilder();
      builder.setGasData(
        SuiGasData(
          payment: [],
          owner: SuiAddress.fromHex('0x1'),
          price: BigInt.from(1000),
          budget: BigInt.from(10000000),
        ),
      );
      expect(() => builder.build(), throwsStateError);
    });

    test('should throw without gas data', () {
      final builder = TransactionBlockBuilder();
      builder.setSender(SuiAddress.fromHex('0x1'));
      expect(() => builder.build(), throwsStateError);
    });
  });

  group('SuiSignatureScheme', () {
    test('should have correct flag values', () {
      expect(SuiSignatureScheme.ed25519.flag, equals(0));
      expect(SuiSignatureScheme.secp256k1.flag, equals(1));
      expect(SuiSignatureScheme.secp256r1.flag, equals(2));
      expect(SuiSignatureScheme.multiSig.flag, equals(3));
      expect(SuiSignatureScheme.zkLogin.flag, equals(5));
    });
  });

  group('SuiClient', () {
    test('should create from chain config', () {
      final client = SuiClient.fromChain(SuiChains.mainnet);
      expect(client.rpcUrl, equals(SuiChains.mainnet.rpcUrl));
      client.close();
    });

    test('should create mainnet client', () {
      final client = SuiClient.mainnet();
      expect(client.rpcUrl, contains('mainnet'));
      client.close();
    });

    test('should create testnet client', () {
      final client = SuiClient.testnet();
      expect(client.rpcUrl, contains('testnet'));
      client.close();
    });

    test('should create devnet client', () {
      final client = SuiClient.devnet();
      expect(client.rpcUrl, contains('devnet'));
      client.close();
    });
  });

  group('SuiObjectDataOptions', () {
    test('should convert to JSON', () {
      const options = SuiObjectDataOptions(showType: true, showContent: true);
      final json = options.toJson();
      expect(json['showType'], isTrue);
      expect(json['showContent'], isTrue);
      expect(json['showBcs'], isFalse);
    });

    test('full should have all options enabled', () {
      final json = SuiObjectDataOptions.full.toJson();
      expect(json['showType'], isTrue);
      expect(json['showContent'], isTrue);
      expect(json['showBcs'], isTrue);
      expect(json['showOwner'], isTrue);
    });
  });

  group('SuiBalance', () {
    test('should parse from JSON', () {
      final balance = SuiBalance.fromJson({
        'coinType': '0x2::sui::SUI',
        'coinObjectCount': 5,
        'totalBalance': '1000000000',
      });
      expect(balance.coinType, equals('0x2::sui::SUI'));
      expect(balance.coinObjectCount, equals(5));
      expect(balance.totalBalance, equals(BigInt.from(1000000000)));
    });
  });

  group('SuiCoin', () {
    test('should parse from JSON', () {
      final coin = SuiCoin.fromJson({
        'coinType': '0x2::sui::SUI',
        'coinObjectId':
            '0x02a212de6a9dfa3a69e22387acfbafbb1a9e591bd9d636e7895dcfc8de05f331',
        'version': '100',
        'digest': 'DigestPlaceholder',
        'balance': '500000000',
      });
      expect(coin.coinType, equals('0x2::sui::SUI'));
      expect(coin.balance, equals(BigInt.from(500000000)));
    });
  });

  group('SuiSystemState', () {
    test('should parse from JSON', () {
      final state = SuiSystemState.fromJson({
        'epoch': '100',
        'protocolVersion': '50',
        'systemStateVersion': '1',
        'referenceGasPrice': '1000',
      });
      expect(state.epoch, equals(BigInt.from(100)));
      expect(state.protocolVersion, equals(BigInt.from(50)));
      expect(state.referenceGasPrice, equals(BigInt.from(1000)));
    });
  });

  group('SuiTransactionBlockResponseOptions', () {
    test('should convert to JSON', () {
      const options = SuiTransactionBlockResponseOptions(
        showInput: true,
        showEffects: true,
      );
      final json = options.toJson();
      expect(json['showInput'], isTrue);
      expect(json['showEffects'], isTrue);
      expect(json['showEvents'], isFalse);
    });
  });

  group('SuiGasData', () {
    test('should store gas configuration', () {
      final gasData = SuiGasData(
        payment: [],
        owner: SuiAddress.fromHex('0x1'),
        price: BigInt.from(1000),
        budget: BigInt.from(50000000),
      );
      expect(gasData.price, equals(BigInt.from(1000)));
      expect(gasData.budget, equals(BigInt.from(50000000)));
    });
  });
}
