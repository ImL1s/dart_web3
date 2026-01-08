import 'dart:typed_data';
import 'package:web3_universal_cardano/web3_universal_cardano.dart';
import 'package:test/test.dart';

/// Strict edge case and authoritative tests for Cardano extension package.
/// Test vectors derived from CIP-19 and Cardano specifications.
void main() {
  group('CardanoAddress Edge Cases (CIP-19)', () {
    // === CIP-19 Test Vectors ===
    // Reference: https://cips.cardano.org/cips/cip19/

    test('mainnet base address (addr1...)', () {
      final address = CardanoAddress.fromBech32(
        'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp',
      );
      expect(address.isMainnet, isTrue);
      expect(address.type, equals(CardanoAddressType.base));
      expect(address.network, equals(1));
    });

    test('testnet base address (addr_test1...)', () {
      final address = CardanoAddress.fromBech32(
        'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq3tj9l6',
      );
      expect(address.isMainnet, isFalse);
      expect(address.type, equals(CardanoAddressType.base));
      expect(address.network, equals(0));
    });

    test('mainnet stake address (stake1...)', () {
      final address = CardanoAddress.fromBech32(
        'stake1ux3g2c9dx2nhhehyrezyxpkstartcqmu9hk63qgfkccw5rqttygt7',
      );
      expect(address.isMainnet, isTrue);
      expect(address.type, equals(CardanoAddressType.reward));
    });

    test('testnet stake address (stake_test1...)', () {
      final address = CardanoAddress.fromBech32(
        'stake_test1uqfu74w3wh4gfzu8m6e7j987h4lq9r3t7ef5gaw497uu85qsqfy27',
      );
      expect(address.isMainnet, isFalse);
      expect(address.type, equals(CardanoAddressType.reward));
    });

    test('address types have correct header values', () {
      expect(CardanoAddressType.base.header, equals(0));
      expect(CardanoAddressType.pointer.header, equals(4));
      expect(CardanoAddressType.enterprise.header, equals(6));
      expect(CardanoAddressType.reward.header, equals(14));
      expect(CardanoAddressType.byron.header, equals(8));
    });
  });

  group('CardanoTxHash Edge Cases', () {
    test('valid 32-byte hash', () {
      final hash = CardanoTxHash.fromHex(
        'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
      );
      expect(hash.bytes.length, equals(32));
    });

    test('hash with 0x prefix', () {
      final hash = CardanoTxHash.fromHex(
        '0xa1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
      );
      expect(hash.bytes.length, equals(32));
      expect(hash.toHex(), isNot(startsWith('0x')));
    });

    test('hash roundtrip', () {
      const originalHex =
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      final hash = CardanoTxHash.fromHex(originalHex);
      expect(hash.toHex(), equals(originalHex));
    });

    test('zero hash', () {
      final hash = CardanoTxHash(Uint8List(32));
      expect(hash.bytes, everyElement(equals(0)));
      expect(
        hash.toHex(),
        equals(
          '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
    });
  });

  group('CardanoValue Edge Cases', () {
    test('lovelace identification', () {
      final ada = CardanoValue(unit: 'lovelace', quantity: BigInt.from(1000000));
      expect(ada.isAda, isTrue);

      final token = CardanoValue(
        unit: 'abc123def456abc123def456abc123def456abc123def456abc123def456token',
        quantity: BigInt.from(100),
      );
      expect(token.isAda, isFalse);
    });

    test('zero quantity', () {
      final value = CardanoValue(unit: 'lovelace', quantity: BigInt.zero);
      expect(value.quantity, equals(BigInt.zero));
    });

    test('large quantity (max supply)', () {
      // Max ADA supply is 45 billion ADA = 45 * 10^15 lovelace
      final maxSupply = BigInt.parse('45000000000000000');
      final value = CardanoValue(unit: 'lovelace', quantity: maxSupply);
      expect(value.quantity, equals(maxSupply));
    });

    test('JSON serialization preserves precision', () {
      final largeAmount = BigInt.parse('9999999999999999999');
      final value = CardanoValue(unit: 'lovelace', quantity: largeAmount);
      final json = value.toJson();
      expect(json['quantity'], equals('9999999999999999999'));

      final parsed = CardanoValue.fromJson(json);
      expect(parsed.quantity, equals(largeAmount));
    });
  });

  group('CardanoMultiAsset Edge Cases', () {
    test('lovelace only', () {
      final value = CardanoMultiAsset.lovelace(BigInt.from(5000000));
      expect(value.coin, equals(BigInt.from(5000000)));
      expect(value.multiAsset, isNull);
    });

    test('addition of lovelace values', () {
      final v1 = CardanoMultiAsset.lovelace(BigInt.from(1000000));
      final v2 = CardanoMultiAsset.lovelace(BigInt.from(2000000));
      final sum = v1 + v2;
      expect(sum.coin, equals(BigInt.from(3000000)));
    });

    test('zero coin value', () {
      final value = CardanoMultiAsset.lovelace(BigInt.zero);
      expect(value.coin, equals(BigInt.zero));
    });
  });

  group('CardanoUtxo Edge Cases', () {
    test('UTxO with only lovelace', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
      });
      expect(utxo.lovelace, equals(BigInt.from(5000000)));
    });

    test('UTxO with native tokens', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '2000000'},
          {
            'unit':
                'abc123def456abc123def456abc123def456abc123def456abc123def456token',
            'quantity': '100',
          },
        ],
      });
      expect(utxo.lovelace, equals(BigInt.from(2000000)));
      expect(utxo.amount.length, equals(2));
    });

    test('UTxO with inline datum', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
        'inline_datum': {'int': 42},
      });
      expect(utxo.datum, isNotNull);
      expect(utxo.datum!['int'], equals(42));
    });

    test('UTxO with datum hash', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
        'data_hash':
            '9e1199a988ba72ffd6e9c269cadb3b53b5f360ff99f112d9b2ee30c4d74ad88b',
      });
      expect(utxo.datumHash, isNotNull);
    });

    test('UTxO with reference script', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'output_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
        'reference_script_hash':
            'abc123def456abc123def456abc123def456abc123def456abc123def456',
      });
      expect(utxo.scriptRef, isNotNull);
    });

    test('UTxO with tx_index alternate key', () {
      final utxo = CardanoUtxo.fromJson({
        'tx_hash':
            'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        'tx_index': 5,
        'amount': [
          {'unit': 'lovelace', 'quantity': '5000000'},
        ],
      });
      expect(utxo.outputIndex, equals(5));
    });
  });

  group('CardanoAsset Edge Cases', () {
    test('asset with fingerprint', () {
      final asset = CardanoAsset.fromJson({
        'policy_id': 'abc123',
        'asset_name': 'token',
        'quantity': '1000',
        'fingerprint': 'asset1abc123',
      });
      expect(asset.fingerprint, isNotNull);
    });

    test('asset with empty name (ADA handle)', () {
      final asset = CardanoAsset.fromJson({
        'policy_id': 'f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a',
        'quantity': '1',
      });
      expect(asset.assetName, equals(''));
    });

    test('asset with metadata', () {
      final asset = CardanoAsset.fromJson({
        'policy_id': 'abc123',
        'asset_name': 'nft',
        'quantity': '1',
        'onchain_metadata': {
          'name': 'My NFT',
          'image': 'ipfs://...',
        },
      });
      expect(asset.metadata, isNotNull);
      expect(asset.metadata!['name'], equals('My NFT'));
    });
  });

  group('CardanoBlock Edge Cases', () {
    test('block with transactions', () {
      final block = CardanoBlock.fromJson({
        'hash': 'abc123',
        'height': 1000000,
        'slot': 50000000,
        'epoch': 400,
        'epoch_slot': 1000,
        'time': 1700000000,
        'tx_count': 100,
        'size': 50000,
        'previous_block': 'prev123',
      });
      expect(block.height, equals(1000000));
      expect(block.txCount, equals(100));
      expect(block.size, equals(50000));
      expect(block.previousBlock, isNotNull);
    });

    test('genesis block (no previous)', () {
      final block = CardanoBlock.fromJson({
        'hash': 'genesis',
        'height': 0,
        'slot': 0,
        'epoch': 0,
        'epoch_slot': 0,
        'time': 1506203091, // Cardano genesis time
        'tx_count': 0,
      });
      expect(block.height, equals(0));
      expect(block.previousBlock, isNull);
    });

    test('block with alternate key names', () {
      final block = CardanoBlock.fromJson({
        'hash': 'abc123',
        'block_no': 1000000,
        'abs_slot': 50000000,
        'epoch_no': 400,
        'epoch_slot': 1000,
        'block_time': 1700000000,
        'tx_count': 50,
      });
      expect(block.height, equals(1000000));
      expect(block.slot, equals(50000000));
      expect(block.epoch, equals(400));
    });
  });

  group('CardanoEpoch Edge Cases', () {
    test('epoch with all fields', () {
      final epoch = CardanoEpoch.fromJson({
        'epoch': 400,
        'start_time': 1700000000,
        'end_time': 1700432000,
        'first_block_time': 1700000020,
        'last_block_time': 1700431980,
        'block_count': 21600,
        'tx_count': 1000000,
        'output': '50000000000000000',
        'fees': '500000000000',
        'active_stake': '25000000000000000',
      });
      expect(epoch.epoch, equals(400));
      expect(epoch.blockCount, equals(21600));
      expect(epoch.output, equals(BigInt.parse('50000000000000000')));
    });

    test('epoch without active stake', () {
      final epoch = CardanoEpoch.fromJson({
        'epoch': 1,
        'start_time': 1506203091,
        'end_time': 1506635091,
        'first_block_time': 1506203111,
        'last_block_time': 1506635071,
        'block_count': 21600,
        'tx_count': 0,
        'output': '0',
        'fees': '0',
        'active_stake': null,
      });
      expect(epoch.activeStake, isNull);
    });
  });

  group('CardanoPool Edge Cases', () {
    test('pool with all fields', () {
      final pool = CardanoPool.fromJson({
        'pool_id': 'pool1abc123',
        'hex': 'abc123',
        'vrf_key': 'vrf_key_hex',
        'pledge': '1000000000000',
        'fixed_cost': '340000000',
        'margin_cost': '0.05',
        'reward_account': 'stake1abc',
        'metadata': {
          'name': 'Test Pool',
          'ticker': 'TEST',
        },
        'active_stake': '50000000000000',
        'live_stake': '50000000000000',
      });
      expect(pool.poolId, equals('pool1abc123'));
      expect(pool.pledge, equals(BigInt.parse('1000000000000')));
      expect(pool.margin, equals(0.05));
      expect(pool.metadata, isNotNull);
    });

    test('pool with alternate key names', () {
      final pool = CardanoPool.fromJson({
        'pool_id': 'pool1abc123',
        'hex': 'abc123',
        'vrf_key': 'vrf_key_hex',
        'pledge': '1000000000000',
        'cost': '340000000',
        'margin': '0.05',
        'reward_account': 'stake1abc',
      });
      expect(pool.cost, equals(BigInt.from(340000000)));
      expect(pool.margin, equals(0.05));
    });
  });

  group('CardanoProtocolParams Edge Cases', () {
    test('protocol params with all fields', () {
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
      expect(params.maxTxSize, equals(16384));
      expect(params.coinsPerUtxoSize, equals(BigInt.from(4310)));
    });

    test('protocol params with coins_per_utxo_word (legacy)', () {
      final params = CardanoProtocolParams.fromJson({
        'min_fee_a': 44,
        'min_fee_b': 155381,
        'max_tx_size': 16384,
        'key_deposit': '2000000',
        'pool_deposit': '500000000',
        'coins_per_utxo_word': '34482',
        'price_mem': '0.0577',
        'price_step': '0.0000721',
        'collateral_percent': 150,
        'max_collateral_inputs': 3,
      });
      expect(params.coinsPerUtxoSize, equals(BigInt.from(34482)));
    });
  });

  group('PlutusData Edge Cases', () {
    test('PlutusInteger with large value', () {
      final large = BigInt.parse('99999999999999999999999999999');
      final data = PlutusInteger(large);
      final cbor = data.toCbor();
      expect(cbor['int'], equals('99999999999999999999999999999'));
    });

    test('PlutusInteger with negative value', () {
      final data = PlutusInteger(BigInt.from(-42));
      final cbor = data.toCbor();
      expect(cbor['int'], equals('-42'));
    });

    test('PlutusBytes empty', () {
      final data = PlutusBytes(Uint8List(0));
      final cbor = data.toCbor();
      expect((cbor['bytes'] as Uint8List), isEmpty);
    });

    test('PlutusList empty', () {
      final data = PlutusList([]);
      final cbor = data.toCbor();
      expect((cbor['list'] as List), isEmpty);
    });

    test('PlutusMap with entries', () {
      final data = PlutusMap({
        PlutusBytes(Uint8List.fromList([1])): PlutusInteger(BigInt.from(42)),
      });
      final cbor = data.toCbor();
      expect((cbor['map'] as List).length, equals(1));
    });

    test('PlutusConstr with high constructor', () {
      final data = PlutusConstr(
        constructor: 999,
        fields: [PlutusInteger(BigInt.one)],
      );
      final cbor = data.toCbor();
      expect(cbor['constructor'], equals(999));
    });

    test('nested Plutus data structures', () {
      final nested = PlutusList([
        PlutusConstr(
          constructor: 0,
          fields: [
            PlutusMap({
              PlutusInteger(BigInt.zero): PlutusList([
                PlutusBytes(Uint8List.fromList([1, 2, 3])),
              ]),
            }),
          ],
        ),
      ]);
      final cbor = nested.toCbor();
      expect((cbor['list'] as List).length, equals(1));
    });
  });

  group('NativeScript Edge Cases', () {
    test('sig script', () {
      final script = NativeScript(
        type: NativeScriptType.sig,
        keyHash: Uint8List(28),
      );
      expect(script.type, equals(NativeScriptType.sig));
    });

    test('all script with nested scripts', () {
      final script = NativeScript(
        type: NativeScriptType.all,
        scripts: [
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
        ],
      );
      expect(script.scripts!.length, equals(2));
    });

    test('any script', () {
      final script = NativeScript(
        type: NativeScriptType.any,
        scripts: [
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
        ],
      );
      expect(script.type, equals(NativeScriptType.any));
    });

    test('atLeast script with required count', () {
      final script = NativeScript(
        type: NativeScriptType.atLeast,
        required: 2,
        scripts: [
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
          NativeScript(type: NativeScriptType.sig, keyHash: Uint8List(28)),
        ],
      );
      expect(script.required, equals(2));
      expect(script.scripts!.length, equals(3));
    });

    test('after time lock', () {
      final script = NativeScript(
        type: NativeScriptType.after,
        slot: BigInt.from(50000000),
      );
      expect(script.type, equals(NativeScriptType.after));
      expect(script.slot, equals(BigInt.from(50000000)));
    });

    test('before time lock', () {
      final script = NativeScript(
        type: NativeScriptType.before,
        slot: BigInt.from(60000000),
      );
      expect(script.type, equals(NativeScriptType.before));
    });
  });

  group('CardanoCertificate Edge Cases', () {
    test('stake registration', () {
      final cert = StakeRegistration(Uint8List(28));
      final cbor = cert.toCbor();
      expect(cbor['type'], equals('stake_registration'));
    });

    test('stake deregistration', () {
      final cert = StakeDeregistration(Uint8List(28));
      final cbor = cert.toCbor();
      expect(cbor['type'], equals('stake_deregistration'));
    });

    test('stake delegation', () {
      final cert = StakeDelegation(
        stakeCredential: Uint8List(28),
        poolKeyHash: Uint8List(28),
      );
      final cbor = cert.toCbor();
      expect(cbor['type'], equals('stake_delegation'));
    });
  });

  group('ExUnits Edge Cases', () {
    test('zero execution units', () {
      final units = ExUnits(mem: BigInt.zero, steps: BigInt.zero);
      final cbor = units.toCbor();
      expect(cbor['mem'], equals('0'));
      expect(cbor['steps'], equals('0'));
    });

    test('large execution units', () {
      final units = ExUnits(
        mem: BigInt.parse('14000000'),
        steps: BigInt.parse('10000000000'),
      );
      final cbor = units.toCbor();
      expect(cbor['mem'], equals('14000000'));
      expect(cbor['steps'], equals('10000000000'));
    });
  });

  group('RedeemerTag Edge Cases', () {
    test('all redeemer tags', () {
      expect(RedeemerTag.spend.name, equals('spend'));
      expect(RedeemerTag.mint.name, equals('mint'));
      expect(RedeemerTag.cert.name, equals('cert'));
      expect(RedeemerTag.reward.name, equals('reward'));
    });
  });

  group('CardanoNetwork Edge Cases', () {
    test('network magic values', () {
      expect(CardanoNetwork.mainnet.networkMagic, equals(764824073));
      expect(CardanoNetwork.preprod.networkMagic, equals(1));
      expect(CardanoNetwork.preview.networkMagic, equals(2));
    });

    test('network magic values are unique', () {
      final magics = CardanoNetwork.values.map((n) => n.networkMagic).toSet();
      expect(magics.length, equals(CardanoNetwork.values.length));
    });
  });

  group('Chain Configuration Edge Cases', () {
    test('all chains have valid URLs', () {
      for (final chain in CardanoChains.all) {
        expect(Uri.tryParse(chain.blockfrostUrl), isNotNull);
        expect(Uri.tryParse(chain.koiosUrl), isNotNull);
      }
    });

    test('mainnet is not testnet', () {
      expect(CardanoChains.mainnet.isTestnet, isFalse);
    });

    test('testnets are marked as testnet', () {
      expect(CardanoChains.preprod.isTestnet, isTrue);
      expect(CardanoChains.preview.isTestnet, isTrue);
    });

    test('getByNetwork returns correct chain', () {
      expect(
        CardanoChains.getByNetwork(CardanoNetwork.mainnet),
        equals(CardanoChains.mainnet),
      );
      expect(
        CardanoChains.getByNetwork(CardanoNetwork.preprod),
        equals(CardanoChains.preprod),
      );
      expect(
        CardanoChains.getByNetwork(CardanoNetwork.preview),
        equals(CardanoChains.preview),
      );
    });
  });

  group('Transaction Builder Edge Cases', () {
    CardanoProtocolParams createParams() {
      return CardanoProtocolParams(
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
    }

    test('calculate min fee', () {
      final builder = CardanoTxBuilder(protocolParams: createParams());
      // Fee = minFeeA * txSize + minFeeB
      final fee = builder.calculateMinFee(300);
      expect(fee, equals(BigInt.from(44 * 300 + 155381)));
    });

    test('build transaction with multiple inputs', () {
      final builder = CardanoTxBuilder(protocolParams: createParams());
      builder.addInput(CardanoTxInput(
        txHash: CardanoTxHash.fromHex(
          'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        ),
        index: 0,
      ));
      builder.addInput(CardanoTxInput(
        txHash: CardanoTxHash.fromHex(
          'b2c3d4e5f6789012345678901234567890123456789012345678901234abcdef',
        ),
        index: 1,
      ));
      builder.addOutput(CardanoTxOutput(
        address: CardanoAddress.fromBech32(
          'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp',
        ),
        amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
      ));
      builder.setFee(BigInt.from(200000));

      final body = builder.build();
      expect(body.inputs.length, equals(2));
    });

    test('build transaction with multiple outputs', () {
      final builder = CardanoTxBuilder(protocolParams: createParams());
      builder.addInput(CardanoTxInput(
        txHash: CardanoTxHash.fromHex(
          'a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd',
        ),
        index: 0,
      ));
      builder.addOutput(CardanoTxOutput(
        address: CardanoAddress.fromBech32(
          'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp',
        ),
        amount: CardanoMultiAsset.lovelace(BigInt.from(2000000)),
      ));
      builder.addOutput(CardanoTxOutput(
        address: CardanoAddress.fromBech32(
          'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjqp',
        ),
        amount: CardanoMultiAsset.lovelace(BigInt.from(3000000)),
      ));
      builder.setFee(BigInt.from(200000));

      final body = builder.build();
      expect(body.outputs.length, equals(2));
    });

    test('throws without inputs', () {
      final builder = CardanoTxBuilder(protocolParams: createParams());
      builder.setFee(BigInt.from(200000));
      expect(() => builder.build(), throwsStateError);
    });
  });
}
