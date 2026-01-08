/// NEAR Protocol integration tests.
///
/// Tests the NEAR extension package types and utilities.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:web3_universal_near/web3_universal_near.dart';
import 'package:test/test.dart';

void main() {
  group('NEAR Integration Tests', () {
    group('NearAccountId', () {
      test('creates from string', () {
        final accountId = NearAccountId('alice.near');
        expect(accountId.value, equals('alice.near'));
        expect(accountId.toString(), equals('alice.near'));
      });

      test('parses valid account ID', () {
        final accountId = NearAccountId.parse('alice.near');
        expect(accountId.value, equals('alice.near'));
      });

      test('converts to lowercase', () {
        final accountId = NearAccountId.parse('Alice.Near');
        expect(accountId.value, equals('alice.near'));
      });

      test('identifies implicit accounts', () {
        final implicitHex = 'a' * 64;
        final accountId = NearAccountId(implicitHex);
        expect(accountId.isImplicit, isTrue);
        expect(accountId.isNamed, isFalse);
      });

      test('identifies named accounts', () {
        final accountId = NearAccountId('alice.near');
        expect(accountId.isNamed, isTrue);
        expect(accountId.isImplicit, isFalse);
      });

      test('extracts top-level account', () {
        final accountId = NearAccountId('app.alice.near');
        expect(accountId.topLevel, equals('near'));
      });

      test('throws on empty account ID', () {
        expect(
          () => NearAccountId.parse(''),
          throwsArgumentError,
        );
      });

      test('equality works correctly', () {
        final id1 = NearAccountId('alice.near');
        final id2 = NearAccountId('alice.near');
        final id3 = NearAccountId('bob.near');

        expect(id1, equals(id2));
        expect(id1, isNot(equals(id3)));
        expect(id1.hashCode, equals(id2.hashCode));
      });
    });

    group('NearPublicKey', () {
      test('creates with key type and data', () {
        final key = NearPublicKey(
          keyType: NearKeyType.ed25519,
          data: Uint8List(32),
        );
        expect(key.keyType, equals(NearKeyType.ed25519));
        expect(key.data.length, equals(32));
      });

      test('parses from string', () {
        final key = NearPublicKey.fromString('ed25519:placeholder');
        expect(key.keyType, equals(NearKeyType.ed25519));
      });

      test('converts to string', () {
        final key = NearPublicKey(
          keyType: NearKeyType.ed25519,
          data: Uint8List(32),
        );
        final str = key.toStringKey();
        expect(str.startsWith('ed25519:'), isTrue);
      });
    });

    group('NearAccessKey', () {
      test('creates from JSON with full access', () {
        final json = {
          'nonce': '100',
          'permission': 'FullAccess',
        };

        final accessKey = NearAccessKey.fromJson(json);

        expect(accessKey.nonce, equals(BigInt.from(100)));
        expect(accessKey.permission, isA<FullAccessPermission>());
      });

      test('creates from JSON with function call permission', () {
        final json = {
          'nonce': '50',
          'permission': {
            'FunctionCall': {
              'allowance': '1000000000000000000',
              'receiver_id': 'contract.near',
              'method_names': ['transfer', 'deposit'],
            },
          },
        };

        final accessKey = NearAccessKey.fromJson(json);

        expect(accessKey.nonce, equals(BigInt.from(50)));
        expect(accessKey.permission, isA<FunctionCallPermission>());

        final fcPerm = accessKey.permission as FunctionCallPermission;
        expect(fcPerm.receiverId, equals('contract.near'));
        expect(fcPerm.methodNames, contains('transfer'));
        expect(fcPerm.methodNames, contains('deposit'));
      });
    });

    group('NearAccount', () {
      test('creates from JSON', () {
        final json = {
          'amount': '1000000000000000000000000',
          'locked': '0',
          'code_hash': '11111111111111111111111111111111',
          'storage_usage': '1000',
          'storage_paid_at': '0',
        };

        final account = NearAccount.fromJson(json);

        expect(account.amount, equals(BigInt.parse('1000000000000000000000000')));
        expect(account.locked, equals(BigInt.zero));
        expect(account.hasContract, isFalse);
      });

      test('detects contract account', () {
        final json = {
          'amount': '1000000000000000000000000',
          'locked': '0',
          'code_hash': 'abcdef1234567890abcdef1234567890',
          'storage_usage': '5000',
          'storage_paid_at': '0',
        };

        final account = NearAccount.fromJson(json);
        expect(account.hasContract, isTrue);
      });
    });

    group('NearBlock', () {
      test('creates from JSON', () {
        final json = {
          'header': {
            'height': '100000',
            'hash': 'blockhash123',
            'prev_hash': 'prevhash123',
            'timestamp': '1704672000000000000',
            'epoch_id': 'epoch123',
            'chunks_included': 4,
          },
        };

        final block = NearBlock.fromJson(json);

        expect(block.height, equals(BigInt.from(100000)));
        expect(block.hash, equals('blockhash123'));
        expect(block.chunksIncluded, equals(4));
      });

      test('calculates block time', () {
        final json = {
          'header': {
            'height': '100000',
            'hash': 'blockhash123',
            'prev_hash': 'prevhash123',
            'timestamp': '1704672000000000000',
            'epoch_id': 'epoch123',
            'chunks_included': 4,
          },
        };

        final block = NearBlock.fromJson(json);
        expect(block.time, isA<DateTime>());
      });
    });

    group('NearAmount', () {
      test('creates from yoctoNEAR', () {
        final amount = NearAmount(BigInt.from(10).pow(24));
        expect(amount.toNear(), closeTo(1.0, 0.0001));
      });

      test('creates from NEAR', () {
        final amount = NearAmount.fromNear(2.5);
        expect(amount.yoctoNear, greaterThan(BigInt.zero));
      });

      test('parses from string with NEAR suffix', () {
        final amount = NearAmount.parse('1.5 NEAR');
        expect(amount.yoctoNear, greaterThan(BigInt.zero));
      });

      test('parses from string with yoctoNEAR', () {
        final amount = NearAmount.parse('1000000000000000000000000');
        expect(amount.toNear(), closeTo(1.0, 0.0001));
      });

      test('formats to string', () {
        final amount = NearAmount.oneNear;
        expect(amount.toFormattedString(), contains('NEAR'));
      });

      test('arithmetic operations', () {
        final a = NearAmount(BigInt.from(100));
        final b = NearAmount(BigInt.from(50));

        expect((a + b).yoctoNear, equals(BigInt.from(150)));
        expect((a - b).yoctoNear, equals(BigInt.from(50)));
      });

      test('comparison operations', () {
        final a = NearAmount(BigInt.from(100));
        final b = NearAmount(BigInt.from(50));

        expect(a > b, isTrue);
        expect(b < a, isTrue);
        expect(a >= a, isTrue);
        expect(b <= a, isTrue);
      });
    });

    group('NearGas', () {
      test('creates from TGas', () {
        final gas = NearGas.tGas(100);
        expect(gas.toTGas(), equals(100));
      });

      test('has default values', () {
        expect(NearGas.defaultTransfer.toTGas(), equals(30));
        expect(NearGas.defaultFunctionCall.toTGas(), equals(100));
      });

      test('has maximum value', () {
        expect(NearGas.max.toTGas(), equals(300));
      });
    });

    group('NearValidator', () {
      test('creates from JSON', () {
        final json = {
          'account_id': 'validator.pool',
          'public_key': 'ed25519:key123',
          'stake': '1000000000000000000000000000',
          'is_slashed': false,
          'num_produced_blocks': 100,
          'num_expected_blocks': 100,
        };

        final validator = NearValidator.fromJson(json);

        expect(validator.accountId, equals('validator.pool'));
        expect(validator.stake, greaterThan(BigInt.zero));
        expect(validator.isSlashed, isFalse);
      });
    });

    group('NearAction Types', () {
      test('creates CreateAccountAction', () {
        const action = CreateAccountAction();
        expect(action, isA<NearAction>());
        expect(action.toJson()['CreateAccount'], isNotNull);
      });

      test('creates TransferAction', () {
        final action = TransferAction(deposit: NearAmount.oneNear);
        expect(action, isA<NearAction>());
        expect(action.toJson()['Transfer'], isNotNull);
      });

      test('creates FunctionCallAction', () {
        final action = FunctionCallAction.call(
          methodName: 'transfer',
          args: {'recipient': 'bob.near', 'amount': '100'},
        );
        expect(action, isA<NearAction>());
        expect(action.methodName, equals('transfer'));
        expect(action.toJson()['FunctionCall'], isNotNull);
      });

      test('creates DeployContractAction', () {
        final action = DeployContractAction(
          code: Uint8List.fromList([0, 97, 115, 109]),
        );
        expect(action, isA<NearAction>());
        expect(action.toJson()['DeployContract'], isNotNull);
      });

      test('creates StakeAction', () {
        final action = StakeAction(
          stake: NearAmount.oneNear,
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );
        expect(action, isA<NearAction>());
        expect(action.toJson()['Stake'], isNotNull);
      });

      test('creates AddKeyAction', () {
        final action = AddKeyAction(
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          accessKey: NearAccessKey(
            nonce: BigInt.zero,
            permission: const FullAccessPermission(),
          ),
        );
        expect(action, isA<NearAction>());
        expect(action.toJson()['AddKey'], isNotNull);
      });

      test('creates DeleteKeyAction', () {
        final action = DeleteKeyAction(
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );
        expect(action, isA<NearAction>());
        expect(action.toJson()['DeleteKey'], isNotNull);
      });

      test('creates DeleteAccountAction', () {
        final action = DeleteAccountAction(
          beneficiaryId: NearAccountId('beneficiary.near'),
        );
        expect(action, isA<NearAction>());
        expect(action.toJson()['DeleteAccount'], isNotNull);
      });
    });

    group('NearTransaction', () {
      test('creates with required fields', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        expect(tx.signerId.value, equals('alice.near'));
        expect(tx.receiverId.value, equals('bob.near'));
        expect(tx.actions.length, equals(1));
      });

      test('serializes to bytes', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        final serialized = tx.serialize();
        expect(serialized, isA<Uint8List>());
      });

      test('converts to JSON', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        final json = tx.toJson();
        expect(json['signer_id'], equals('alice.near'));
        expect(json['receiver_id'], equals('bob.near'));
        expect(json['actions'], isNotEmpty);
      });
    });

    group('NearTransactionBuilder', () {
      test('builds transfer transaction', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        final tx = builder
            .nonce(BigInt.from(1))
            .receiver(NearAccountId('bob.near'))
            .blockHash(Uint8List(32))
            .transfer(NearAmount.oneNear)
            .build();

        expect(tx.actions.length, equals(1));
        expect(tx.actions.first, isA<TransferAction>());
      });

      test('builds function call transaction', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        final tx = builder
            .nonce(BigInt.from(1))
            .receiver(NearAccountId('contract.near'))
            .blockHash(Uint8List(32))
            .functionCall(
              methodName: 'transfer',
              args: {'amount': '100'},
            )
            .build();

        expect(tx.actions.length, equals(1));
        expect(tx.actions.first, isA<FunctionCallAction>());
      });

      test('builds multi-action transaction', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        final tx = builder
            .nonce(BigInt.from(1))
            .receiver(NearAccountId('new.alice.near'))
            .blockHash(Uint8List(32))
            .createAccount()
            .transfer(NearAmount.fromNear(0.1))
            .addKey(
              NearPublicKey(keyType: NearKeyType.ed25519, data: Uint8List(32)),
              NearAccessKey(
                nonce: BigInt.zero,
                permission: const FullAccessPermission(),
              ),
            )
            .build();

        expect(tx.actions.length, equals(3));
      });

      test('throws without nonce', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        builder
            .receiver(NearAccountId('bob.near'))
            .blockHash(Uint8List(32))
            .transfer(NearAmount.oneNear);

        expect(() => builder.build(), throwsStateError);
      });

      test('throws without receiver', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        builder
            .nonce(BigInt.from(1))
            .blockHash(Uint8List(32))
            .transfer(NearAmount.oneNear);

        expect(() => builder.build(), throwsStateError);
      });

      test('throws without actions', () {
        final builder = NearTransactionBuilder(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
        );

        builder
            .nonce(BigInt.from(1))
            .receiver(NearAccountId('bob.near'))
            .blockHash(Uint8List(32));

        expect(() => builder.build(), throwsStateError);
      });
    });

    group('SignedNearTransaction', () {
      test('creates with transaction and signature', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        final signedTx = SignedNearTransaction(
          transaction: tx,
          signature: NearSignature(
            keyType: NearKeyType.ed25519,
            data: Uint8List(64),
          ),
        );

        expect(signedTx.transaction, equals(tx));
        expect(signedTx.signature.data.length, equals(64));
      });

      test('serializes to base64', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        final signedTx = SignedNearTransaction(
          transaction: tx,
          signature: NearSignature(
            keyType: NearKeyType.ed25519,
            data: Uint8List(64),
          ),
        );

        final base64 = signedTx.toBase64();
        expect(base64, isA<String>());
      });

      test('converts to RPC params', () {
        final tx = NearTransaction(
          signerId: NearAccountId('alice.near'),
          publicKey: NearPublicKey(
            keyType: NearKeyType.ed25519,
            data: Uint8List(32),
          ),
          nonce: BigInt.from(1),
          receiverId: NearAccountId('bob.near'),
          blockHash: Uint8List(32),
          actions: [TransferAction(deposit: NearAmount.oneNear)],
        );

        final signedTx = SignedNearTransaction(
          transaction: tx,
          signature: NearSignature(
            keyType: NearKeyType.ed25519,
            data: Uint8List(64),
          ),
        );

        final params = signedTx.toRpcParams();
        expect(params, isA<List>());
        expect(params.length, equals(1));
      });
    });

    group('NearExecutionStatus', () {
      test('parses SuccessValue', () {
        final json = {'SuccessValue': 'base64data'};
        final status = NearExecutionStatus.fromJson(json);
        expect(status, isA<SuccessValueStatus>());
        expect((status as SuccessValueStatus).value, equals('base64data'));
      });

      test('parses SuccessReceiptId', () {
        final json = {'SuccessReceiptId': 'receiptid123'};
        final status = NearExecutionStatus.fromJson(json);
        expect(status, isA<SuccessReceiptIdStatus>());
      });

      test('parses Failure', () {
        final json = {'Failure': {'error': 'some error'}};
        final status = NearExecutionStatus.fromJson(json);
        expect(status, isA<FailureStatus>());
      });

      test('parses Unknown', () {
        const json = 'Unknown';
        final status = NearExecutionStatus.fromJson(json);
        expect(status, isA<UnknownStatus>());
      });
    });

    group('NearProtocolConfig', () {
      test('creates from JSON', () {
        final json = {
          'protocol_version': 60,
          'genesis_height': '0',
          'epoch_length': 43200,
          'min_gas_price': '100000000',
          'runtime_config': {'storage_amount_per_byte': '10000000000000000000'},
        };

        final config = NearProtocolConfig.fromJson(json);

        expect(config.protocolVersion, equals(60));
        expect(config.epochLength, equals(43200));
        expect(config.minGasPrice, equals(BigInt.from(100000000)));
      });
    });
  });
}
