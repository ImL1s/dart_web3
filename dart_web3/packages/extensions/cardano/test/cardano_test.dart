import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3_universal_cardano/web3_universal_cardano.dart';

void main() {
  group('CardanoChains', () {
    test('should have mainnet configuration', () {
      expect(CardanoChains.mainnet.name, equals('Cardano Mainnet'));
      expect(CardanoChains.mainnet.network, equals(CardanoNetwork.mainnet));
      expect(CardanoChains.mainnet.network.networkMagic, equals(764824073));
      expect(CardanoChains.mainnet.isTestnet, isFalse);
    });

    test('should have preprod configuration', () {
      expect(CardanoChains.preprod.name, equals('Cardano Preprod'));
      expect(CardanoChains.preprod.network, equals(CardanoNetwork.preprod));
      expect(CardanoChains.preprod.isTestnet, isTrue);
    });

    test('should have preview configuration', () {
      expect(CardanoChains.preview.name, equals('Cardano Preview'));
      expect(CardanoChains.preview.network, equals(CardanoNetwork.preview));
      expect(CardanoChains.preview.isTestnet, isTrue);
    });

    test('all should contain all networks', () {
      expect(CardanoChains.all.length, equals(3));
    });

    test('getByNetwork should return correct chain', () {
      expect(
        CardanoChains.getByNetwork(CardanoNetwork.mainnet),
        equals(CardanoChains.mainnet),
      );
      expect(
        CardanoChains.getByNetwork(CardanoNetwork.preprod),
        equals(CardanoChains.preprod),
      );
    });
  });

  group('CardanoNetwork', () {
    test('should have correct network magic values', () {
      expect(CardanoNetwork.mainnet.networkMagic, equals(764824073));
      expect(CardanoNetwork.preprod.networkMagic, equals(1));
      expect(CardanoNetwork.preview.networkMagic, equals(2));
    });
  });

  group('CardanoAddress', () {
    test('should parse mainnet address', () {
      final address = CardanoAddress.fromBech32(
        'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp',
      );
      expect(address.isMainnet, isTrue);
      expect(address.type, equals(CardanoAddressType.base));
    });

    test('should parse testnet address', () {
      final address = CardanoAddress.fromBech32(
        'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq3tj9l6',
      );
      expect(address.isMainnet, isFalse);
      expect(address.type, equals(CardanoAddressType.base));
    });

    test('should parse stake address', () {
      final address = CardanoAddress.fromBech32(
        'stake1ux3g2c9dx2nhhehyrezyxpkstartcqmu9hk63qgfkccw5rqttygt7',
      );
      expect(address.type, equals(CardanoAddressType.reward));
    });
  });

  group('CardanoTxHash', () {
    test('should create from hex', () {
      final hash = CardanoTxHash.fromHex(
        'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
      );
      expect(hash.bytes.length, equals(32));
    });

    test('should convert to hex', () {
      final hash = CardanoTxHash.fromHex(
        'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
      );
      expect(
        hash.toHex(),
        equals('a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd'),
      );
    });
  });

  group('CardanoValue', () {
    test('should create and serialize', () {
      final value = CardanoValue(unit: 'lovelace', quantity: BigInt.from(1000000));
      expect(value.unit, equals('lovelace'));
      expect(value.quantity, equals(BigInt.from(1000000)));
      expect(value.isAda, isTrue);
    });

    test('should parse from JSON', () {
      final value = CardanoValue.fromJson({
        'unit': 'lovelace',
        'quantity': '5000000',
      });
      expect(value.quantity, equals(BigInt.from(5000000)));
    });
  });

  group('CardanoMultiAsset', () {
    test('should create lovelace only', () {
      final value = CardanoMultiAsset.lovelace(BigInt.from(1000000));
      expect(value.coin, equals(BigInt.from(1000000)));
      expect(value.multiAsset, isNull);
    });

    test('should add values', () {
      final value1 = CardanoMultiAsset.lovelace(BigInt.from(1000000));
      final value2 = CardanoMultiAsset.lovelace(BigInt.from(500000));
      final result = value1 + value2;
      expect(result.coin, equals(BigInt.from(1500000)));
    });
  });

  group('CardanoUtxo', () {
    test('should parse from JSON', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash': 'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
      });
      expect(utxo.outputIndex, equals(0));
      expect(utxo.lovelace, equals(BigInt.from(5000000)));
    });
  });

  group('CardanoBlock', () {
    test('should parse from JSON', () {
      final block = CardanoBlock.fromJson({
        'hash': 'abc123',
        'height': 1000000,
        'slot': 50000000,
        'epoch': 400,
        'epoch_slot': 1000,
        'time': 1700000000,
        'tx_count': 50,
        'size': 10000,
      });
      expect(block.height, equals(1000000));
      expect(block.epoch, equals(400));
      expect(block.txCount, equals(50));
    });
  });

  group('CardanoProtocolParams', () {
    test('should parse from JSON', () {
      final params = CardanoProtocolParams.fromJson({
        'min_fee_a': 44,
        'min_fee_b': 155381,
        'max_tx_size': 16384,
        'max_val_size': 5000,
        'key_deposit': '2000000',
        'pool_deposit': '500000000',
        'coins_per_utxo_size': '4310',
        'price_mem': '0.0577',
        'price_step': '0.0000721',
        'collateral_percent': 150,
        'max_collateral_inputs': 3,
      });
      expect(params.minFeeA, equals(44));
      expect(params.minFeeB, equals(155381));
      expect(params.keyDeposit, equals(BigInt.from(2000000)));
    });
  });

  group('CardanoTxInput', () {
    test('should create from UTxO', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash': 'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 1,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
      });
      final input = CardanoTxInput.fromUtxo(utxo);
      expect(input.index, equals(1));
    });
  });

  group('CardanoTxOutput', () {
    test('should create output', () {
      final output = CardanoTxOutput(
        address: CardanoAddress.fromBech32('addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp'),
        amount: CardanoMultiAsset.lovelace(BigInt.from(2000000)),
      );
      expect(output.amount.coin, equals(BigInt.from(2000000)));
    });
  });

  group('CardanoPlutusData', () {
    test('should create integer', () {
      final data = PlutusInteger(BigInt.from(42));
      final cbor = data.toCbor();
      expect(cbor['int'], equals('42'));
    });

    test('should create bytes', () {
      final data = PlutusBytes(Uint8List.fromList([1, 2, 3]));
      final cbor = data.toCbor();
      expect(cbor['bytes'], isNotNull);
    });

    test('should create list', () {
      final data = PlutusList([
        PlutusInteger(BigInt.from(1)),
        PlutusInteger(BigInt.from(2)),
      ]);
      final cbor = data.toCbor();
      expect((cbor['list'] as List).length, equals(2));
    });

    test('should create constructor', () {
      final data = PlutusConstr(
        constructor: 0,
        fields: [PlutusInteger(BigInt.from(42))],
      );
      final cbor = data.toCbor();
      expect(cbor['constructor'], equals(0));
    });
  });

  group('CardanoTxBuilder', () {
    test('should build transaction', () {
      final params = CardanoProtocolParams(
        minFeeA: 44,
        minFeeB: 155381,
        maxTxSize: 16384,
        maxValSize: 5000,
        keyDeposit: BigInt.from(2000000),
        poolDeposit: BigInt.from(500000000),
        coinsPerUtxoSize: BigInt.from(4310),
        priceMem: 0.0577,
        priceStep: 0.0000721,
        collateralPercent: 150,
        maxCollateralInputs: 3,
      );

      final builder = CardanoTxBuilder(protocolParams: params);
      builder.addInput(CardanoTxInput(
        txHash: CardanoTxHash.fromHex(
          'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        ),
        index: 0,
      ));
      builder.addOutput(CardanoTxOutput(
        address: CardanoAddress.fromBech32('addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp'),
        amount: CardanoMultiAsset.lovelace(BigInt.from(2000000)),
      ));
      builder.setFee(BigInt.from(200000));

      final body = builder.build();
      expect(body.inputs.length, equals(1));
      expect(body.outputs.length, equals(1));
      expect(body.fee, equals(BigInt.from(200000)));
    });

    test('should throw without inputs', () {
      final params = CardanoProtocolParams(
        minFeeA: 44,
        minFeeB: 155381,
        maxTxSize: 16384,
        maxValSize: 5000,
        keyDeposit: BigInt.from(2000000),
        poolDeposit: BigInt.from(500000000),
        coinsPerUtxoSize: BigInt.from(4310),
        priceMem: 0.0577,
        priceStep: 0.0000721,
        collateralPercent: 150,
        maxCollateralInputs: 3,
      );

      final builder = CardanoTxBuilder(protocolParams: params);
      builder.setFee(BigInt.from(200000));
      expect(() => builder.build(), throwsStateError);
    });

    test('should calculate min fee', () {
      final params = CardanoProtocolParams(
        minFeeA: 44,
        minFeeB: 155381,
        maxTxSize: 16384,
        maxValSize: 5000,
        keyDeposit: BigInt.from(2000000),
        poolDeposit: BigInt.from(500000000),
        coinsPerUtxoSize: BigInt.from(4310),
        priceMem: 0.0577,
        priceStep: 0.0000721,
        collateralPercent: 150,
        maxCollateralInputs: 3,
      );

      final builder = CardanoTxBuilder(protocolParams: params);
      final fee = builder.calculateMinFee(300);
      expect(fee, equals(BigInt.from(44 * 300 + 155381)));
    });
  });

  group('NativeScript', () {
    test('should create sig script', () {
      final script = NativeScript(
        type: NativeScriptType.sig,
        keyHash: Uint8List(28),
      );
      final cbor = script.toCbor();
      expect(cbor['type'], equals('sig'));
    });

    test('should create all script', () {
      final script = NativeScript(
        type: NativeScriptType.all,
        scripts: [
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
        ],
      );
      final cbor = script.toCbor();
      expect(cbor['type'], equals('all'));
    });
  });

  group('CardanoCertificate', () {
    test('should create stake registration', () {
      final cert = StakeRegistration(Uint8List(28));
      final cbor = cert.toCbor();
      expect(cbor['type'], equals('stake_registration'));
    });

    test('should create stake delegation', () {
      final cert = StakeDelegation(
        stakeCredential: Uint8List(28),
        poolKeyHash: Uint8List(28),
      );
      final cbor = cert.toCbor();
      expect(cbor['type'], equals('stake_delegation'));
    });
  });

  group('ExUnits', () {
    test('should convert to CBOR', () {
      final units = ExUnits(mem: BigInt.from(1000000), steps: BigInt.from(500000000));
      final cbor = units.toCbor();
      expect(cbor['mem'], equals('1000000'));
      expect(cbor['steps'], equals('500000000'));
    });
  });

  group('RedeemerTag', () {
    test('should have correct values', () {
      expect(RedeemerTag.spend.name, equals('spend'));
      expect(RedeemerTag.mint.name, equals('mint'));
      expect(RedeemerTag.cert.name, equals('cert'));
      expect(RedeemerTag.reward.name, equals('reward'));
    });
  });

  group('CardanoClient', () {
    test('should create Blockfrost client', () {
      final client = CardanoClient.blockfrost(
        baseUrl: CardanoChains.mainnet.blockfrostUrl,
        apiKey: 'test-api-key',
      );
      expect(client.apiKey, equals('test-api-key'));
      client.close();
    });

    test('should create Koios client', () {
      final client = CardanoClient.koios(
        baseUrl: CardanoChains.mainnet.koiosUrl,
      );
      expect(client.apiKey, isNull);
      client.close();
    });

    test('should create from chain config', () {
      final client = CardanoClient.fromChain(CardanoChains.mainnet);
      expect(client.apiKey, isNull); // Koios by default
      client.close();
    });
  });
}
