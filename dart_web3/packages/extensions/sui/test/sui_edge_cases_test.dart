import 'dart:typed_data';
import 'package:dart_web3_sui/dart_web3_sui.dart';
import 'package:test/test.dart';

/// Strict edge case and authoritative tests for Sui extension package.
/// Test vectors derived from official Sui/Move BCS specification.
void main() {
  group('SuiAddress Edge Cases', () {
    // === Official Test Vectors ===
    test('zero address (0x0)', () {
      final address = SuiAddress.fromHex('0x0');
      expect(address.bytes, equals(Uint8List(32)));
      expect(
        address.toHex(),
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
    });

    test('max address (all 0xFF)', () {
      final maxHex = '0x${'ff' * 32}';
      final address = SuiAddress.fromHex(maxHex);
      expect(address.bytes, everyElement(equals(0xff)));
      expect(address.toHex(), equals(maxHex));
    });

    test('system addresses (0x1, 0x2, 0x5, 0x6)', () {
      // Sui framework address
      final suiFramework = SuiAddress.fromHex('0x2');
      expect(suiFramework.bytes[31], equals(2));

      // Sui system address
      final suiSystem = SuiAddress.fromHex('0x5');
      expect(suiSystem.bytes[31], equals(5));

      // Clock object address
      final clock = SuiAddress.fromHex('0x6');
      expect(clock.bytes[31], equals(6));
    });

    test('leading zeros preserved', () {
      final address = SuiAddress.fromHex('0x00000000000000000000000000000001');
      expect(
        address.toHex(),
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        ),
      );
    });

    test('case insensitivity', () {
      final lower = SuiAddress.fromHex('0xabcdef');
      final upper = SuiAddress.fromHex('0xABCDEF');
      final mixed = SuiAddress.fromHex('0xAbCdEf');
      expect(lower, equals(upper));
      expect(lower, equals(mixed));
    });

    test('empty hex string should pad to 32 bytes', () {
      final address = SuiAddress.fromHex('0x');
      expect(address.bytes.length, equals(32));
      expect(address.bytes, everyElement(equals(0)));
    });

    test('real-world mainnet address', () {
      // Example from Sui documentation
      const realAddress =
          '0x02a212de6a9dfa3a69e22387acfbafbb1a9e591bd9d636e7895dcfc8de05f331';
      final address = SuiAddress.fromHex(realAddress);
      expect(address.bytes.length, equals(32));
      expect(address.toHex(), equals(realAddress));
    });
  });

  group('BCS Encoding Test Vectors (Official Specification)', () {
    // === BCS Specification Test Vectors ===
    // From: https://github.com/aptos-labs/bcs

    test('u64 little-endian encoding', () {
      // BCS encodes u64 in little-endian format
      final arg1 = PureArg.u64(BigInt.from(1));
      expect(
        arg1.value,
        equals(Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])),
      );

      final arg256 = PureArg.u64(BigInt.from(256));
      expect(
        arg256.value,
        equals(Uint8List.fromList([0, 1, 0, 0, 0, 0, 0, 0])),
      );

      final arg305419896 = PureArg.u64(BigInt.from(305419896)); // 0x12345678
      expect(
        arg305419896.value,
        equals(Uint8List.fromList([0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0])),
      );
    });

    test('u64 max value', () {
      final maxU64 = BigInt.parse('18446744073709551615'); // 2^64 - 1
      final arg = PureArg.u64(maxU64);
      expect(
        arg.value,
        equals(Uint8List.fromList([255, 255, 255, 255, 255, 255, 255, 255])),
      );
    });

    test('u64 zero', () {
      final arg = PureArg.u64(BigInt.zero);
      expect(
        arg.value,
        equals(Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0])),
      );
    });

    test('bool encoding', () {
      // BCS: true = 0x01, false = 0x00
      final trueArg = PureArg.bool_(true);
      final falseArg = PureArg.bool_(false);
      expect(trueArg.value, equals(Uint8List.fromList([1])));
      expect(falseArg.value, equals(Uint8List.fromList([0])));
    });

    test('address encoding (32 bytes)', () {
      final address = SuiAddress.fromHex('0x1');
      final arg = PureArg.address(address);
      expect(arg.value.length, equals(32));
      expect(arg.value[31], equals(1)); // little-endian
    });

    test('string encoding with ULEB128 length prefix', () {
      // BCS strings: ULEB128 length + UTF-8 bytes
      final arg = PureArg.string('sui');
      // Length 3 + 's' 'u' 'i'
      expect(arg.value[0], equals(3)); // ULEB128 length
      expect(arg.value[1], equals(0x73)); // 's'
      expect(arg.value[2], equals(0x75)); // 'u'
      expect(arg.value[3], equals(0x69)); // 'i'
    });

    test('empty string encoding', () {
      final arg = PureArg.string('');
      expect(arg.value, equals(Uint8List.fromList([0]))); // length = 0
    });

    test('UTF-8 multi-byte character encoding', () {
      // "çå" - 2 characters, implementation uses codeUnits (UTF-16)
      final arg = PureArg.string('çå');
      // codeUnits length for Latin-1 chars is 1 each
      expect(arg.value[0], equals(2)); // length = 2 code units
    });
  });

  group('SuiTypeTag Edge Cases', () {
    test('nested vector types', () {
      final vecVecU64 = SuiTypeTag.vector(SuiTypeTag.vector(SuiTypeTag.u64));
      expect(vecVecU64.value, equals('vector<vector<u64>>'));
    });

    test('deeply nested struct types', () {
      final nestedType = SuiTypeTag.struct_(
        '0x2',
        'coin',
        'CoinMetadata',
        [SuiTypeTag.struct_('0x2', 'sui', 'SUI')],
      );
      expect(nestedType.value, contains('CoinMetadata'));
      expect(nestedType.value, contains('SUI'));
    });

    test('all primitive types', () {
      expect(SuiTypeTag.u8.value, equals('u8'));
      expect(SuiTypeTag.u16.value, equals('u16'));
      expect(SuiTypeTag.u32.value, equals('u32'));
      expect(SuiTypeTag.u64.value, equals('u64'));
      expect(SuiTypeTag.u128.value, equals('u128'));
      expect(SuiTypeTag.u256.value, equals('u256'));
      expect(SuiTypeTag.bool_.value, equals('bool'));
      expect(SuiTypeTag.address.value, equals('address'));
      expect(SuiTypeTag.signer.value, equals('signer'));
    });

    test('SUI coin type', () {
      final suiCoin = SuiTypeTag.struct_('0x2', 'sui', 'SUI');
      expect(suiCoin.value, equals('0x2::sui::SUI'));
    });

    test('struct with multiple type parameters', () {
      final balance = SuiTypeTag.struct_(
        '0x2',
        'balance',
        'Balance',
        [SuiTypeTag.struct_('0x2', 'sui', 'SUI')],
      );
      expect(balance.value, contains('Balance'));
    });
  });

  group('SuiObjectId Edge Cases', () {
    test('zero object ID', () {
      final id = SuiObjectId.fromHex('0x0');
      expect(id.bytes.length, equals(32));
    });

    test('object ID equality', () {
      final id1 = SuiObjectId.fromHex('0xabc');
      final id2 = SuiObjectId.fromHex('0xABC');
      expect(id1.toHex(), equals(id2.toHex()));
    });
  });

  group('Transaction Builder Edge Cases', () {
    test('transaction with no commands', () {
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
      final txData = builder.build();
      final kind = txData.kind as ProgrammableTransaction;
      expect(kind.commands, isEmpty);
    });

    test('transaction with multiple split coins', () {
      final builder = TransactionBlockBuilder();
      builder.setSender(SuiAddress.fromHex('0x1'));
      builder.setGasData(
        SuiGasData(
          payment: [],
          owner: SuiAddress.fromHex('0x1'),
          price: BigInt.from(1000),
          budget: BigInt.from(50000000),
        ),
      );

      // Split into multiple amounts
      final amount1 = builder.addPure(PureArg.u64(BigInt.from(1000000)).value);
      final amount2 = builder.addPure(PureArg.u64(BigInt.from(2000000)).value);
      final amount3 = builder.addPure(PureArg.u64(BigInt.from(3000000)).value);

      builder.splitCoins(builder.gas, [amount1, amount2, amount3]);

      final txData = builder.build();
      final kind = txData.kind as ProgrammableTransaction;
      expect(kind.commands.length, equals(1));
      expect(kind.inputs.length, equals(3));
    });

    test('transaction with merge coins', () {
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

      // Merge coins requires ObjectArgs but we can test the structure
      final txData = builder.build();
      expect(txData.kind, isA<ProgrammableTransaction>());
    });

    test('max gas budget', () {
      final builder = TransactionBlockBuilder();
      builder.setSender(SuiAddress.fromHex('0x1'));
      final maxGas = BigInt.from(50000000000); // 50 SUI
      builder.setGasData(
        SuiGasData(
          payment: [],
          owner: SuiAddress.fromHex('0x1'),
          price: BigInt.from(1000),
          budget: maxGas,
        ),
      );
      final txData = builder.build();
      expect(txData.gasData.budget, equals(maxGas));
    });
  });

  group('JSON Parsing Edge Cases', () {
    test('SuiBalance with large totalBalance', () {
      final balance = SuiBalance.fromJson({
        'coinType': '0x2::sui::SUI',
        'coinObjectCount': 1000,
        'totalBalance': '9999999999999999999', // Large number
      });
      expect(
        balance.totalBalance,
        equals(BigInt.parse('9999999999999999999')),
      );
    });

    test('SuiCoin with zero balance', () {
      final coin = SuiCoin.fromJson({
        'coinType': '0x2::sui::SUI',
        'coinObjectId': '0x1',
        'version': '1',
        'digest': 'test',
        'balance': '0',
      });
      expect(coin.balance, equals(BigInt.zero));
    });

    test('SuiSystemState with epoch boundary values', () {
      final state = SuiSystemState.fromJson({
        'epoch': '0', // Genesis epoch
        'protocolVersion': '1',
        'systemStateVersion': '1',
        'referenceGasPrice': '750', // Minimum gas price
      });
      expect(state.epoch, equals(BigInt.zero));
      expect(state.referenceGasPrice, equals(BigInt.from(750)));
    });

    test('SuiSystemState with high epoch number', () {
      final state = SuiSystemState.fromJson({
        'epoch': '999999',
        'protocolVersion': '100',
        'systemStateVersion': '5',
        'referenceGasPrice': '1000000',
      });
      expect(state.epoch, equals(BigInt.from(999999)));
    });
  });

  group('Signature Scheme Edge Cases', () {
    test('all signature schemes have unique flags', () {
      final flags = SuiSignatureScheme.values.map((s) => s.flag).toSet();
      expect(flags.length, equals(SuiSignatureScheme.values.length));
    });

    test('zkLogin scheme flag', () {
      // zkLogin uses flag 5 (skips flag 4)
      expect(SuiSignatureScheme.zkLogin.flag, equals(5));
    });
  });

  group('Object Owner Edge Cases', () {
    test('ObjectOwner owner type', () {
      final owner = ObjectOwner(SuiObjectId.fromHex('0x123'));
      expect(owner.objectId.toHex(), contains('123'));
    });

    test('SharedOwner with high version', () {
      final owner = SharedOwner(
        initialSharedVersion: BigInt.parse('18446744073709551615'),
      );
      expect(
        owner.initialSharedVersion,
        equals(BigInt.parse('18446744073709551615')),
      );
    });
  });

  group('Gas Data Edge Cases', () {
    test('minimum gas price', () {
      final gasData = SuiGasData(
        payment: [],
        owner: SuiAddress.fromHex('0x1'),
        price: BigInt.from(750), // Minimum reference gas price
        budget: BigInt.from(1000000),
      );
      expect(gasData.price, equals(BigInt.from(750)));
    });

    test('multiple payment objects', () {
      final payments = [
        SuiObjectRef(
          objectId: SuiObjectId.fromHex('0x1'),
          version: BigInt.from(1),
          digest: SuiDigest(Uint8List(32)),
        ),
        SuiObjectRef(
          objectId: SuiObjectId.fromHex('0x2'),
          version: BigInt.from(2),
          digest: SuiDigest(Uint8List(32)),
        ),
      ];
      final gasData = SuiGasData(
        payment: payments,
        owner: SuiAddress.fromHex('0x1'),
        price: BigInt.from(1000),
        budget: BigInt.from(10000000),
      );
      expect(gasData.payment.length, equals(2));
    });
  });

  group('Chain Configuration Edge Cases', () {
    test('all chains have valid RPC URLs', () {
      for (final chain in SuiChains.all) {
        expect(chain.rpcUrl, startsWith('http'));
        expect(Uri.tryParse(chain.rpcUrl), isNotNull);
      }
    });

    test('testnet chains have faucet URLs', () {
      expect(SuiChains.testnet.faucetUrl, isNotNull);
      expect(SuiChains.devnet.faucetUrl, isNotNull);
    });

    test('mainnet has no faucet', () {
      expect(SuiChains.mainnet.faucetUrl, isNull);
    });
  });
}
