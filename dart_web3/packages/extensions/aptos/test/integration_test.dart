/// Aptos blockchain integration tests.
///
/// Tests the Aptos extension package types and utilities.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:dart_web3_aptos/dart_web3_aptos.dart';
import 'package:test/test.dart';

void main() {
  group('Aptos Integration Tests', () {
    group('AptosAddress', () {
      test('creates from hex with 0x prefix', () {
        final address = AptosAddress.fromHex('0x${'ab' * 32}');
        expect(address.bytes.length, equals(32));
        expect(address.toHex().startsWith('0x'), isTrue);
      });

      test('creates from hex without prefix', () {
        final address = AptosAddress.fromHex('${'cd' * 32}');
        expect(address.bytes.length, equals(32));
      });

      test('pads short addresses correctly', () {
        final address = AptosAddress.fromHex('0x1');
        expect(address.bytes.length, equals(32));
        expect(address.bytes.last, equals(1));
      });

      test('converts to hex', () {
        final address = AptosAddress.fromHex('0x1');
        // toHex() preserves at least 2 hex chars for last byte
        expect(address.toHex(), equals('0x01'));
      });

      test('converts to full hex', () {
        final address = AptosAddress.fromHex('0x1');
        final fullHex = address.toFullHex();
        expect(fullHex.length, equals(66)); // 0x + 64 hex chars
        expect(fullHex.endsWith('1'), isTrue);
      });

      test('converts to short string format', () {
        final address = AptosAddress.fromHex('0x${'ab' * 32}');
        final shortStr = address.toShortString();
        expect(shortStr.contains('...'), isTrue);
        expect(shortStr.length, lessThan(address.toFullHex().length));
      });

      test('equality comparison works correctly', () {
        final addr1 = AptosAddress.fromHex('0x${'11' * 32}');
        final addr2 = AptosAddress.fromHex('0x${'11' * 32}');
        final addr3 = AptosAddress.fromHex('0x${'22' * 32}');

        expect(addr1, equals(addr2));
        expect(addr1, isNot(equals(addr3)));
      });

      test('hashCode is consistent', () {
        final addr1 = AptosAddress.fromHex('0x${'11' * 32}');
        final addr2 = AptosAddress.fromHex('0x${'11' * 32}');

        expect(addr1.hashCode, equals(addr2.hashCode));
      });

      test('has framework constant', () {
        // toHex() pads last byte to 2 hex chars
        expect(AptosAddress.framework.toHex(), equals('0x01'));
      });

      test('has token constant', () {
        // toHex() pads last byte to 2 hex chars
        expect(AptosAddress.token.toHex(), equals('0x03'));
      });

      test('has objects constant', () {
        // toHex() pads last byte to 2 hex chars
        expect(AptosAddress.objects.toHex(), equals('0x04'));
      });

      test('toString returns hex', () {
        final address = AptosAddress.fromHex('0x1');
        // toString() calls toHex() which pads bytes
        expect(address.toString(), equals('0x01'));
      });
    });

    group('AptosTypeTag', () {
      test('creates from string', () {
        final tag = AptosTypeTag.fromString('0x1::aptos_coin::AptosCoin');
        expect(tag.value, equals('0x1::aptos_coin::AptosCoin'));
      });

      test('has basic type tags', () {
        expect(AptosTypeTag.bool_.value, equals('bool'));
        expect(AptosTypeTag.u8.value, equals('u8'));
        expect(AptosTypeTag.u16.value, equals('u16'));
        expect(AptosTypeTag.u32.value, equals('u32'));
        expect(AptosTypeTag.u64.value, equals('u64'));
        expect(AptosTypeTag.u128.value, equals('u128'));
        expect(AptosTypeTag.u256.value, equals('u256'));
        expect(AptosTypeTag.address.value, equals('address'));
        expect(AptosTypeTag.signer.value, equals('signer'));
      });

      test('creates vector type tags', () {
        final vectorU8 = AptosTypeTag.vector(AptosTypeTag.u8);
        expect(vectorU8.value, equals('vector<u8>'));

        final vectorU64 = AptosTypeTag.vector(AptosTypeTag.u64);
        expect(vectorU64.value, equals('vector<u64>'));
      });

      test('creates struct type tags', () {
        final coinType = AptosTypeTag.struct_('0x1', 'aptos_coin', 'AptosCoin');
        expect(coinType.value, equals('0x1::aptos_coin::AptosCoin'));
      });

      test('creates struct type tags with type arguments', () {
        final coinType = AptosTypeTag.struct_(
          '0x1',
          'coin',
          'CoinStore',
          [AptosTypeTag.struct_('0x1', 'aptos_coin', 'AptosCoin')],
        );
        expect(coinType.value, contains('0x1::coin::CoinStore<'));
      });

      test('has aptCoin constant', () {
        expect(AptosTypeTag.aptCoin.value, equals('0x1::aptos_coin::AptosCoin'));
      });

      test('toString returns value', () {
        final tag = AptosTypeTag.u64;
        expect(tag.toString(), equals('u64'));
      });
    });

    group('AptosAccountResource', () {
      test('creates with type and data', () {
        final resource = AptosAccountResource(
          type: '0x1::account::Account',
          data: {'sequence_number': '10'},
        );

        expect(resource.type, equals('0x1::account::Account'));
        expect(resource.data['sequence_number'], equals('10'));
      });

      test('creates from JSON', () {
        final json = {
          'type': '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
          'data': {
            'coin': {'value': '1000000000'},
            'frozen': false,
          },
        };

        final resource = AptosAccountResource.fromJson(json);
        expect(resource.type, contains('CoinStore'));
        expect(resource.data['frozen'], equals(false));
      });
    });

    group('AptosAccount', () {
      test('creates with required fields', () {
        final account = AptosAccount(
          sequenceNumber: BigInt.from(10),
          authenticationKey: '0x${'ab' * 32}',
        );

        expect(account.sequenceNumber, equals(BigInt.from(10)));
        expect(account.authenticationKey, contains('ab'));
      });

      test('creates from JSON', () {
        final json = {
          'sequence_number': '25',
          'authentication_key': '0x${'cd' * 32}',
        };

        final account = AptosAccount.fromJson(json);
        expect(account.sequenceNumber, equals(BigInt.from(25)));
      });
    });

    group('AptosCoin', () {
      test('creates with value', () {
        final coin = AptosCoin(value: BigInt.from(100000000));
        expect(coin.value, equals(BigInt.from(100000000)));
      });

      test('creates from JSON', () {
        final json = {'value': '1000000000'};
        final coin = AptosCoin.fromJson(json);
        expect(coin.value, equals(BigInt.from(1000000000)));
      });
    });

    group('AptosCoinStore', () {
      test('creates with coin and frozen status', () {
        final store = AptosCoinStore(
          coin: AptosCoin(value: BigInt.from(100000000)),
          frozen: false,
        );

        expect(store.coin.value, equals(BigInt.from(100000000)));
        expect(store.frozen, isFalse);
      });

      test('creates from JSON', () {
        final json = {
          'coin': {'value': '500000000'},
          'frozen': true,
        };

        final store = AptosCoinStore.fromJson(json);
        expect(store.coin.value, equals(BigInt.from(500000000)));
        expect(store.frozen, isTrue);
      });
    });

    group('AptosLedgerInfo', () {
      test('creates with all fields', () {
        final ledgerInfo = AptosLedgerInfo(
          chainId: 1,
          epoch: BigInt.from(1000),
          ledgerVersion: BigInt.from(50000000),
          oldestLedgerVersion: BigInt.from(1000000),
          ledgerTimestamp: BigInt.from(1704672000000000),
          nodeRole: 'full_node',
          oldestBlockHeight: BigInt.from(100000),
          blockHeight: BigInt.from(500000),
          gitHash: 'abc123',
        );

        expect(ledgerInfo.chainId, equals(1));
        expect(ledgerInfo.epoch, equals(BigInt.from(1000)));
        expect(ledgerInfo.blockHeight, equals(BigInt.from(500000)));
      });

      test('creates from JSON', () {
        final json = {
          'chain_id': 2,
          'epoch': '500',
          'ledger_version': '25000000',
          'oldest_ledger_version': '500000',
          'ledger_timestamp': '1704672000000000',
          'node_role': 'validator',
          'oldest_block_height': '50000',
          'block_height': '250000',
          'git_hash': 'def456',
        };

        final ledgerInfo = AptosLedgerInfo.fromJson(json);
        expect(ledgerInfo.chainId, equals(2));
        expect(ledgerInfo.nodeRole, equals('validator'));
      });
    });

    group('AptosGasEstimation', () {
      test('creates with all fields', () {
        final estimation = AptosGasEstimation(
          gasEstimate: 100,
          deprioritizedGasEstimate: 80,
          prioritizedGasEstimate: 150,
        );

        expect(estimation.gasEstimate, equals(100));
        expect(estimation.deprioritizedGasEstimate, equals(80));
        expect(estimation.prioritizedGasEstimate, equals(150));
      });

      test('creates from JSON', () {
        final json = {
          'gas_estimate': 120,
          'deprioritized_gas_estimate': 90,
          'prioritized_gas_estimate': 180,
        };

        final estimation = AptosGasEstimation.fromJson(json);
        expect(estimation.gasEstimate, equals(120));
      });

      test('allows null optional fields', () {
        final estimation = AptosGasEstimation(
          gasEstimate: 100,
          deprioritizedGasEstimate: null,
          prioritizedGasEstimate: null,
        );

        expect(estimation.deprioritizedGasEstimate, isNull);
        expect(estimation.prioritizedGasEstimate, isNull);
      });
    });

    group('AptosBlock', () {
      test('creates with required fields', () {
        final block = AptosBlock(
          blockHeight: BigInt.from(1000000),
          blockHash: '0xblockhash123',
          blockTimestamp: BigInt.from(1704672000000000),
          firstVersion: BigInt.from(50000000),
          lastVersion: BigInt.from(50001000),
        );

        expect(block.blockHeight, equals(BigInt.from(1000000)));
        expect(block.blockHash, equals('0xblockhash123'));
        expect(block.firstVersion, equals(BigInt.from(50000000)));
      });

      test('creates from JSON', () {
        final json = {
          'block_height': '2000000',
          'block_hash': '0xabc123',
          'block_timestamp': '1704672000000000',
          'first_version': '100000000',
          'last_version': '100002000',
        };

        final block = AptosBlock.fromJson(json);
        expect(block.blockHeight, equals(BigInt.from(2000000)));
        expect(block.lastVersion, equals(BigInt.from(100002000)));
      });

      test('supports optional transactions', () {
        final block = AptosBlock(
          blockHeight: BigInt.from(1000000),
          blockHash: '0xblockhash123',
          blockTimestamp: BigInt.from(1704672000000000),
          firstVersion: BigInt.from(50000000),
          lastVersion: BigInt.from(50001000),
          transactions: [{'type': 'user_transaction'}],
        );

        expect(block.transactions, isNotNull);
        expect(block.transactions!.length, equals(1));
      });
    });

    group('AptosEvent', () {
      test('creates with required fields', () {
        final event = AptosEvent(
          guid: AptosEventGuid(
            creationNumber: BigInt.from(5),
            accountAddress: '0x${'aa' * 32}',
          ),
          sequenceNumber: BigInt.from(10),
          type: '0x1::coin::DepositEvent',
          data: {'amount': '1000000'},
        );

        expect(event.type, equals('0x1::coin::DepositEvent'));
        expect(event.sequenceNumber, equals(BigInt.from(10)));
        expect(event.data['amount'], equals('1000000'));
      });

      test('creates from JSON', () {
        final json = {
          'guid': {
            'creation_number': '0',
            'account_address': '0x${'bb' * 32}',
          },
          'sequence_number': '15',
          'type': '0x1::coin::WithdrawEvent',
          'data': {'amount': '500000'},
        };

        final event = AptosEvent.fromJson(json);
        expect(event.type, equals('0x1::coin::WithdrawEvent'));
        expect(event.guid.creationNumber, equals(BigInt.zero));
      });
    });

    group('AptosEventGuid', () {
      test('creates with required fields', () {
        final guid = AptosEventGuid(
          creationNumber: BigInt.from(3),
          accountAddress: '0x1',
        );

        expect(guid.creationNumber, equals(BigInt.from(3)));
        expect(guid.accountAddress, equals('0x1'));
      });

      test('creates from JSON', () {
        final json = {
          'creation_number': '10',
          'account_address': '0x${'cc' * 32}',
        };

        final guid = AptosEventGuid.fromJson(json);
        expect(guid.creationNumber, equals(BigInt.from(10)));
      });
    });

    group('AptosSignatureScheme', () {
      test('has correct values', () {
        expect(AptosSignatureScheme.ed25519.value, equals(0));
        expect(AptosSignatureScheme.multiEd25519.value, equals(1));
        expect(AptosSignatureScheme.singleKey.value, equals(2));
        expect(AptosSignatureScheme.multiKey.value, equals(3));
      });
    });

    group('EntryFunctionPayload', () {
      test('creates with required fields', () {
        final payload = EntryFunctionPayload(
          function: '0x1::aptos_account::transfer',
          typeArguments: [],
          arguments: ['0x${'aa' * 32}', '1000000'],
        );

        expect(payload.function, equals('0x1::aptos_account::transfer'));
        expect(payload.typeArguments, isEmpty);
        expect(payload.arguments.length, equals(2));
        expect(payload, isA<AptosTransactionPayload>());
      });

      test('creates with type arguments', () {
        final payload = EntryFunctionPayload(
          function: '0x1::coin::transfer',
          typeArguments: ['0x1::aptos_coin::AptosCoin'],
          arguments: ['0x${'bb' * 32}', '2000000'],
        );

        expect(payload.typeArguments.length, equals(1));
        expect(payload.typeArguments.first, contains('AptosCoin'));
      });

      test('converts to JSON', () {
        final payload = EntryFunctionPayload(
          function: '0x1::aptos_account::transfer',
          typeArguments: [],
          arguments: ['0x1', '1000000'],
        );
        final json = payload.toJson();

        expect(json['type'], equals('entry_function_payload'));
        expect(json['function'], equals('0x1::aptos_account::transfer'));
        expect(json['type_arguments'], isA<List>());
        expect(json['arguments'], isA<List>());
      });
    });

    group('ScriptPayload', () {
      test('creates with required fields', () {
        final payload = ScriptPayload(
          code: Uint8List.fromList([1, 2, 3, 4]),
          typeArguments: ['0x1::aptos_coin::AptosCoin'],
          arguments: [BigInt.from(1000)],
        );

        expect(payload.code.length, equals(4));
        expect(payload.typeArguments.length, equals(1));
        expect(payload, isA<AptosTransactionPayload>());
      });

      test('converts to JSON', () {
        final payload = ScriptPayload(
          code: Uint8List.fromList([0x01, 0x02, 0x03]),
          typeArguments: [],
          arguments: [],
        );
        final json = payload.toJson();

        expect(json['type'], equals('script_payload'));
        expect(json['code'], isA<Map>());
        expect(json['code']['bytecode'], startsWith('0x'));
      });
    });

    group('MultisigPayload', () {
      test('creates with multisig address', () {
        final payload = MultisigPayload(
          multisigAddress: AptosAddress.fromHex('0x${'aa' * 32}'),
        );

        expect(payload.multisigAddress.bytes.length, equals(32));
        expect(payload.transactionPayload, isNull);
        expect(payload, isA<AptosTransactionPayload>());
      });

      test('creates with inner payload', () {
        final payload = MultisigPayload(
          multisigAddress: AptosAddress.fromHex('0x${'aa' * 32}'),
          transactionPayload: EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: ['0x1', '1000000'],
          ),
        );

        expect(payload.transactionPayload, isNotNull);
      });

      test('converts to JSON', () {
        final payload = MultisigPayload(
          multisigAddress: AptosAddress.fromHex('0x1'),
        );
        final json = payload.toJson();

        expect(json['type'], equals('multisig_payload'));
        expect(json['multisig_address'], isNotNull);
      });
    });

    group('AptosRawTransaction', () {
      test('creates with required fields', () {
        final tx = AptosRawTransaction(
          sender: AptosAddress.fromHex('0x${'aa' * 32}'),
          sequenceNumber: BigInt.from(10),
          payload: EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: ['0x${'bb' * 32}', '1000000'],
          ),
          maxGasAmount: BigInt.from(200000),
          gasUnitPrice: BigInt.from(100),
          expirationTimestampSecs: BigInt.from(1704672000),
          chainId: 1,
        );

        expect(tx.sender.bytes.length, equals(32));
        expect(tx.sequenceNumber, equals(BigInt.from(10)));
        expect(tx.maxGasAmount, equals(BigInt.from(200000)));
        expect(tx.chainId, equals(1));
      });

      test('serializes to bytes', () {
        final tx = AptosRawTransaction(
          sender: AptosAddress.fromHex('0x1'),
          sequenceNumber: BigInt.zero,
          payload: EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ),
          maxGasAmount: BigInt.from(200000),
          gasUnitPrice: BigInt.from(100),
          expirationTimestampSecs: BigInt.from(1704672000),
          chainId: 1,
        );

        final serialized = tx.serialize();
        expect(serialized, isA<Uint8List>());
      });
    });

    group('AptosTransactionAuthenticator Types', () {
      test('creates Ed25519Authenticator', () {
        final auth = Ed25519Authenticator(
          publicKey: Uint8List(32),
          signature: Uint8List(64),
        );

        expect(auth.publicKey.length, equals(32));
        expect(auth.signature.length, equals(64));
        expect(auth, isA<AptosTransactionAuthenticator>());
      });

      test('creates MultiEd25519Authenticator', () {
        final auth = MultiEd25519Authenticator(
          publicKeys: [Uint8List(32), Uint8List(32)],
          signatures: [Uint8List(64)],
          bitmap: Uint8List.fromList([0x80, 0x00, 0x00, 0x00]),
          threshold: 1,
        );

        expect(auth.publicKeys.length, equals(2));
        expect(auth.signatures.length, equals(1));
        expect(auth.threshold, equals(1));
        expect(auth, isA<AptosTransactionAuthenticator>());
      });

      test('creates SingleKeyAuthenticator', () {
        final auth = SingleKeyAuthenticator(
          publicKey: AptosAnyPublicKey(
            type: AptosPublicKeyType.ed25519,
            publicKey: Uint8List(32),
          ),
          signature: AptosAnySignature(
            type: AptosSignatureType.ed25519,
            signature: Uint8List(64),
          ),
        );

        expect(auth.publicKey.type, equals(AptosPublicKeyType.ed25519));
        expect(auth.signature.type, equals(AptosSignatureType.ed25519));
        expect(auth, isA<AptosTransactionAuthenticator>());
      });
    });

    group('AptosPublicKeyType', () {
      test('has correct values', () {
        expect(AptosPublicKeyType.ed25519.value, equals(0));
        expect(AptosPublicKeyType.secp256k1Ecdsa.value, equals(1));
        expect(AptosPublicKeyType.secp256r1Ecdsa.value, equals(2));
        expect(AptosPublicKeyType.keyless.value, equals(3));
      });
    });

    group('AptosSignatureType', () {
      test('has correct values', () {
        expect(AptosSignatureType.ed25519.value, equals(0));
        expect(AptosSignatureType.secp256k1Ecdsa.value, equals(1));
        expect(AptosSignatureType.secp256r1Ecdsa.value, equals(2));
        expect(AptosSignatureType.keyless.value, equals(3));
      });
    });

    group('AptosAnyPublicKey', () {
      test('creates with type and key', () {
        final pubKey = AptosAnyPublicKey(
          type: AptosPublicKeyType.secp256k1Ecdsa,
          publicKey: Uint8List(33),
        );

        expect(pubKey.type, equals(AptosPublicKeyType.secp256k1Ecdsa));
        expect(pubKey.publicKey.length, equals(33));
      });
    });

    group('AptosAnySignature', () {
      test('creates with type and signature', () {
        final sig = AptosAnySignature(
          type: AptosSignatureType.secp256r1Ecdsa,
          signature: Uint8List(64),
        );

        expect(sig.type, equals(AptosSignatureType.secp256r1Ecdsa));
        expect(sig.signature.length, equals(64));
      });
    });

    group('AptosSignedTransaction', () {
      test('creates with raw transaction and authenticator', () {
        final rawTx = AptosRawTransaction(
          sender: AptosAddress.fromHex('0x1'),
          sequenceNumber: BigInt.zero,
          payload: EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ),
          maxGasAmount: BigInt.from(200000),
          gasUnitPrice: BigInt.from(100),
          expirationTimestampSecs: BigInt.from(1704672000),
          chainId: 1,
        );

        final signedTx = AptosSignedTransaction(
          rawTransaction: rawTx,
          authenticator: Ed25519Authenticator(
            publicKey: Uint8List(32),
            signature: Uint8List(64),
          ),
        );

        expect(signedTx.rawTransaction, equals(rawTx));
        expect(signedTx.authenticator, isA<Ed25519Authenticator>());
      });

      test('serializes to bytes', () {
        final signedTx = AptosSignedTransaction(
          rawTransaction: AptosRawTransaction(
            sender: AptosAddress.fromHex('0x1'),
            sequenceNumber: BigInt.zero,
            payload: EntryFunctionPayload(
              function: '0x1::aptos_account::transfer',
              typeArguments: [],
              arguments: [],
            ),
            maxGasAmount: BigInt.from(200000),
            gasUnitPrice: BigInt.from(100),
            expirationTimestampSecs: BigInt.from(1704672000),
            chainId: 1,
          ),
          authenticator: Ed25519Authenticator(
            publicKey: Uint8List(32),
            signature: Uint8List(64),
          ),
        );

        final serialized = signedTx.serialize();
        expect(serialized, isA<Uint8List>());
      });
    });

    group('AptosTransactionResponse', () {
      test('creates successful response', () {
        final response = AptosTransactionResponse(
          version: BigInt.from(100000000),
          hash: '0xtxhash123',
          stateChangeHash: '0xstatechange',
          eventRootHash: '0xeventroot',
          stateCheckpointHash: null,
          gasUsed: BigInt.from(500),
          success: true,
          vmStatus: 'Executed successfully',
          accumulatorRootHash: '0xaccroot',
        );

        expect(response.success, isTrue);
        expect(response.version, equals(BigInt.from(100000000)));
        expect(response.gasUsed, equals(BigInt.from(500)));
      });

      test('creates failed response', () {
        final response = AptosTransactionResponse(
          version: BigInt.from(100000001),
          hash: '0xtxhash456',
          stateChangeHash: '0xstatechange',
          eventRootHash: '0xeventroot',
          stateCheckpointHash: null,
          gasUsed: BigInt.from(100),
          success: false,
          vmStatus: 'Move abort: EINSUFFICIENT_BALANCE',
          accumulatorRootHash: '0xaccroot',
        );

        expect(response.success, isFalse);
        expect(response.vmStatus, contains('EINSUFFICIENT_BALANCE'));
      });

      test('creates from JSON', () {
        final json = {
          'version': '200000000',
          'hash': '0xhash789',
          'state_change_hash': '0xsc',
          'event_root_hash': '0xer',
          'state_checkpoint_hash': null,
          'gas_used': '750',
          'success': true,
          'vm_status': 'Executed successfully',
          'accumulator_root_hash': '0xar',
          'changes': [],
          'events': [],
          'timestamp': '1704672000000000',
        };

        final response = AptosTransactionResponse.fromJson(json);
        expect(response.version, equals(BigInt.from(200000000)));
        expect(response.gasUsed, equals(BigInt.from(750)));
        expect(response.timestamp, isNotNull);
      });
    });

    group('AptosPendingTransactionResponse', () {
      test('creates from JSON', () {
        final json = {
          'hash': '0xpendinghash',
          'sender': '0x${'aa' * 32}',
          'sequence_number': '10',
          'max_gas_amount': '200000',
          'gas_unit_price': '100',
          'expiration_timestamp_secs': '1704672000',
          'payload': {'type': 'entry_function_payload'},
        };

        final response = AptosPendingTransactionResponse.fromJson(json);
        expect(response.hash, equals('0xpendinghash'));
        expect(response.sequenceNumber, equals(BigInt.from(10)));
        expect(response.maxGasAmount, equals(BigInt.from(200000)));
      });
    });

    group('AptosTransactionBuilder', () {
      test('creates with sender and chain ID', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        );

        // toHex() pads last byte to 2 hex chars
        expect(builder.sender.toHex(), equals('0x01'));
        expect(builder.chainId, equals(1));
      });

      test('sets sequence number', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )..sequenceNumber(BigInt.from(25));

        builder
          ..payload(EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ))
          ..expiresIn(const Duration(seconds: 30));

        final tx = builder.build();
        expect(tx.sequenceNumber, equals(BigInt.from(25)));
      });

      test('sets max gas amount', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )
          ..sequenceNumber(BigInt.zero)
          ..maxGasAmount(BigInt.from(500000))
          ..payload(EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ))
          ..expiresIn(const Duration(seconds: 30));

        final tx = builder.build();
        expect(tx.maxGasAmount, equals(BigInt.from(500000)));
      });

      test('sets gas unit price', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )
          ..sequenceNumber(BigInt.zero)
          ..gasUnitPrice(BigInt.from(200))
          ..payload(EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ))
          ..expiresIn(const Duration(seconds: 30));

        final tx = builder.build();
        expect(tx.gasUnitPrice, equals(BigInt.from(200)));
      });

      test('sets expiration with expiresIn', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )
          ..sequenceNumber(BigInt.zero)
          ..expiresIn(const Duration(minutes: 5))
          ..payload(EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ));

        final tx = builder.build();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(tx.expirationTimestampSecs.toInt(), greaterThan(now));
      });

      test('sets entry function', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )
          ..sequenceNumber(BigInt.zero)
          ..entryFunction(
            function: '0x1::coin::transfer',
            typeArguments: ['0x1::aptos_coin::AptosCoin'],
            arguments: ['0x${'bb' * 32}', '1000000'],
          )
          ..expiresIn(const Duration(seconds: 30));

        final tx = builder.build();
        expect(tx.payload, isA<EntryFunctionPayload>());
      });

      test('throws without sequence number', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )..payload(EntryFunctionPayload(
            function: '0x1::aptos_account::transfer',
            typeArguments: [],
            arguments: [],
          ));

        expect(() => builder.build(), throwsStateError);
      });

      test('throws without payload', () {
        final builder = AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )..sequenceNumber(BigInt.zero);

        expect(() => builder.build(), throwsStateError);
      });

      test('supports method chaining', () {
        final tx = (AptosTransactionBuilder(
          sender: AptosAddress.fromHex('0x1'),
          chainId: 1,
        )
              ..sequenceNumber(BigInt.from(5))
              ..maxGasAmount(BigInt.from(300000))
              ..gasUnitPrice(BigInt.from(150))
              ..expiresIn(const Duration(minutes: 10))
              ..entryFunction(
                function: '0x1::aptos_account::transfer',
                typeArguments: [],
                arguments: ['0x${'aa' * 32}', '1000000'],
              ))
            .build();

        expect(tx.sequenceNumber, equals(BigInt.from(5)));
        expect(tx.maxGasAmount, equals(BigInt.from(300000)));
        expect(tx.gasUnitPrice, equals(BigInt.from(150)));
      });
    });

    group('AptosPayloads', () {
      test('creates transferApt payload', () {
        final payload = AptosPayloads.transferApt(
          to: AptosAddress.fromHex('0x${'aa' * 32}'),
          amount: BigInt.from(100000000),
        );

        expect(payload.function, equals('0x1::aptos_account::transfer'));
        expect(payload.typeArguments, isEmpty);
        expect(payload.arguments.length, equals(2));
      });

      test('creates transferCoin payload', () {
        final payload = AptosPayloads.transferCoin(
          coinType: '0x1::aptos_coin::AptosCoin',
          to: AptosAddress.fromHex('0x${'bb' * 32}'),
          amount: BigInt.from(50000000),
        );

        expect(payload.function, equals('0x1::aptos_account::transfer_coins'));
        expect(payload.typeArguments.length, equals(1));
        expect(payload.typeArguments.first, contains('AptosCoin'));
      });

      test('creates registerCoin payload', () {
        final payload = AptosPayloads.registerCoin(
          coinType: '0x${'cc' * 32}::my_coin::MyCoin',
        );

        expect(payload.function, equals('0x1::managed_coin::register'));
        expect(payload.typeArguments.length, equals(1));
        expect(payload.arguments, isEmpty);
      });
    });

    group('Gas Calculation', () {
      test('calculates transaction fee', () {
        final gasUsed = 500;
        final gasUnitPrice = 100;

        final fee = gasUsed * gasUnitPrice;
        expect(fee, equals(50000));
      });

      test('adds safety buffer to gas estimate', () {
        final estimatedGas = 500;
        final safetyMultiplier = 1.5;

        final safeGas = (estimatedGas * safetyMultiplier).ceil();
        expect(safeGas, equals(750));
      });
    });
  });
}
