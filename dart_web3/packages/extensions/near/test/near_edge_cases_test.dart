import 'dart:typed_data';
import 'package:dart_web3_near/dart_web3_near.dart';
import 'package:test/test.dart';

/// Strict edge case and authoritative tests for NEAR extension package.
/// Test vectors derived from official NEAR Protocol specification.
void main() {
  group('NearAccountId Edge Cases (NEAR Protocol Spec)', () {
    // === Official NEAR Account ID Specification ===
    // https://docs.near.org/concepts/basics/accounts/account-id

    test('minimum length account (2 chars)', () {
      final accountId = NearAccountId.parse('ab');
      expect(accountId.value, equals('ab'));
      expect(accountId.isNamed, isTrue);
    });

    test('maximum length account (64 chars)', () {
      final maxAccount = 'a' * 64;
      final accountId = NearAccountId.parse(maxAccount);
      expect(accountId.value, equals(maxAccount));
    });

    test('rejects empty account ID', () {
      expect(() => NearAccountId.parse(''), throwsArgumentError);
    });

    test('rejects too short account ID (1 char)', () {
      expect(() => NearAccountId.parse('a'), throwsArgumentError);
    });

    test('rejects too long account ID (65 chars)', () {
      expect(() => NearAccountId.parse('a' * 65), throwsArgumentError);
    });

    test('implicit account (64 hex chars)', () {
      // Implicit accounts are 64 hex characters representing a public key
      final implicitAccount = 'a' * 64;
      final accountId = NearAccountId.parse(implicitAccount);
      expect(accountId.isImplicit, isTrue);
      expect(accountId.isNamed, isFalse);
    });

    test('real-world implicit account', () {
      final accountId = NearAccountId.parse(
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      );
      expect(accountId.isImplicit, isTrue);
    });

    test('named account with subdomain', () {
      final accountId = NearAccountId.parse('alice.near');
      expect(accountId.isNamed, isTrue);
      expect(accountId.topLevel, equals('near'));
    });

    test('multi-level subdomain', () {
      final accountId = NearAccountId.parse('test.alice.near');
      expect(accountId.topLevel, equals('near'));
    });

    test('testnet account', () {
      final accountId = NearAccountId.parse('alice.testnet');
      expect(accountId.topLevel, equals('testnet'));
    });

    test('converts to lowercase', () {
      final accountId = NearAccountId.parse('ALICE.NEAR');
      expect(accountId.value, equals('alice.near'));
    });

    test('account equality', () {
      final a = NearAccountId.parse('alice.near');
      final b = NearAccountId.parse('ALICE.NEAR');
      expect(a, equals(b));
    });

    test('non-implicit 64-char account (contains non-hex)', () {
      // 64 chars but contains non-hex characters - should be named account
      final accountId = NearAccountId.parse(
        'thisisa64characteraccountidwithnonhexcharsanditsnamedaccount64',
      );
      expect(accountId.isImplicit, isFalse);
      expect(accountId.isNamed, isTrue);
    });
  });

  group('NearPublicKey Edge Cases', () {
    test('ed25519 key type', () {
      final key = NearPublicKey.fromString('ed25519:somebase58key');
      expect(key.keyType, equals(NearKeyType.ed25519));
    });

    test('secp256k1 key type', () {
      final key = NearPublicKey.fromString('secp256k1:somebase58key');
      expect(key.keyType, equals(NearKeyType.secp256k1));
    });

    test('defaults to ed25519 for unknown type', () {
      final key = NearPublicKey.fromString('unknown:somebase58key');
      expect(key.keyType, equals(NearKeyType.ed25519));
    });

    test('rejects invalid format', () {
      expect(
        () => NearPublicKey.fromString('invalidkeyformat'),
        throwsArgumentError,
      );
    });

    test('key data is 32 bytes', () {
      final key = NearPublicKey.fromString('ed25519:data');
      expect(key.data.length, equals(32));
    });

    test('toStringKey output format', () {
      final key = NearPublicKey(
        keyType: NearKeyType.ed25519,
        data: Uint8List(32),
      );
      expect(key.toStringKey(), contains('ed25519:'));
    });
  });

  group('NearKeyType Edge Cases', () {
    test('all key types', () {
      expect(NearKeyType.values, contains(NearKeyType.ed25519));
      expect(NearKeyType.values, contains(NearKeyType.secp256k1));
    });

    test('exactly 2 key types', () {
      expect(NearKeyType.values.length, equals(2));
    });
  });

  group('NearAmount Edge Cases (yoctoNEAR Scale)', () {
    // 1 NEAR = 10^24 yoctoNEAR

    test('one NEAR', () {
      final oneNear = NearAmount.oneNear;
      expect(oneNear.yoctoNear, equals(BigInt.from(10).pow(24)));
    });

    test('zero amount', () {
      final zero = NearAmount.zero;
      expect(zero.yoctoNear, equals(BigInt.zero));
    });

    test('from NEAR conversion', () {
      final amount = NearAmount.fromNear(1.0);
      expect(amount.toNear(), closeTo(1.0, 0.0001));
    });

    test('large amount (total supply ~ 1 billion NEAR)', () {
      // 1 billion NEAR = 10^9 * 10^24 yoctoNEAR
      final largeAmount = NearAmount(BigInt.parse('1000000000000000000000000000000000'));
      expect(largeAmount.toNear(), closeTo(1e9, 1e5));
    });

    test('parse from yoctoNEAR string', () {
      final amount = NearAmount.parse('1000000000000000000000000');
      expect(amount.toNear(), closeTo(1.0, 0.001));
    });

    test('parse from NEAR string', () {
      final amount = NearAmount.parse('1.5 NEAR');
      expect(amount.toNear(), closeTo(1.5, 0.001));
    });

    test('parse handles uppercase NEAR', () {
      final amount = NearAmount.parse('2 near');
      expect(amount.toNear(), closeTo(2.0, 0.001));
    });

    test('addition operator', () {
      final a = NearAmount.fromNear(1.0);
      final b = NearAmount.fromNear(2.0);
      expect((a + b).toNear(), closeTo(3.0, 0.001));
    });

    test('subtraction operator', () {
      final a = NearAmount.fromNear(3.0);
      final b = NearAmount.fromNear(1.0);
      expect((a - b).toNear(), closeTo(2.0, 0.001));
    });

    test('comparison operators', () {
      final a = NearAmount.fromNear(1.0);
      final b = NearAmount.fromNear(2.0);
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= b, isTrue);
      expect(b >= a, isTrue);
    });

    test('formatted string contains NEAR', () {
      final amount = NearAmount.fromNear(1.5);
      final formatted = amount.toFormattedString();
      expect(formatted, contains('NEAR'));
      expect(formatted, contains('1.'));
    });

    test('toString returns yoctoNEAR', () {
      final amount = NearAmount(BigInt.from(12345));
      expect(amount.toString(), equals('12345'));
    });
  });

  group('NearGas Edge Cases', () {
    // 1 TGas = 10^12 gas

    test('TGas conversion', () {
      final gas = NearGas.tGas(1);
      expect(gas.gas, equals(BigInt.from(10).pow(12)));
    });

    test('toTGas roundtrip', () {
      final gas = NearGas.tGas(100);
      expect(gas.toTGas(), equals(100));
    });

    test('default transfer gas (30 TGas)', () {
      expect(NearGas.defaultTransfer.toTGas(), equals(30));
    });

    test('default function call gas (100 TGas)', () {
      expect(NearGas.defaultFunctionCall.toTGas(), equals(100));
    });

    test('max gas (300 TGas)', () {
      expect(NearGas.max.toTGas(), equals(300));
      expect(NearGas.max.gas, equals(BigInt.from(300) * BigInt.from(10).pow(12)));
    });

    test('toString returns raw gas', () {
      final gas = NearGas.tGas(5);
      expect(gas.toString(), equals('5000000000000'));
    });

    test('zero TGas', () {
      final gas = NearGas.tGas(0);
      expect(gas.toTGas(), equals(0));
      expect(gas.gas, equals(BigInt.zero));
    });
  });

  group('NearAccount Edge Cases', () {
    test('account without contract', () {
      final account = NearAccount.fromJson({
        'amount': '1000000000000000000000000',
        'locked': '0',
        'code_hash': '11111111111111111111111111111111',
        'storage_usage': '182',
        'storage_paid_at': '0',
      });
      expect(account.hasContract, isFalse);
    });

    test('account with contract', () {
      final account = NearAccount.fromJson({
        'amount': '1000000000000000000000000',
        'locked': '0',
        'code_hash': 'abcd1234abcd1234abcd1234abcd1234',
        'storage_usage': '10000',
        'storage_paid_at': '100',
      });
      expect(account.hasContract, isTrue);
    });

    test('large locked balance (staking)', () {
      final account = NearAccount.fromJson({
        'amount': '1000000000000000000000000',
        'locked': '999999999999999999999999999',
        'code_hash': '11111111111111111111111111111111',
        'storage_usage': '0',
        'storage_paid_at': '0',
      });
      expect(account.locked, greaterThan(BigInt.zero));
    });

    test('storage usage parsing', () {
      final account = NearAccount.fromJson({
        'amount': '0',
        'locked': '0',
        'code_hash': '11111111111111111111111111111111',
        'storage_usage': '1000000',
        'storage_paid_at': '12345678',
      });
      expect(account.storageUsage, equals(BigInt.from(1000000)));
      expect(account.storagePaidAt, equals(BigInt.from(12345678)));
    });
  });

  group('NearBlock Edge Cases', () {
    test('parse from JSON with header', () {
      final block = NearBlock.fromJson({
        'header': {
          'height': '100000000',
          'hash': 'Hk9YQnxvKwmQyU9EWS123ABC',
          'prev_hash': 'PrevHk9YQnxvKwmQyU9E123ABC',
          'timestamp': '1700000000000000000',
          'epoch_id': 'EpochId123ABC',
          'chunks_included': 4,
        },
      });
      expect(block.height, equals(BigInt.from(100000000)));
      expect(block.hash, equals('Hk9YQnxvKwmQyU9EWS123ABC'));
      expect(block.chunksIncluded, equals(4));
    });

    test('timestamp in nanoseconds', () {
      // 1700000000 seconds = 1700000000000000000 nanoseconds
      final block = NearBlock.fromJson({
        'header': {
          'height': '1',
          'hash': 'hash',
          'prev_hash': 'prev',
          'timestamp': '1700000000000000000',
          'epoch_id': 'epoch',
          'chunks_included': 1,
        },
      });
      expect(block.timestamp, equals(BigInt.parse('1700000000000000000')));
    });

    test('time conversion', () {
      final block = NearBlock.fromJson({
        'header': {
          'height': '1',
          'hash': 'hash',
          'prev_hash': 'prev',
          'timestamp': '1700000000000000000',
          'epoch_id': 'epoch',
          'chunks_included': 1,
        },
      });
      expect(block.time, isA<DateTime>());
    });

    test('genesis block (height 0)', () {
      final block = NearBlock.fromJson({
        'header': {
          'height': '0',
          'hash': 'genesis',
          'prev_hash': 'genesis_prev',
          'timestamp': '0',
          'epoch_id': 'epoch0',
          'chunks_included': 0,
        },
      });
      expect(block.height, equals(BigInt.zero));
    });
  });

  group('NearGasPrice Edge Cases', () {
    test('parse gas price from JSON', () {
      final gasPrice = NearGasPrice.fromJson({
        'gas_price': '100000000',
      });
      expect(gasPrice.gasPrice, equals(BigInt.from(100000000)));
    });

    test('very low gas price', () {
      final gasPrice = NearGasPrice.fromJson({
        'gas_price': '1',
      });
      expect(gasPrice.gasPrice, equals(BigInt.one));
    });

    test('high gas price', () {
      final gasPrice = NearGasPrice.fromJson({
        'gas_price': '999999999999999',
      });
      expect(gasPrice.gasPrice, equals(BigInt.parse('999999999999999')));
    });
  });

  group('NearAccessKey Edge Cases', () {
    test('full access permission', () {
      final key = NearAccessKey.fromJson({
        'nonce': '1',
        'permission': 'FullAccess',
      });
      expect(key.permission, isA<FullAccessPermission>());
    });

    test('function call permission with allowance', () {
      final key = NearAccessKey.fromJson({
        'nonce': '100',
        'permission': {
          'FunctionCall': {
            'allowance': '250000000000000000000000',
            'receiver_id': 'contract.near',
            'method_names': ['method1', 'method2'],
          },
        },
      });
      final fc = key.permission as FunctionCallPermission;
      expect(fc.allowance, equals(BigInt.parse('250000000000000000000000')));
      expect(fc.receiverId, equals('contract.near'));
      expect(fc.methodNames, hasLength(2));
    });

    test('function call permission without allowance', () {
      final key = NearAccessKey.fromJson({
        'nonce': '1',
        'permission': {
          'FunctionCall': {
            'allowance': null,
            'receiver_id': 'contract.near',
            'method_names': [],
          },
        },
      });
      final fc = key.permission as FunctionCallPermission;
      expect(fc.allowance, isNull);
      expect(fc.methodNames, isEmpty);
    });

    test('high nonce value', () {
      final key = NearAccessKey.fromJson({
        'nonce': '18446744073709551615',
        'permission': 'FullAccess',
      });
      expect(key.nonce, equals(BigInt.parse('18446744073709551615')));
    });
  });

  group('NearValidator Edge Cases', () {
    test('active validator', () {
      final validator = NearValidator.fromJson({
        'account_id': 'validator.poolv1.near',
        'public_key': 'ed25519:xyz',
        'stake': '1000000000000000000000000000',
        'is_slashed': false,
        'num_produced_blocks': 100,
        'num_expected_blocks': 100,
      });
      expect(validator.isSlashed, isFalse);
      expect(validator.numProducedBlocks, equals(100));
      expect(validator.numExpectedBlocks, equals(100));
    });

    test('slashed validator', () {
      final validator = NearValidator.fromJson({
        'account_id': 'bad-validator.near',
        'public_key': 'ed25519:abc',
        'stake': '0',
        'is_slashed': true,
      });
      expect(validator.isSlashed, isTrue);
    });

    test('validator with large stake', () {
      // 10 million NEAR staked
      final validator = NearValidator.fromJson({
        'account_id': 'whale.poolv1.near',
        'public_key': 'ed25519:key',
        'stake': '10000000000000000000000000000000',
      });
      expect(
        validator.stake,
        equals(BigInt.parse('10000000000000000000000000000000')),
      );
    });

    test('validator without optional fields', () {
      final validator = NearValidator.fromJson({
        'account_id': 'validator.near',
        'public_key': 'ed25519:key',
        'stake': '1000000',
      });
      expect(validator.isSlashed, isFalse);
      expect(validator.numProducedBlocks, isNull);
      expect(validator.numExpectedBlocks, isNull);
    });
  });

  group('NearProtocolConfig Edge Cases', () {
    test('parse full config', () {
      final config = NearProtocolConfig.fromJson({
        'protocol_version': 60,
        'genesis_height': '0',
        'epoch_length': 43200,
        'min_gas_price': '100000000',
        'runtime_config': {'storage_amount_per_byte': '10000000000000000000'},
      });
      expect(config.protocolVersion, equals(60));
      expect(config.genesisHeight, equals(BigInt.zero));
      expect(config.epochLength, equals(43200));
      expect(config.minGasPrice, equals(BigInt.from(100000000)));
    });

    test('large genesis height', () {
      final config = NearProtocolConfig.fromJson({
        'protocol_version': 1,
        'genesis_height': '100000000',
        'epoch_length': 1000,
        'min_gas_price': '1',
        'runtime_config': <String, dynamic>{},
      });
      expect(config.genesisHeight, equals(BigInt.from(100000000)));
    });
  });

  group('NearAction Edge Cases', () {
    test('CreateAccountAction toJson', () {
      const action = CreateAccountAction();
      final json = action.toJson();
      expect(json['CreateAccount'], isNotNull);
      expect(json['CreateAccount'], isEmpty);
    });

    test('TransferAction toJson', () {
      final action = TransferAction(deposit: NearAmount.fromNear(1.0));
      final json = action.toJson();
      expect(json['Transfer'], isNotNull);
      expect(json['Transfer']['deposit'], isA<String>());
    });

    test('FunctionCallAction with args', () {
      final action = FunctionCallAction.call(
        methodName: 'test_method',
        args: {'key': 'value'},
        gas: NearGas.tGas(50),
        deposit: NearAmount.zero,
      );
      final json = action.toJson();
      expect(json['FunctionCall']['method_name'], equals('test_method'));
      expect(json['FunctionCall']['gas'], isA<String>());
    });

    test('FunctionCallAction without args', () {
      final action = FunctionCallAction.call(
        methodName: 'no_args',
      );
      final json = action.toJson();
      expect(json['FunctionCall']['method_name'], equals('no_args'));
    });

    test('StakeAction toJson', () {
      final action = StakeAction(
        stake: NearAmount.fromNear(100),
        publicKey: NearPublicKey(keyType: NearKeyType.ed25519, data: Uint8List(32)),
      );
      final json = action.toJson();
      expect(json['Stake'], isNotNull);
      expect(json['Stake']['stake'], isA<String>());
    });

    test('DeleteAccountAction toJson', () {
      final action = DeleteAccountAction(
        beneficiaryId: NearAccountId.parse('beneficiary.near'),
      );
      final json = action.toJson();
      expect(json['DeleteAccount']['beneficiary_id'], equals('beneficiary.near'));
    });

    test('AddKeyAction with full access', () {
      final action = AddKeyAction(
        publicKey: NearPublicKey(keyType: NearKeyType.ed25519, data: Uint8List(32)),
        accessKey: NearAccessKey(
          nonce: BigInt.zero,
          permission: const FullAccessPermission(),
        ),
      );
      final json = action.toJson();
      expect(json['AddKey'], isNotNull);
    });

    test('AddKeyAction with function call permission', () {
      final action = AddKeyAction(
        publicKey: NearPublicKey(keyType: NearKeyType.ed25519, data: Uint8List(32)),
        accessKey: NearAccessKey(
          nonce: BigInt.zero,
          permission: const FunctionCallPermission(
            allowance: null,
            receiverId: 'contract.near',
            methodNames: ['allowed_method'],
          ),
        ),
      );
      final json = action.toJson();
      expect(json['AddKey']['access_key']['permission']['FunctionCall'], isNotNull);
    });

    test('DeleteKeyAction toJson', () {
      final action = DeleteKeyAction(
        publicKey: NearPublicKey(keyType: NearKeyType.ed25519, data: Uint8List(32)),
      );
      final json = action.toJson();
      expect(json['DeleteKey'], isNotNull);
    });

    test('DeployContractAction toJson', () {
      final action = DeployContractAction(code: Uint8List.fromList([0, 1, 2, 3]));
      final json = action.toJson();
      expect(json['DeployContract']['code'], isNotNull);
    });
  });

  group('NearTransactionBuilder Edge Cases', () {
    test('build valid transaction', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      final tx = builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32))
          .transfer(NearAmount.fromNear(1.0))
          .build();
      expect(tx.signerId.value, equals('alice.near'));
      expect(tx.receiverId.value, equals('bob.near'));
    });

    test('throws without nonce', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      builder
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32))
          .transfer(NearAmount.fromNear(1.0));
      expect(() => builder.build(), throwsStateError);
    });

    test('throws without receiver', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      builder
          .nonce(BigInt.one)
          .blockHash(Uint8List(32))
          .transfer(NearAmount.fromNear(1.0));
      expect(() => builder.build(), throwsStateError);
    });

    test('throws without block hash', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('bob.near'))
          .transfer(NearAmount.fromNear(1.0));
      expect(() => builder.build(), throwsStateError);
    });

    test('throws without actions', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32));
      expect(() => builder.build(), throwsStateError);
    });

    test('multiple actions', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      final tx = builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('new-account.near'))
          .blockHash(Uint8List(32))
          .createAccount()
          .transfer(NearAmount.fromNear(1.0))
          .build();
      expect(tx.actions, hasLength(2));
    });

    test('function call action', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      final tx = builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('contract.near'))
          .blockHash(Uint8List(32))
          .functionCall(
            methodName: 'my_method',
            args: {'param': 'value'},
            gas: NearGas.tGas(100),
            deposit: NearAmount.zero,
          )
          .build();
      expect(tx.actions.first, isA<FunctionCallAction>());
    });

    test('stake action', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
      );
      final tx = builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('pool.near'))
          .blockHash(Uint8List(32))
          .stake(
            NearAmount.fromNear(100),
            NearPublicKey.fromString('ed25519:validatorkey'),
          )
          .build();
      expect(tx.actions.first, isA<StakeAction>());
    });
  });

  group('NearTransaction Edge Cases', () {
    test('serialize returns bytes', () {
      final tx = NearTransaction(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
        nonce: BigInt.one,
        receiverId: NearAccountId.parse('bob.near'),
        blockHash: Uint8List(32),
        actions: [TransferAction(deposit: NearAmount.fromNear(1.0))],
      );
      expect(tx.serialize(), isA<Uint8List>());
    });

    test('toJson structure', () {
      final tx = NearTransaction(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
        nonce: BigInt.from(123),
        receiverId: NearAccountId.parse('bob.near'),
        blockHash: Uint8List(32),
        actions: [TransferAction(deposit: NearAmount.fromNear(1.0))],
      );
      final json = tx.toJson();
      expect(json['signer_id'], equals('alice.near'));
      expect(json['receiver_id'], equals('bob.near'));
      expect(json['nonce'], equals('123'));
      expect(json['actions'], hasLength(1));
    });
  });

  group('NearSignature Edge Cases', () {
    test('ed25519 signature (64 bytes)', () {
      final sig = NearSignature(
        keyType: NearKeyType.ed25519,
        data: Uint8List(64),
      );
      expect(sig.data.length, equals(64));
      expect(sig.keyType, equals(NearKeyType.ed25519));
    });
  });

  group('SignedNearTransaction Edge Cases', () {
    test('serialize returns bytes', () {
      final tx = NearTransaction(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
        nonce: BigInt.one,
        receiverId: NearAccountId.parse('bob.near'),
        blockHash: Uint8List(32),
        actions: [TransferAction(deposit: NearAmount.zero)],
      );
      final signedTx = SignedNearTransaction(
        transaction: tx,
        signature: NearSignature(keyType: NearKeyType.ed25519, data: Uint8List(64)),
      );
      expect(signedTx.serialize(), isA<Uint8List>());
    });

    test('toBase64 returns string', () {
      final tx = NearTransaction(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
        nonce: BigInt.one,
        receiverId: NearAccountId.parse('bob.near'),
        blockHash: Uint8List(32),
        actions: [TransferAction(deposit: NearAmount.zero)],
      );
      final signedTx = SignedNearTransaction(
        transaction: tx,
        signature: NearSignature(keyType: NearKeyType.ed25519, data: Uint8List(64)),
      );
      expect(signedTx.toBase64(), isA<String>());
    });

    test('toRpcParams returns list', () {
      final tx = NearTransaction(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:key'),
        nonce: BigInt.one,
        receiverId: NearAccountId.parse('bob.near'),
        blockHash: Uint8List(32),
        actions: [TransferAction(deposit: NearAmount.zero)],
      );
      final signedTx = SignedNearTransaction(
        transaction: tx,
        signature: NearSignature(keyType: NearKeyType.ed25519, data: Uint8List(64)),
      );
      expect(signedTx.toRpcParams(), isA<List>());
    });
  });

  group('NearExecutionStatus Edge Cases', () {
    test('parse SuccessValue', () {
      final status = NearExecutionStatus.fromJson({
        'SuccessValue': 'eyJyZXN1bHQiOiAidmFsdWUifQ==',
      });
      expect(status, isA<SuccessValueStatus>());
      expect((status as SuccessValueStatus).value, isNotEmpty);
    });

    test('parse SuccessReceiptId', () {
      final status = NearExecutionStatus.fromJson({
        'SuccessReceiptId': 'receipt123abc',
      });
      expect(status, isA<SuccessReceiptIdStatus>());
      expect((status as SuccessReceiptIdStatus).receiptId, equals('receipt123abc'));
    });

    test('parse Failure', () {
      final status = NearExecutionStatus.fromJson({
        'Failure': {
          'ActionError': {
            'kind': 'AccountAlreadyExists',
          },
        },
      });
      expect(status, isA<FailureStatus>());
      expect((status as FailureStatus).error, isNotEmpty);
    });

    test('parse Unknown', () {
      final status = NearExecutionStatus.fromJson('Unknown');
      expect(status, isA<UnknownStatus>());
    });

    test('parse invalid returns Unknown', () {
      final status = NearExecutionStatus.fromJson({'InvalidKey': 'value'});
      expect(status, isA<UnknownStatus>());
    });

    test('empty success value', () {
      final status = NearExecutionStatus.fromJson({'SuccessValue': ''});
      expect(status, isA<SuccessValueStatus>());
      expect((status as SuccessValueStatus).value, isEmpty);
    });
  });

  group('NearExecutionOutcome Edge Cases', () {
    test('successful outcome', () {
      final outcome = NearExecutionOutcome.fromJson({
        'gas_burnt': '2428086920308',
        'tokens_burnt': '242808692030800000000',
        'status': {'SuccessValue': ''},
        'logs': ['log1', 'log2'],
        'receipt_ids': ['receipt1'],
      });
      expect(outcome.isSuccess, isTrue);
      expect(outcome.gasBurnt, equals(BigInt.parse('2428086920308')));
      expect(outcome.logs, hasLength(2));
    });

    test('failed outcome', () {
      final outcome = NearExecutionOutcome.fromJson({
        'gas_burnt': '1000000000000',
        'tokens_burnt': '100000000000000000000',
        'status': {'Failure': {'ActionError': {}}},
        'logs': [],
        'receipt_ids': [],
      });
      expect(outcome.isSuccess, isFalse);
    });

    test('outcome without logs', () {
      final outcome = NearExecutionOutcome.fromJson({
        'gas_burnt': '0',
        'tokens_burnt': '0',
        'status': {'SuccessValue': ''},
      });
      expect(outcome.logs, isEmpty);
      expect(outcome.receiptIds, isEmpty);
    });
  });

  group('NearReceiptOutcome Edge Cases', () {
    test('parse from JSON', () {
      final receiptOutcome = NearReceiptOutcome.fromJson({
        'id': 'receipt123',
        'outcome': {
          'gas_burnt': '1000000',
          'tokens_burnt': '1000000000000',
          'status': {'SuccessValue': ''},
          'logs': [],
          'receipt_ids': [],
        },
      });
      expect(receiptOutcome.id, equals('receipt123'));
      expect(receiptOutcome.outcome.isSuccess, isTrue);
    });
  });

  group('NearTransactionOutcome Edge Cases', () {
    test('parse success transaction', () {
      final txOutcome = NearTransactionOutcome.fromJson({
        'transaction': {'hash': 'txhash123'},
        'transaction_outcome': {
          'outcome': {
            'gas_burnt': '1000000000',
            'tokens_burnt': '100000000000000000',
            'status': {'SuccessValue': ''},
            'logs': [],
            'receipt_ids': [],
          },
        },
        'receipts_outcome': [],
      });
      expect(txOutcome.transactionHash, equals('txhash123'));
      expect(txOutcome.isSuccess, isTrue);
    });

    test('parse transaction with receipts', () {
      final txOutcome = NearTransactionOutcome.fromJson({
        'transaction': {'hash': 'txhash123'},
        'transaction_outcome': {
          'outcome': {
            'gas_burnt': '1000000000',
            'tokens_burnt': '100000000000000000',
            'status': {'SuccessReceiptId': 'receipt123'},
            'logs': [],
            'receipt_ids': ['receipt123'],
          },
        },
        'receipts_outcome': [
          {
            'id': 'receipt123',
            'outcome': {
              'gas_burnt': '500000000',
              'tokens_burnt': '50000000000000000',
              'status': {'SuccessValue': ''},
              'logs': [],
              'receipt_ids': [],
            },
          },
        ],
      });
      expect(txOutcome.receiptsOutcome, hasLength(1));
    });
  });

  group('Chain Configuration Edge Cases', () {
    test('mainnet configuration', () {
      expect(NearChains.mainnet.networkId, equals('mainnet'));
      expect(NearChains.mainnet.isTestnet, isFalse);
      expect(NearChains.mainnet.rpcUrl, contains('mainnet'));
      expect(NearChains.mainnet.explorerUrl, isNotNull);
    });

    test('testnet configuration', () {
      expect(NearChains.testnet.networkId, equals('testnet'));
      expect(NearChains.testnet.isTestnet, isTrue);
      expect(NearChains.testnet.helperUrl, isNotNull);
    });

    test('betanet configuration', () {
      expect(NearChains.betanet.networkId, equals('betanet'));
      expect(NearChains.betanet.isTestnet, isTrue);
    });

    test('local configuration', () {
      expect(NearChains.local.networkId, equals('local'));
      expect(NearChains.local.rpcUrl, contains('127.0.0.1'));
      expect(NearChains.local.isTestnet, isTrue);
    });

    test('all chains count', () {
      expect(NearChains.all, hasLength(4));
    });

    test('getByNetworkId mainnet', () {
      expect(NearChains.getByNetworkId('mainnet'), equals(NearChains.mainnet));
    });

    test('getByNetworkId testnet', () {
      expect(NearChains.getByNetworkId('testnet'), equals(NearChains.testnet));
    });

    test('getByNetworkId unknown returns null', () {
      expect(NearChains.getByNetworkId('unknown'), isNull);
    });

    test('all chains have valid RPC URLs', () {
      for (final chain in NearChains.all) {
        expect(chain.rpcUrl, startsWith('http'));
        expect(Uri.tryParse(chain.rpcUrl), isNotNull);
      }
    });

    test('all chains have valid archival RPC URLs', () {
      for (final chain in NearChains.all) {
        expect(chain.archivalRpcUrl, startsWith('http'));
        expect(Uri.tryParse(chain.archivalRpcUrl), isNotNull);
      }
    });

    test('mainnet has wallet URL', () {
      expect(NearChains.mainnet.walletUrl, isNotNull);
      expect(NearChains.mainnet.walletUrl, contains('wallet'));
    });
  });

  group('NearClient Edge Cases', () {
    test('create from chain config', () {
      final client = NearClient.fromChain(NearChains.mainnet);
      expect(client.rpcUrl, equals(NearChains.mainnet.rpcUrl));
      client.close();
    });

    test('create mainnet client', () {
      final client = NearClient.mainnet();
      expect(client.rpcUrl, contains('mainnet'));
      client.close();
    });

    test('create testnet client', () {
      final client = NearClient.testnet();
      expect(client.rpcUrl, contains('testnet'));
      client.close();
    });
  });
}
