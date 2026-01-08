import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3_universal_near/web3_universal_near.dart';

void main() {
  group('NearChains', () {
    test('should have mainnet configuration', () {
      expect(NearChains.mainnet.networkId, equals('mainnet'));
      expect(NearChains.mainnet.name, equals('NEAR Mainnet'));
      expect(NearChains.mainnet.rpcUrl, contains('mainnet'));
      expect(NearChains.mainnet.isTestnet, isFalse);
    });

    test('should have testnet configuration', () {
      expect(NearChains.testnet.networkId, equals('testnet'));
      expect(NearChains.testnet.name, equals('NEAR Testnet'));
      expect(NearChains.testnet.rpcUrl, contains('testnet'));
      expect(NearChains.testnet.isTestnet, isTrue);
    });

    test('all should contain all networks', () {
      expect(NearChains.all.length, equals(4));
    });

    test('getByNetworkId should return correct chain', () {
      expect(
        NearChains.getByNetworkId('mainnet'),
        equals(NearChains.mainnet),
      );
      expect(
        NearChains.getByNetworkId('testnet'),
        equals(NearChains.testnet),
      );
      expect(NearChains.getByNetworkId('unknown'), isNull);
    });
  });

  group('NearAccountId', () {
    test('should parse valid account ID', () {
      final accountId = NearAccountId.parse('alice.near');
      expect(accountId.value, equals('alice.near'));
      expect(accountId.isNamed, isTrue);
      expect(accountId.isImplicit, isFalse);
    });

    test('should detect implicit account', () {
      // Implicit account ID is a 64-character hex string (public key)
      final accountId = NearAccountId.parse(
        'abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234',
      );
      expect(accountId.isImplicit, isTrue);
      expect(accountId.isNamed, isFalse);
    });

    test('should get top level account', () {
      final accountId = NearAccountId.parse('alice.testnet');
      expect(accountId.topLevel, equals('testnet'));
    });

    test('should throw for empty account ID', () {
      expect(() => NearAccountId.parse(''), throwsArgumentError);
    });
  });

  group('NearAmount', () {
    test('should create from yoctoNEAR', () {
      final amount = NearAmount(BigInt.parse('1000000000000000000000000'));
      expect(amount.toNear(), closeTo(1.0, 0.001));
    });

    test('should create from NEAR', () {
      final amount = NearAmount.fromNear(1.5);
      expect(amount.toNear(), closeTo(1.5, 0.001));
    });

    test('should parse from string', () {
      final amount = NearAmount.parse('1 NEAR');
      expect(amount.toNear(), closeTo(1.0, 0.001));
    });

    test('should add amounts', () {
      final a = NearAmount.fromNear(1.0);
      final b = NearAmount.fromNear(0.5);
      final result = a + b;
      expect(result.toNear(), closeTo(1.5, 0.001));
    });

    test('should format to string', () {
      final amount = NearAmount.fromNear(1.5);
      expect(amount.toFormattedString(), contains('NEAR'));
    });
  });

  group('NearGas', () {
    test('should create from TGas', () {
      final gas = NearGas.tGas(30);
      expect(gas.toTGas(), equals(30));
    });

    test('should have default values', () {
      expect(NearGas.defaultTransfer.toTGas(), equals(30));
      expect(NearGas.defaultFunctionCall.toTGas(), equals(100));
    });

    test('max gas should be 300 TGas', () {
      expect(NearGas.max.toTGas(), equals(300));
    });
  });

  group('NearAccount', () {
    test('should parse from JSON', () {
      final account = NearAccount.fromJson({
        'amount': '1000000000000000000000000',
        'locked': '0',
        'code_hash': '11111111111111111111111111111111',
        'storage_usage': '182',
        'storage_paid_at': '0',
      });
      expect(account.hasContract, isFalse);
      expect(account.storageUsage, equals(BigInt.from(182)));
    });

    test('should detect contract', () {
      final account = NearAccount.fromJson({
        'amount': '1000000000000000000000000',
        'locked': '0',
        'code_hash': 'abcd1234abcd1234abcd1234abcd1234',
        'storage_usage': '1000',
        'storage_paid_at': '0',
      });
      expect(account.hasContract, isTrue);
    });
  });

  group('NearBlock', () {
    test('should parse from JSON', () {
      final block = NearBlock.fromJson({
        'header': {
          'height': '100000000',
          'hash': 'blockhash123',
          'prev_hash': 'prevhash123',
          'timestamp': '1700000000000000000',
          'epoch_id': 'epoch123',
          'chunks_included': 4,
        },
      });
      expect(block.height, equals(BigInt.from(100000000)));
      expect(block.chunksIncluded, equals(4));
    });
  });

  group('NearAccessKey', () {
    test('should parse full access from JSON', () {
      final key = NearAccessKey.fromJson({
        'nonce': '1',
        'permission': 'FullAccess',
      });
      expect(key.nonce, equals(BigInt.one));
      expect(key.permission, isA<FullAccessPermission>());
    });

    test('should parse function call from JSON', () {
      final key = NearAccessKey.fromJson({
        'nonce': '10',
        'permission': {
          'FunctionCall': {
            'allowance': '250000000000000000000000',
            'receiver_id': 'contract.near',
            'method_names': ['method1', 'method2'],
          },
        },
      });
      expect(key.permission, isA<FunctionCallPermission>());
      final fc = key.permission as FunctionCallPermission;
      expect(fc.receiverId, equals('contract.near'));
      expect(fc.methodNames, contains('method1'));
    });
  });

  group('NearAction', () {
    test('should create transfer action', () {
      final action = TransferAction(deposit: NearAmount.fromNear(1.0));
      final json = action.toJson();
      expect(json.containsKey('Transfer'), isTrue);
    });

    test('should create function call action', () {
      final action = FunctionCallAction.call(
        methodName: 'my_method',
        args: {'key': 'value'},
        gas: NearGas.tGas(50),
        deposit: NearAmount.zero,
      );
      final json = action.toJson();
      expect(json.containsKey('FunctionCall'), isTrue);
      expect(json['FunctionCall']['method_name'], equals('my_method'));
    });

    test('should create create account action', () {
      const action = CreateAccountAction();
      final json = action.toJson();
      expect(json.containsKey('CreateAccount'), isTrue);
    });

    test('should create stake action', () {
      final action = StakeAction(
        stake: NearAmount.fromNear(100),
        publicKey: NearPublicKey.fromString('ed25519:placeholder'),
      );
      final json = action.toJson();
      expect(json.containsKey('Stake'), isTrue);
    });
  });

  group('NearTransactionBuilder', () {
    test('should build transaction', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:placeholder'),
      );

      final tx = builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32))
          .transfer(NearAmount.fromNear(1.0))
          .build();

      expect(tx.signerId.value, equals('alice.near'));
      expect(tx.receiverId.value, equals('bob.near'));
      expect(tx.actions.length, equals(1));
    });

    test('should throw without nonce', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:placeholder'),
      );
      builder
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32))
          .transfer(NearAmount.fromNear(1.0));
      expect(() => builder.build(), throwsStateError);
    });

    test('should throw without actions', () {
      final builder = NearTransactionBuilder(
        signerId: NearAccountId.parse('alice.near'),
        publicKey: NearPublicKey.fromString('ed25519:placeholder'),
      );
      builder
          .nonce(BigInt.one)
          .receiver(NearAccountId.parse('bob.near'))
          .blockHash(Uint8List(32));
      expect(() => builder.build(), throwsStateError);
    });
  });

  group('NearExecutionStatus', () {
    test('should parse success value', () {
      final status = NearExecutionStatus.fromJson({
        'SuccessValue': 'eyJyZXN1bHQiOiAidmFsdWUifQ==',
      });
      expect(status, isA<SuccessValueStatus>());
    });

    test('should parse success receipt', () {
      final status = NearExecutionStatus.fromJson({
        'SuccessReceiptId': 'receipt123',
      });
      expect(status, isA<SuccessReceiptIdStatus>());
    });

    test('should parse failure', () {
      final status = NearExecutionStatus.fromJson({
        'Failure': {'ActionError': {'kind': 'AccountAlreadyExists'}},
      });
      expect(status, isA<FailureStatus>());
    });

    test('should parse unknown', () {
      final status = NearExecutionStatus.fromJson('Unknown');
      expect(status, isA<UnknownStatus>());
    });
  });

  group('NearExecutionOutcome', () {
    test('should parse from JSON', () {
      final outcome = NearExecutionOutcome.fromJson({
        'gas_burnt': '2428086920308',
        'tokens_burnt': '242808692030800000000',
        'status': {'SuccessValue': ''},
        'logs': ['log1', 'log2'],
        'receipt_ids': ['receipt1'],
      });
      expect(outcome.isSuccess, isTrue);
      expect(outcome.logs.length, equals(2));
    });
  });

  group('NearClient', () {
    test('should create from chain config', () {
      final client = NearClient.fromChain(NearChains.mainnet);
      expect(client.rpcUrl, equals(NearChains.mainnet.rpcUrl));
      client.close();
    });

    test('should create mainnet client', () {
      final client = NearClient.mainnet();
      expect(client.rpcUrl, contains('mainnet'));
      client.close();
    });

    test('should create testnet client', () {
      final client = NearClient.testnet();
      expect(client.rpcUrl, contains('testnet'));
      client.close();
    });
  });

  group('NearValidator', () {
    test('should parse from JSON', () {
      final validator = NearValidator.fromJson({
        'account_id': 'validator.poolv1.near',
        'public_key': 'ed25519:xyz',
        'stake': '1000000000000000000000000000',
        'is_slashed': false,
        'num_produced_blocks': 100,
        'num_expected_blocks': 100,
      });
      expect(validator.accountId, equals('validator.poolv1.near'));
      expect(validator.isSlashed, isFalse);
    });
  });

  group('NearKeyType', () {
    test('should have ed25519 and secp256k1', () {
      expect(NearKeyType.values, contains(NearKeyType.ed25519));
      expect(NearKeyType.values, contains(NearKeyType.secp256k1));
    });
  });
}
