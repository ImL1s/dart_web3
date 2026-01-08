/// Sui blockchain integration tests.
///
/// Tests the Sui extension package types and utilities.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:dart_web3_sui/dart_web3_sui.dart';
import 'package:test/test.dart';

void main() {
  group('Sui Integration Tests', () {
    group('SuiAddress', () {
      test('creates from hex with 0x prefix', () {
        final address = SuiAddress.fromHex('0x${'ab' * 32}');
        expect(address.bytes.length, equals(32));
        expect(address.toHex().startsWith('0x'), isTrue);
      });

      test('creates from hex without prefix', () {
        final address = SuiAddress.fromHex('${'cd' * 32}');
        expect(address.bytes.length, equals(32));
      });

      test('pads short addresses correctly', () {
        final address = SuiAddress.fromHex('0x1');
        expect(address.bytes.length, equals(32));
        expect(address.bytes.last, equals(1));
      });

      test('converts to short string format', () {
        final address = SuiAddress.fromHex('0x${'ab' * 32}');
        final shortStr = address.toShortString();
        expect(shortStr.contains('...'), isTrue);
        expect(shortStr.length, lessThan(address.toHex().length));
      });

      test('equality comparison works correctly', () {
        final addr1 = SuiAddress.fromHex('0x${'11' * 32}');
        final addr2 = SuiAddress.fromHex('0x${'11' * 32}');
        final addr3 = SuiAddress.fromHex('0x${'22' * 32}');

        expect(addr1, equals(addr2));
        expect(addr1, isNot(equals(addr3)));
      });

      test('hashCode is consistent', () {
        final addr1 = SuiAddress.fromHex('0x${'11' * 32}');
        final addr2 = SuiAddress.fromHex('0x${'11' * 32}');

        expect(addr1.hashCode, equals(addr2.hashCode));
      });
    });

    group('SuiDigest', () {
      test('creates from bytes', () {
        final digest = SuiDigest(Uint8List(32));
        expect(digest.bytes.length, equals(32));
      });

      test('converts to string', () {
        final digest = SuiDigest(Uint8List(32));
        expect(digest.toString(), isNotEmpty);
      });
    });

    group('SuiTypeTag', () {
      test('creates basic type tags', () {
        expect(SuiTypeTag.bool_.value, equals('bool'));
        expect(SuiTypeTag.u8.value, equals('u8'));
        expect(SuiTypeTag.u64.value, equals('u64'));
        expect(SuiTypeTag.u128.value, equals('u128'));
        expect(SuiTypeTag.u256.value, equals('u256'));
        expect(SuiTypeTag.address.value, equals('address'));
        expect(SuiTypeTag.signer.value, equals('signer'));
      });

      test('creates vector type tags', () {
        final vectorU8 = SuiTypeTag.vector(SuiTypeTag.u8);
        expect(vectorU8.value, equals('vector<u8>'));

        final vectorU64 = SuiTypeTag.vector(SuiTypeTag.u64);
        expect(vectorU64.value, equals('vector<u64>'));
      });

      test('creates struct type tags', () {
        final coinType = SuiTypeTag.struct_('0x2', 'coin', 'Coin');
        expect(coinType.value, equals('0x2::coin::Coin'));
      });

      test('creates struct type tags with type arguments', () {
        final coinType = SuiTypeTag.struct_(
          '0x2',
          'coin',
          'Coin',
          [SuiTypeTag.struct_('0x2', 'sui', 'SUI')],
        );
        expect(coinType.value, contains('0x2::coin::Coin<'));
      });
    });

    group('SuiObjectRef', () {
      test('creates with required fields', () {
        final objectRef = SuiObjectRef(
          objectId: SuiAddress.fromHex('0x${'aa' * 32}'),
          version: BigInt.from(100),
          digest: SuiDigest(Uint8List(32)),
        );

        expect(objectRef.version, equals(BigInt.from(100)));
        expect(objectRef.objectId.bytes.length, equals(32));
      });
    });

    group('SuiOwner Types', () {
      test('creates AddressOwner', () {
        final owner = AddressOwner(SuiAddress.fromHex('0x1'));
        expect(owner.address.bytes.length, equals(32));
        expect(owner, isA<SuiOwner>());
      });

      test('creates ObjectOwner', () {
        final owner = ObjectOwner(SuiAddress.fromHex('0x2'));
        expect(owner.objectId.bytes.length, equals(32));
        expect(owner, isA<SuiOwner>());
      });

      test('creates SharedOwner', () {
        final owner = SharedOwner(initialSharedVersion: BigInt.from(1));
        expect(owner.initialSharedVersion, equals(BigInt.one));
        expect(owner, isA<SuiOwner>());
      });

      test('creates ImmutableOwner', () {
        const owner = ImmutableOwner();
        expect(owner, isA<SuiOwner>());
      });
    });

    group('SuiGasData', () {
      test('creates with required fields', () {
        final gasData = SuiGasData(
          payment: [
            SuiObjectRef(
              objectId: SuiAddress.fromHex('0x1'),
              version: BigInt.one,
              digest: SuiDigest(Uint8List(32)),
            ),
          ],
          owner: SuiAddress.fromHex('0x2'),
          price: BigInt.from(1000),
          budget: BigInt.from(2000000),
        );

        expect(gasData.price, equals(BigInt.from(1000)));
        expect(gasData.budget, equals(BigInt.from(2000000)));
        expect(gasData.payment.length, equals(1));
      });
    });

    group('SuiCoinMetadata', () {
      test('creates with required fields', () {
        final metadata = SuiCoinMetadata(
          decimals: 9,
          name: 'Sui',
          symbol: 'SUI',
          description: 'The native token of Sui',
          id: SuiAddress.fromHex('0x2'),
        );

        expect(metadata.decimals, equals(9));
        expect(metadata.symbol, equals('SUI'));
        expect(metadata.iconUrl, isNull);
      });
    });

    group('SuiEpoch', () {
      test('creates with required fields', () {
        final epoch = SuiEpoch(
          epoch: BigInt.from(100),
          epochStartTimestampMs: BigInt.from(1704672000000),
          epochDurationMs: BigInt.from(86400000),
          referenceGasPrice: BigInt.from(1000),
        );

        expect(epoch.epoch, equals(BigInt.from(100)));
        expect(epoch.epochDurationMs, isNotNull);
      });
    });

    group('Transaction Building', () {
      test('creates ProgrammableTransaction', () {
        const ptb = ProgrammableTransaction(
          inputs: [],
          commands: [],
        );

        expect(ptb.inputs, isEmpty);
        expect(ptb.commands, isEmpty);
        expect(ptb, isA<SuiTransactionKind>());
      });

      test('creates PureArg for different types', () {
        final u64Arg = PureArg.u64(BigInt.from(1000));
        expect(u64Arg.value.length, equals(8));

        final addressArg = PureArg.address(SuiAddress.fromHex('0x1'));
        expect(addressArg.value.length, equals(32));

        final boolArg = PureArg.bool_(true);
        expect(boolArg.value[0], equals(1));

        final stringArg = PureArg.string('hello');
        expect(stringArg.value.length, greaterThan(0));
      });

      test('creates ObjectArg', () {
        final objArg = ObjectArg(
          SuiObjectRef(
            objectId: SuiAddress.fromHex('0x1'),
            version: BigInt.one,
            digest: SuiDigest(Uint8List(32)),
          ),
        );

        expect(objArg.objectRef.version, equals(BigInt.one));
        expect(objArg, isA<SuiCallArg>());
      });

      test('creates SharedObjectArg', () {
        final sharedArg = SharedObjectArg(
          objectId: SuiAddress.fromHex('0x1'),
          initialSharedVersion: BigInt.from(10),
          mutable: true,
        );

        expect(sharedArg.mutable, isTrue);
        expect(sharedArg.initialSharedVersion, equals(BigInt.from(10)));
        expect(sharedArg, isA<SuiCallArg>());
      });

      test('creates MoveCallCommand', () {
        final cmd = MoveCallCommand(
          package: SuiAddress.fromHex('0x2'),
          module: 'coin',
          function: 'transfer',
          typeArguments: [SuiTypeTag.struct_('0x2', 'sui', 'SUI')],
          arguments: [const InputArg(0), const InputArg(1)],
        );

        expect(cmd.module, equals('coin'));
        expect(cmd.function, equals('transfer'));
        expect(cmd, isA<SuiCommand>());
      });

      test('creates TransferObjectsCommand', () {
        const cmd = TransferObjectsCommand(
          objects: [ResultArg(0)],
          address: InputArg(1),
        );

        expect(cmd.objects.length, equals(1));
        expect(cmd, isA<SuiCommand>());
      });

      test('creates SplitCoinsCommand', () {
        const cmd = SplitCoinsCommand(
          coin: GasCoinArg(),
          amounts: [InputArg(0), InputArg(1)],
        );

        expect(cmd.amounts.length, equals(2));
        expect(cmd, isA<SuiCommand>());
      });

      test('creates MergeCoinsCommand', () {
        const cmd = MergeCoinsCommand(
          destination: InputArg(0),
          sources: [InputArg(1), InputArg(2)],
        );

        expect(cmd.sources.length, equals(2));
        expect(cmd, isA<SuiCommand>());
      });
    });

    group('SuiArgument Types', () {
      test('creates GasCoinArg', () {
        const arg = GasCoinArg();
        expect(arg, isA<SuiArgument>());
      });

      test('creates InputArg', () {
        const arg = InputArg(5);
        expect(arg.index, equals(5));
        expect(arg, isA<SuiArgument>());
      });

      test('creates ResultArg', () {
        const arg = ResultArg(3);
        expect(arg.index, equals(3));
        expect(arg, isA<SuiArgument>());
      });

      test('creates NestedResultArg', () {
        const arg = NestedResultArg(1, 2);
        expect(arg.commandIndex, equals(1));
        expect(arg.resultIndex, equals(2));
        expect(arg, isA<SuiArgument>());
      });
    });

    group('TransactionBlockBuilder', () {
      test('creates empty builder', () {
        final builder = TransactionBlockBuilder();
        expect(builder.gas, isA<GasCoinArg>());
      });

      test('adds pure value input', () {
        final builder = TransactionBlockBuilder();
        final arg = builder.addPure(Uint8List.fromList([1, 2, 3]));
        expect(arg, isA<InputArg>());
      });

      test('adds object input', () {
        final builder = TransactionBlockBuilder();
        final arg = builder.addObject(
          SuiObjectRef(
            objectId: SuiAddress.fromHex('0x1'),
            version: BigInt.one,
            digest: SuiDigest(Uint8List(32)),
          ),
        );
        expect(arg, isA<InputArg>());
      });

      test('adds move call command', () {
        final builder = TransactionBlockBuilder();
        final result = builder.moveCall(
          package: SuiAddress.fromHex('0x2'),
          module: 'coin',
          function: 'value',
        );
        expect(result, isA<ResultArg>());
      });

      test('builds complete transaction', () {
        final builder = TransactionBlockBuilder();
        builder.setSender(SuiAddress.fromHex('0x1'));
        builder.setGasData(
          SuiGasData(
            payment: [
              SuiObjectRef(
                objectId: SuiAddress.fromHex('0x3'),
                version: BigInt.one,
                digest: SuiDigest(Uint8List(32)),
              ),
            ],
            owner: SuiAddress.fromHex('0x1'),
            price: BigInt.from(1000),
            budget: BigInt.from(2000000),
          ),
        );

        final arg = builder.addPure(PureArg.u64(BigInt.from(100)).value);
        builder.moveCall(
          package: SuiAddress.fromHex('0x2'),
          module: 'coin',
          function: 'value',
          arguments: [arg],
        );

        final txData = builder.build();
        expect(txData.kind, isA<ProgrammableTransaction>());
        expect(txData.sender, isNotNull);
      });

      test('throws without sender', () {
        final builder = TransactionBlockBuilder();
        builder.setGasData(
          SuiGasData(
            payment: [],
            owner: SuiAddress.fromHex('0x1'),
            price: BigInt.from(1000),
            budget: BigInt.from(2000000),
          ),
        );

        expect(() => builder.build(), throwsStateError);
      });

      test('throws without gas data', () {
        final builder = TransactionBlockBuilder();
        builder.setSender(SuiAddress.fromHex('0x1'));

        expect(() => builder.build(), throwsStateError);
      });
    });

    group('SuiTransaction', () {
      test('creates signed transaction', () {
        final tx = SuiTransaction(
          data: SuiTransactionData(
            kind: const ProgrammableTransaction(inputs: [], commands: []),
            sender: SuiAddress.fromHex('0x1'),
            gasData: SuiGasData(
              payment: [],
              owner: SuiAddress.fromHex('0x1'),
              price: BigInt.from(1000),
              budget: BigInt.from(2000000),
            ),
            expiration: const NoExpiration(),
          ),
          signatures: [
            SuiSignature(
              scheme: SuiSignatureScheme.ed25519,
              signature: Uint8List(64),
            ),
          ],
        );

        expect(tx.signatures.length, equals(1));
        expect(tx.data.expiration, isA<NoExpiration>());
      });

      test('serializes transaction', () {
        final tx = SuiTransaction(
          data: SuiTransactionData(
            kind: const ProgrammableTransaction(inputs: [], commands: []),
            sender: SuiAddress.fromHex('0x1'),
            gasData: SuiGasData(
              payment: [],
              owner: SuiAddress.fromHex('0x1'),
              price: BigInt.from(1000),
              budget: BigInt.from(2000000),
            ),
            expiration: const NoExpiration(),
          ),
          signatures: [],
        );

        final serialized = tx.serialize();
        expect(serialized, isA<Uint8List>());
      });
    });

    group('SuiSignatureScheme', () {
      test('has correct flag values', () {
        expect(SuiSignatureScheme.ed25519.flag, equals(0));
        expect(SuiSignatureScheme.secp256k1.flag, equals(1));
        expect(SuiSignatureScheme.secp256r1.flag, equals(2));
        expect(SuiSignatureScheme.multiSig.flag, equals(3));
        expect(SuiSignatureScheme.zkLogin.flag, equals(5));
      });
    });

    group('Transaction Expiration', () {
      test('creates NoExpiration', () {
        const exp = NoExpiration();
        expect(exp, isA<SuiTransactionExpiration>());
      });

      test('creates EpochExpiration', () {
        final exp = EpochExpiration(BigInt.from(100));
        expect(exp.epoch, equals(BigInt.from(100)));
        expect(exp, isA<SuiTransactionExpiration>());
      });
    });

    group('Constants', () {
      test('suiCoinType is correct', () {
        expect(suiCoinType, equals('0x2::sui::SUI'));
      });
    });
  });
}
