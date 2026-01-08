/// Cardano blockchain integration tests.
///
/// Tests the Cardano extension package types and utilities.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:web3_universal_cardano/web3_universal_cardano.dart';
import 'package:test/test.dart';

void main() {
  group('Cardano Integration Tests', () {
    group('CardanoAddressType', () {
      test('has correct header values', () {
        expect(CardanoAddressType.base.header, equals(0));
        expect(CardanoAddressType.pointer.header, equals(4));
        expect(CardanoAddressType.enterprise.header, equals(6));
        expect(CardanoAddressType.reward.header, equals(14));
        expect(CardanoAddressType.byron.header, equals(8));
      });
    });

    group('CardanoAddress', () {
      test('creates from Bech32 mainnet address', () {
        final address = CardanoAddress.fromBech32('addr1qxyz123');
        expect(address.type, equals(CardanoAddressType.base));
        expect(address.network, equals(1)); // mainnet
        expect(address.isMainnet, isTrue);
      });

      test('creates from Bech32 testnet address', () {
        final address = CardanoAddress.fromBech32('addr_test1qxyz123');
        expect(address.type, equals(CardanoAddressType.base));
        expect(address.network, equals(0)); // testnet
        expect(address.isMainnet, isFalse);
      });

      test('creates stake address from Bech32', () {
        final address = CardanoAddress.fromBech32('stake1qxyz123');
        expect(address.type, equals(CardanoAddressType.reward));
        expect(address.network, equals(1));
      });

      test('creates testnet stake address', () {
        final address = CardanoAddress.fromBech32('stake_test1qxyz123');
        expect(address.type, equals(CardanoAddressType.reward));
        expect(address.network, equals(0));
      });

      test('converts to Bech32 string', () {
        final address = CardanoAddress(
          type: CardanoAddressType.base,
          network: 1,
          bytes: Uint8List(57),
          bech32: 'addr1test123',
        );
        expect(address.toBech32(), equals('addr1test123'));
      });

      test('toString returns Bech32', () {
        final address = CardanoAddress(
          type: CardanoAddressType.base,
          network: 1,
          bytes: Uint8List(57),
          bech32: 'addr1test456',
        );
        expect(address.toString(), equals('addr1test456'));
      });
    });

    group('CardanoTxHash', () {
      test('creates from hex string', () {
        final hash = CardanoTxHash.fromHex('${'ab' * 32}');
        expect(hash.bytes.length, equals(32));
        expect(hash.bytes[0], equals(0xab));
      });

      test('creates from hex with 0x prefix', () {
        final hash = CardanoTxHash.fromHex('0x${'cd' * 32}');
        expect(hash.bytes.length, equals(32));
        expect(hash.bytes[0], equals(0xcd));
      });

      test('converts to hex string', () {
        final bytes = Uint8List.fromList(List.generate(32, (i) => i));
        final hash = CardanoTxHash(bytes);
        expect(hash.toHex().length, equals(64));
      });

      test('toString returns hex', () {
        final hash = CardanoTxHash.fromHex('${'ef' * 32}');
        expect(hash.toString(), equals('${'ef' * 32}'));
      });
    });

    group('CardanoValue', () {
      test('creates with unit and quantity', () {
        final value = CardanoValue(
          unit: 'lovelace',
          quantity: BigInt.from(5000000),
        );
        expect(value.unit, equals('lovelace'));
        expect(value.quantity, equals(BigInt.from(5000000)));
        expect(value.isAda, isTrue);
      });

      test('identifies non-ADA tokens', () {
        final value = CardanoValue(
          unit: 'policyid123assetname456',
          quantity: BigInt.from(100),
        );
        expect(value.isAda, isFalse);
      });

      test('creates from JSON', () {
        final value = CardanoValue.fromJson({
          'unit': 'lovelace',
          'quantity': '1000000',
        });
        expect(value.unit, equals('lovelace'));
        expect(value.quantity, equals(BigInt.from(1000000)));
      });

      test('converts to JSON', () {
        final value = CardanoValue(
          unit: 'lovelace',
          quantity: BigInt.from(2000000),
        );
        final json = value.toJson();
        expect(json['unit'], equals('lovelace'));
        expect(json['quantity'], equals('2000000'));
      });
    });

    group('CardanoAsset', () {
      test('creates with required fields', () {
        final asset = CardanoAsset(
          policyId: 'a' * 56,
          assetName: 'token123',
          quantity: BigInt.from(1000),
        );
        expect(asset.policyId, equals('a' * 56));
        expect(asset.assetName, equals('token123'));
        expect(asset.quantity, equals(BigInt.from(1000)));
      });

      test('creates from JSON', () {
        final asset = CardanoAsset.fromJson({
          'policy_id': 'b' * 56,
          'asset_name': 'mytoken',
          'quantity': '500',
        });
        expect(asset.policyId, equals('b' * 56));
        expect(asset.assetName, equals('mytoken'));
        expect(asset.quantity, equals(BigInt.from(500)));
      });

      test('gets unit string', () {
        final asset = CardanoAsset(
          policyId: 'policy123',
          assetName: 'name456',
          quantity: BigInt.from(100),
        );
        expect(asset.unit, equals('policy123name456'));
      });
    });

    group('CardanoUtxo', () {
      test('creates with required fields', () {
        final txHash = CardanoTxHash.fromHex('${'aa' * 32}');
        final utxo = CardanoUtxo(
          txHash: txHash,
          outputIndex: 0,
          amount: [
            CardanoValue(unit: 'lovelace', quantity: BigInt.from(5000000)),
          ],
        );
        expect(utxo.txHash.bytes.length, equals(32));
        expect(utxo.outputIndex, equals(0));
        expect(utxo.amount.length, equals(1));
      });

      test('gets lovelace amount', () {
        final utxo = CardanoUtxo(
          txHash: CardanoTxHash.fromHex('${'bb' * 32}'),
          outputIndex: 1,
          amount: [
            CardanoValue(unit: 'lovelace', quantity: BigInt.from(3000000)),
            CardanoValue(unit: 'tokenunit', quantity: BigInt.from(100)),
          ],
        );
        expect(utxo.lovelace, equals(BigInt.from(3000000)));
      });

      test('returns zero if no lovelace', () {
        final utxo = CardanoUtxo(
          txHash: CardanoTxHash.fromHex('${'cc' * 32}'),
          outputIndex: 0,
          amount: [
            CardanoValue(unit: 'sometoken', quantity: BigInt.from(50)),
          ],
        );
        expect(utxo.lovelace, equals(BigInt.zero));
      });
    });

    group('CardanoMultiAsset', () {
      test('creates with lovelace only', () {
        final value = CardanoMultiAsset.lovelace(BigInt.from(1000000));
        expect(value.coin, equals(BigInt.from(1000000)));
        expect(value.multiAsset, isNull);
      });

      test('creates with multi-asset', () {
        final value = CardanoMultiAsset(
          coin: BigInt.from(2000000),
          multiAsset: {
            'policy1': {'asset1': BigInt.from(100)},
          },
        );
        expect(value.coin, equals(BigInt.from(2000000)));
        expect(value.multiAsset, isNotNull);
        expect(value.multiAsset!['policy1']!['asset1'], equals(BigInt.from(100)));
      });

      test('adds two values', () {
        final v1 = CardanoMultiAsset(
          coin: BigInt.from(1000000),
          multiAsset: {'policy1': {'asset1': BigInt.from(50)}},
        );
        final v2 = CardanoMultiAsset(
          coin: BigInt.from(500000),
          multiAsset: {'policy1': {'asset1': BigInt.from(30), 'asset2': BigInt.from(20)}},
        );

        final sum = v1 + v2;
        expect(sum.coin, equals(BigInt.from(1500000)));
        expect(sum.multiAsset!['policy1']!['asset1'], equals(BigInt.from(80)));
        expect(sum.multiAsset!['policy1']!['asset2'], equals(BigInt.from(20)));
      });

      test('toCbor returns coin for lovelace-only', () {
        final value = CardanoMultiAsset.lovelace(BigInt.from(1000000));
        expect(value.toCbor(), equals('1000000'));
      });
    });

    group('CardanoPlutusData', () {
      test('creates PlutusInteger', () {
        final data = PlutusInteger(BigInt.from(42));
        expect(data.value, equals(BigInt.from(42)));
        expect(data.toCbor()['int'], equals('42'));
      });

      test('creates PlutusBytes', () {
        final data = PlutusBytes(Uint8List.fromList([1, 2, 3]));
        expect(data.value.length, equals(3));
        expect(data.toCbor()['bytes'], equals(Uint8List.fromList([1, 2, 3])));
      });

      test('creates PlutusList', () {
        final data = PlutusList([
          PlutusInteger(BigInt.from(1)),
          PlutusInteger(BigInt.from(2)),
        ]);
        expect(data.items.length, equals(2));
        expect((data.toCbor()['list'] as List).length, equals(2));
      });

      test('creates PlutusMap', () {
        final data = PlutusMap({
          PlutusInteger(BigInt.from(1)): PlutusBytes(Uint8List.fromList([10])),
        });
        expect(data.entries.length, equals(1));
      });

      test('creates PlutusConstr', () {
        final data = PlutusConstr(
          constructor: 0,
          fields: [PlutusInteger(BigInt.from(100))],
        );
        expect(data.constructor, equals(0));
        expect(data.fields.length, equals(1));
      });
    });

    group('CardanoScript', () {
      test('creates NativeScript with sig type', () {
        final script = NativeScript(
          type: NativeScriptType.sig,
          keyHash: Uint8List(28),
        );
        expect(script.type, equals(NativeScriptType.sig));
        expect(script.keyHash, isNotNull);
      });

      test('creates NativeScript with time lock', () {
        final script = NativeScript(
          type: NativeScriptType.after,
          slot: BigInt.from(1000000),
        );
        expect(script.type, equals(NativeScriptType.after));
        expect(script.slot, equals(BigInt.from(1000000)));
      });

      test('creates PlutusScript', () {
        final script = PlutusScript(
          version: 2,
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        );
        expect(script.version, equals(2));
        expect(script.bytes.length, equals(5));
      });
    });

    group('CardanoTxInput', () {
      test('creates from hash and index', () {
        final input = CardanoTxInput(
          txHash: CardanoTxHash.fromHex('${'dd' * 32}'),
          index: 0,
        );
        expect(input.txHash.bytes.length, equals(32));
        expect(input.index, equals(0));
      });

      test('creates from UTxO', () {
        final utxo = CardanoUtxo(
          txHash: CardanoTxHash.fromHex('${'ee' * 32}'),
          outputIndex: 2,
          amount: [],
        );
        final input = CardanoTxInput.fromUtxo(utxo);
        expect(input.index, equals(2));
      });

      test('toCbor returns correct format', () {
        final input = CardanoTxInput(
          txHash: CardanoTxHash.fromHex('${'ff' * 32}'),
          index: 1,
        );
        final cbor = input.toCbor();
        expect(cbor['transaction_id'], isNotNull);
        expect(cbor['index'], equals(1));
      });
    });

    group('CardanoTxOutput', () {
      test('creates with address and amount', () {
        final output = CardanoTxOutput(
          address: CardanoAddress.fromBech32('addr1test'),
          amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
        );
        expect(output.address.type, equals(CardanoAddressType.base));
        expect(output.amount.coin, equals(BigInt.from(5000000)));
      });

      test('creates with datum', () {
        final output = CardanoTxOutput(
          address: CardanoAddress.fromBech32('addr1test'),
          amount: CardanoMultiAsset.lovelace(BigInt.from(2000000)),
          datum: PlutusInteger(BigInt.from(42)),
        );
        expect(output.datum, isNotNull);
        expect((output.datum as PlutusInteger).value, equals(BigInt.from(42)));
      });
    });

    group('CardanoCertificate', () {
      test('creates StakeRegistration', () {
        final cert = StakeRegistration(Uint8List(28));
        expect(cert, isA<CardanoCertificate>());
        expect(cert.stakeCredential.length, equals(28));
      });

      test('creates StakeDeregistration', () {
        final cert = StakeDeregistration(Uint8List(28));
        expect(cert, isA<CardanoCertificate>());
      });

      test('creates StakeDelegation', () {
        final cert = StakeDelegation(
          stakeCredential: Uint8List(28),
          poolKeyHash: Uint8List(28),
        );
        expect(cert, isA<CardanoCertificate>());
        expect(cert.poolKeyHash.length, equals(28));
      });
    });

    group('CardanoRedeemer', () {
      test('creates with all fields', () {
        final redeemer = CardanoRedeemer(
          tag: RedeemerTag.spend,
          index: 0,
          data: PlutusInteger(BigInt.from(100)),
          exUnits: ExUnits(mem: BigInt.from(1000), steps: BigInt.from(2000)),
        );
        expect(redeemer.tag, equals(RedeemerTag.spend));
        expect(redeemer.index, equals(0));
      });

      test('RedeemerTag has all variants', () {
        expect(RedeemerTag.values.length, equals(4));
        expect(RedeemerTag.spend.name, equals('spend'));
        expect(RedeemerTag.mint.name, equals('mint'));
        expect(RedeemerTag.cert.name, equals('cert'));
        expect(RedeemerTag.reward.name, equals('reward'));
      });
    });

    group('ExUnits', () {
      test('creates with mem and steps', () {
        final exUnits = ExUnits(
          mem: BigInt.from(100000),
          steps: BigInt.from(200000),
        );
        expect(exUnits.mem, equals(BigInt.from(100000)));
        expect(exUnits.steps, equals(BigInt.from(200000)));
      });

      test('toCbor returns correct format', () {
        final exUnits = ExUnits(
          mem: BigInt.from(50000),
          steps: BigInt.from(100000),
        );
        final cbor = exUnits.toCbor();
        expect(cbor['mem'], equals('50000'));
        expect(cbor['steps'], equals('100000'));
      });
    });

    group('CardanoWitnessSet', () {
      test('creates with VKey witnesses', () {
        final witnessSet = CardanoWitnessSet(
          vkeyWitnesses: [
            CardanoVkeyWitness(
              vkey: Uint8List(32),
              signature: Uint8List(64),
            ),
          ],
        );
        expect(witnessSet.vkeyWitnesses?.length, equals(1));
      });

      test('creates with Plutus scripts', () {
        final witnessSet = CardanoWitnessSet(
          plutusScripts: [
            PlutusScript(version: 2, bytes: Uint8List(10)),
          ],
        );
        expect(witnessSet.plutusScripts?.length, equals(1));
      });
    });

    group('CardanoVkeyWitness', () {
      test('creates with vkey and signature', () {
        final witness = CardanoVkeyWitness(
          vkey: Uint8List(32),
          signature: Uint8List(64),
        );
        expect(witness.vkey.length, equals(32));
        expect(witness.signature.length, equals(64));
      });
    });

    group('CardanoTxBody', () {
      test('creates with required fields', () {
        final body = CardanoTxBody(
          inputs: [
            CardanoTxInput(
              txHash: CardanoTxHash.fromHex('${'aa' * 32}'),
              index: 0,
            ),
          ],
          outputs: [
            CardanoTxOutput(
              address: CardanoAddress.fromBech32('addr1test'),
              amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
            ),
          ],
          fee: BigInt.from(200000),
        );
        expect(body.inputs.length, equals(1));
        expect(body.outputs.length, equals(1));
        expect(body.fee, equals(BigInt.from(200000)));
      });

      test('creates with TTL', () {
        final body = CardanoTxBody(
          inputs: [],
          outputs: [],
          fee: BigInt.from(200000),
          ttl: BigInt.from(50000000),
        );
        expect(body.ttl, equals(BigInt.from(50000000)));
      });

      test('creates with certificates', () {
        final body = CardanoTxBody(
          inputs: [],
          outputs: [],
          fee: BigInt.from(200000),
          certificates: [StakeRegistration(Uint8List(28))],
        );
        expect(body.certificates?.length, equals(1));
      });
    });

    group('CardanoTransaction', () {
      test('creates with body and witness set', () {
        final tx = CardanoTransaction(
          body: CardanoTxBody(
            inputs: [],
            outputs: [],
            fee: BigInt.from(200000),
          ),
          witnessSet: const CardanoWitnessSet(),
        );
        expect(tx.isValid, isTrue);
        expect(tx.auxiliaryData, isNull);
      });

      test('creates with auxiliary data', () {
        final tx = CardanoTransaction(
          body: CardanoTxBody(
            inputs: [],
            outputs: [],
            fee: BigInt.from(200000),
          ),
          witnessSet: const CardanoWitnessSet(),
          auxiliaryData: {'msg': 'hello'},
        );
        expect(tx.auxiliaryData, isNotNull);
        expect(tx.auxiliaryData!['msg'], equals('hello'));
      });

      test('serialize returns bytes', () {
        final tx = CardanoTransaction(
          body: CardanoTxBody(
            inputs: [],
            outputs: [],
            fee: BigInt.from(200000),
          ),
          witnessSet: const CardanoWitnessSet(),
        );
        expect(tx.serialize(), isA<Uint8List>());
      });
    });

    group('CardanoTxBuilder', () {
      test('creates with protocol params', () {
        final builder = CardanoTxBuilder(
          protocolParams: CardanoProtocolParams(
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
          ),
        );
        expect(builder.protocolParams.minFeeA, equals(44));
      });

      test('adds inputs and outputs', () {
        final builder = CardanoTxBuilder(
          protocolParams: CardanoProtocolParams(
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
          ),
        );

        builder
            .addInput(CardanoTxInput(
              txHash: CardanoTxHash.fromHex('${'aa' * 32}'),
              index: 0,
            ))
            .addOutput(CardanoTxOutput(
              address: CardanoAddress.fromBech32('addr1test'),
              amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
            ))
            .setFee(BigInt.from(200000));

        final body = builder.build();
        expect(body.inputs.length, equals(1));
        expect(body.outputs.length, equals(1));
        expect(body.fee, equals(BigInt.from(200000)));
      });

      test('calculates minimum fee', () {
        final builder = CardanoTxBuilder(
          protocolParams: CardanoProtocolParams(
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
          ),
        );

        final minFee = builder.calculateMinFee(300);
        expect(minFee, equals(BigInt.from(44 * 300 + 155381)));
      });

      test('throws without inputs', () {
        final builder = CardanoTxBuilder(
          protocolParams: CardanoProtocolParams(
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
          ),
        );
        builder.addOutput(CardanoTxOutput(
          address: CardanoAddress.fromBech32('addr1test'),
          amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
        ));
        builder.setFee(BigInt.from(200000));

        expect(() => builder.build(), throwsStateError);
      });

      test('throws without fee', () {
        final builder = CardanoTxBuilder(
          protocolParams: CardanoProtocolParams(
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
          ),
        );
        builder.addInput(CardanoTxInput(
          txHash: CardanoTxHash.fromHex('${'aa' * 32}'),
          index: 0,
        ));
        builder.addOutput(CardanoTxOutput(
          address: CardanoAddress.fromBech32('addr1test'),
          amount: CardanoMultiAsset.lovelace(BigInt.from(5000000)),
        ));

        expect(() => builder.build(), throwsStateError);
      });
    });

    group('CardanoProtocolParams', () {
      test('creates with required fields', () {
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

        expect(params.minFeeA, equals(44));
        expect(params.minFeeB, equals(155381));
        expect(params.maxTxSize, equals(16384));
        expect(params.keyDeposit, equals(BigInt.from(2000000)));
        expect(params.poolDeposit, equals(BigInt.from(500000000)));
      });

      test('creates from JSON', () {
        final params = CardanoProtocolParams.fromJson({
          'min_fee_a': 44,
          'min_fee_b': 155381,
          'max_tx_size': 16384,
          'key_deposit': '2000000',
          'pool_deposit': '500000000',
          'coins_per_utxo_size': '4310',
          'price_mem': '0.0577',
          'price_step': '0.0000721',
          'collateral_percent': 150,
          'max_collateral_inputs': 3,
        });

        expect(params.minFeeA, equals(44));
        expect(params.keyDeposit, equals(BigInt.from(2000000)));
      });
    });

    group('CardanoBlock', () {
      test('creates with required fields', () {
        final block = CardanoBlock(
          hash: 'blockhash123',
          height: 100000,
          slot: 50000000,
          epoch: 300,
          epochSlot: 1000,
          time: DateTime(2024, 1, 8),
          txCount: 15,
        );

        expect(block.hash, equals('blockhash123'));
        expect(block.height, equals(100000));
        expect(block.epoch, equals(300));
        expect(block.txCount, equals(15));
      });
    });

    group('CardanoEpoch', () {
      test('creates with required fields', () {
        final epoch = CardanoEpoch(
          epoch: 403,
          startTime: DateTime(2024, 1, 1),
          endTime: DateTime(2024, 1, 6),
          firstBlockTime: DateTime(2024, 1, 1, 0, 0, 1),
          lastBlockTime: DateTime(2024, 1, 5, 23, 59, 59),
          blockCount: 21600,
          txCount: 150000,
          output: BigInt.from(1000000000000),
          fees: BigInt.from(500000000),
          activeStake: BigInt.from(22000000000000000),
        );

        expect(epoch.epoch, equals(403));
        expect(epoch.blockCount, equals(21600));
        expect(epoch.txCount, equals(150000));
      });
    });

    group('CardanoPool', () {
      test('creates with required fields', () {
        final pool = CardanoPool(
          poolId: 'pool1abc123',
          hex: 'abc123',
          vrfKey: 'vrfkey123',
          pledge: BigInt.from(1000000000),
          cost: BigInt.from(340000000),
          margin: 0.05,
          rewardAccount: 'stake1address',
        );

        expect(pool.poolId, equals('pool1abc123'));
        expect(pool.pledge, equals(BigInt.from(1000000000)));
        expect(pool.margin, equals(0.05));
      });
    });

    group('NativeScriptType', () {
      test('has all variants', () {
        expect(NativeScriptType.values.length, equals(6));
        expect(NativeScriptType.sig.name, equals('sig'));
        expect(NativeScriptType.all.name, equals('all'));
        expect(NativeScriptType.any.name, equals('any'));
        expect(NativeScriptType.atLeast.name, equals('atLeast'));
        expect(NativeScriptType.after.name, equals('after'));
        expect(NativeScriptType.before.name, equals('before'));
      });
    });
  });
}
