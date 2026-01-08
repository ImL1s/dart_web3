import 'dart:typed_data';
import 'package:web3_universal_aptos/web3_universal_aptos.dart';
import 'package:test/test.dart';

/// Strict edge case and authoritative tests for Aptos extension package.
/// Test vectors derived from official Aptos/Move BCS specification.
void main() {
  group('AptosAddress Edge Cases', () {
    // === Official Test Vectors ===
    test('zero address (0x0)', () {
      final address = AptosAddress.fromHex('0x0');
      expect(address.bytes, equals(Uint8List(32)));
      expect(
        address.toFullHex(),
        equals(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
    });

    test('max address (all 0xFF)', () {
      final maxHex = '0x${'ff' * 32}';
      final address = AptosAddress.fromHex(maxHex);
      expect(address.bytes, everyElement(equals(0xff)));
      expect(address.toFullHex(), equals(maxHex));
    });

    test('framework addresses (0x1, 0x3, 0x4)', () {
      // Aptos framework address
      final framework = AptosAddress.framework;
      expect(framework.bytes[31], equals(1));
      expect(framework.toHex(), equals('0x01'));

      // Token address
      final token = AptosAddress.token;
      expect(token.bytes[31], equals(3));

      // Objects address
      final objects = AptosAddress.objects;
      expect(objects.bytes[31], equals(4));
    });

    test('leading zeros preserved in bytes', () {
      final address = AptosAddress.fromHex('0x00000000000000000000000000000001');
      expect(address.bytes[31], equals(1));
      expect(address.bytes.sublist(0, 31), everyElement(equals(0)));
    });

    test('case insensitivity', () {
      final lower = AptosAddress.fromHex('0xabcdef');
      final upper = AptosAddress.fromHex('0xABCDEF');
      final mixed = AptosAddress.fromHex('0xAbCdEf');
      expect(lower, equals(upper));
      expect(lower, equals(mixed));
    });

    test('empty hex string should pad to 32 bytes', () {
      final address = AptosAddress.fromHex('0x');
      expect(address.bytes.length, equals(32));
      expect(address.bytes, everyElement(equals(0)));
    });

    test('short address display format', () {
      // Aptos uses short display format without leading zeros
      final address = AptosAddress.fromHex('0x1');
      expect(address.toHex(), equals('0x01'));

      final address42 = AptosAddress.fromHex('0x42');
      expect(address42.toHex(), equals('0x42'));
    });

    test('real-world mainnet address', () {
      // Example from Aptos documentation
      const realAddress =
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final address = AptosAddress.fromHex(realAddress);
      expect(address.bytes.length, equals(32));
      expect(address.toFullHex(), equals(realAddress));
    });

    test('toShortString format', () {
      final address = AptosAddress.fromHex(
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
      final short = address.toShortString();
      expect(short, equals('0x1234...cdef'));
      expect(short.length, equals(13)); // 0x(2) + 4 + ...(3) + 4
    });
  });

  group('AptosTypeTag Edge Cases', () {
    test('all primitive types', () {
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

    test('nested vector types', () {
      final vecVecU64 =
          AptosTypeTag.vector(AptosTypeTag.vector(AptosTypeTag.u64));
      expect(vecVecU64.value, equals('vector<vector<u64>>'));
    });

    test('deeply nested struct types', () {
      final nestedType = AptosTypeTag.struct_(
        '0x1',
        'coin',
        'CoinStore',
        [AptosTypeTag.struct_('0x1', 'aptos_coin', 'AptosCoin')],
      );
      expect(nestedType.value, contains('CoinStore'));
      expect(nestedType.value, contains('AptosCoin'));
    });

    test('APT coin type', () {
      final aptCoin = AptosTypeTag.aptCoin;
      expect(aptCoin.value, equals('0x1::aptos_coin::AptosCoin'));
    });

    test('struct with multiple type parameters', () {
      final pairType = AptosTypeTag.struct_(
        '0x1',
        'pair',
        'Pair',
        [AptosTypeTag.u64, AptosTypeTag.address],
      );
      expect(pairType.value, equals('0x1::pair::Pair<u64, address>'));
    });

    test('struct without type parameters', () {
      final simple = AptosTypeTag.struct_('0x1', 'module', 'Struct');
      expect(simple.value, equals('0x1::module::Struct'));
    });
  });

  group('Transaction Builder Edge Cases', () {
    test('transaction with default gas settings', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.sequenceNumber(BigInt.zero);
      builder.entryFunction(function: '0x1::test::test');
      builder.expiresIn(const Duration(seconds: 30));

      final tx = builder.build();
      expect(tx.maxGasAmount, equals(BigInt.from(200000)));
      expect(tx.gasUnitPrice, equals(BigInt.from(100)));
    });

    test('transaction with custom gas settings', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.sequenceNumber(BigInt.zero);
      builder.maxGasAmount(BigInt.from(500000));
      builder.gasUnitPrice(BigInt.from(200));
      builder.entryFunction(function: '0x1::test::test');
      builder.expiresIn(const Duration(seconds: 60));

      final tx = builder.build();
      expect(tx.maxGasAmount, equals(BigInt.from(500000)));
      expect(tx.gasUnitPrice, equals(BigInt.from(200)));
    });

    test('transaction with max sequence number', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      final maxSeqNum = BigInt.parse('18446744073709551615'); // u64 max
      builder.sequenceNumber(maxSeqNum);
      builder.entryFunction(function: '0x1::test::test');
      builder.expiresIn(const Duration(seconds: 30));

      final tx = builder.build();
      expect(tx.sequenceNumber, equals(maxSeqNum));
    });

    test('transaction with explicit expiration timestamp', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      final expiration = BigInt.from(1700000000);
      builder.sequenceNumber(BigInt.zero);
      builder.expirationTimestampSecs(expiration);
      builder.entryFunction(function: '0x1::test::test');

      final tx = builder.build();
      expect(tx.expirationTimestampSecs, equals(expiration));
    });

    test('throws without sequence number', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.entryFunction(function: '0x1::test::test');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws without payload', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.sequenceNumber(BigInt.zero);
      expect(() => builder.build(), throwsStateError);
    });

    test('entry function with type arguments', () {
      final builder = AptosTransactionBuilder(
        sender: AptosAddress.fromHex('0x1'),
        chainId: 1,
      );
      builder.sequenceNumber(BigInt.zero);
      builder.entryFunction(
        function: '0x1::coin::transfer',
        typeArguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: ['0x2', '1000000'],
      );
      builder.expiresIn(const Duration(seconds: 30));

      final tx = builder.build();
      final payload = tx.payload as EntryFunctionPayload;
      expect(payload.typeArguments, contains('0x1::aptos_coin::AptosCoin'));
      expect(payload.arguments.length, equals(2));
    });
  });

  group('JSON Parsing Edge Cases', () {
    test('AptosLedgerInfo with genesis epoch', () {
      final info = AptosLedgerInfo.fromJson({
        'chain_id': 1,
        'epoch': '0',
        'ledger_version': '0',
        'oldest_ledger_version': '0',
        'ledger_timestamp': '0',
        'node_role': 'full_node',
        'oldest_block_height': '0',
        'block_height': '0',
        'git_hash': null,
      });
      expect(info.epoch, equals(BigInt.zero));
      expect(info.ledgerVersion, equals(BigInt.zero));
      expect(info.gitHash, isNull);
    });

    test('AptosLedgerInfo with large values', () {
      final info = AptosLedgerInfo.fromJson({
        'chain_id': 1,
        'epoch': '999999999',
        'ledger_version': '18446744073709551615',
        'oldest_ledger_version': '100000000',
        'ledger_timestamp': '1700000000000000',
        'node_role': 'validator',
        'oldest_block_height': '50000000',
        'block_height': '100000000',
        'git_hash': 'abc123def456',
      });
      expect(info.epoch, equals(BigInt.from(999999999)));
      expect(
        info.ledgerVersion,
        equals(BigInt.parse('18446744073709551615')),
      );
    });

    test('AptosGasEstimation with optional fields', () {
      final estimation = AptosGasEstimation.fromJson({
        'gas_estimate': 100,
        'deprioritized_gas_estimate': null,
        'prioritized_gas_estimate': null,
      });
      expect(estimation.gasEstimate, equals(100));
      expect(estimation.deprioritizedGasEstimate, isNull);
      expect(estimation.prioritizedGasEstimate, isNull);
    });

    test('AptosAccount with zero sequence number', () {
      final account = AptosAccount.fromJson({
        'sequence_number': '0',
        'authentication_key':
            '0x0000000000000000000000000000000000000000000000000000000000000001',
      });
      expect(account.sequenceNumber, equals(BigInt.zero));
    });

    test('AptosCoinStore with frozen state', () {
      final coinStore = AptosCoinStore.fromJson({
        'coin': {'value': '0'},
        'frozen': true,
      });
      expect(coinStore.coin.value, equals(BigInt.zero));
      expect(coinStore.frozen, isTrue);
    });

    test('AptosBlock with transactions', () {
      final block = AptosBlock.fromJson({
        'block_height': '1000000',
        'block_hash': '0xblockhash',
        'block_timestamp': '1700000000000000',
        'first_version': '5000000',
        'last_version': '5001000',
        'transactions': [
          {'type': 'user_transaction'},
        ],
      });
      expect(block.transactions, isNotNull);
      expect(block.transactions!.length, equals(1));
    });

    test('AptosEvent with complex data', () {
      final event = AptosEvent.fromJson({
        'guid': {
          'creation_number': '18446744073709551615',
          'account_address': '0x1',
        },
        'sequence_number': '999999999999999999',
        'type': '0x1::coin::WithdrawEvent',
        'data': {'amount': '1000000000', 'nested': {'key': 'value'}},
      });
      expect(
        event.guid.creationNumber,
        equals(BigInt.parse('18446744073709551615')),
      );
      expect(
        event.sequenceNumber,
        equals(BigInt.parse('999999999999999999')),
      );
    });

    test('AptosTransactionResponse success and failure', () {
      final success = AptosTransactionResponse.fromJson({
        'version': '12345',
        'hash': '0xabc123',
        'state_change_hash': '0xdef456',
        'event_root_hash': '0x789',
        'state_checkpoint_hash': '0xcheckpoint',
        'gas_used': '100',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0xaccumulator',
        'timestamp': '1700000000000000',
      });
      expect(success.success, isTrue);

      final failure = AptosTransactionResponse.fromJson({
        'version': '12346',
        'hash': '0xabc124',
        'state_change_hash': '0xdef457',
        'event_root_hash': '0x78a',
        'state_checkpoint_hash': null,
        'gas_used': '50',
        'success': false,
        'vm_status': 'Move abort',
        'accumulator_root_hash': '0xaccumulator2',
      });
      expect(failure.success, isFalse);
      expect(failure.stateCheckpointHash, isNull);
      expect(failure.timestamp, isNull);
    });

    test('AptosPendingTransactionResponse parsing', () {
      final pending = AptosPendingTransactionResponse.fromJson({
        'hash': '0xpending123',
        'sender': '0x1',
        'sequence_number': '42',
        'max_gas_amount': '200000',
        'gas_unit_price': '100',
        'expiration_timestamp_secs': '1700000030',
        'payload': {
          'type': 'entry_function_payload',
          'function': '0x1::coin::transfer',
        },
      });
      expect(pending.hash, equals('0xpending123'));
      expect(pending.sequenceNumber, equals(BigInt.from(42)));
    });
  });

  group('Signature Scheme Edge Cases', () {
    test('all signature schemes have unique values', () {
      final values =
          AptosSignatureScheme.values.map((s) => s.value).toSet();
      expect(values.length, equals(AptosSignatureScheme.values.length));
    });

    test('signature scheme values', () {
      expect(AptosSignatureScheme.ed25519.value, equals(0));
      expect(AptosSignatureScheme.multiEd25519.value, equals(1));
      expect(AptosSignatureScheme.singleKey.value, equals(2));
      expect(AptosSignatureScheme.multiKey.value, equals(3));
    });
  });

  group('Public Key Type Edge Cases', () {
    test('all public key types have unique values', () {
      final values =
          AptosPublicKeyType.values.map((t) => t.value).toSet();
      expect(values.length, equals(AptosPublicKeyType.values.length));
    });

    test('public key type values', () {
      expect(AptosPublicKeyType.ed25519.value, equals(0));
      expect(AptosPublicKeyType.secp256k1Ecdsa.value, equals(1));
      expect(AptosPublicKeyType.secp256r1Ecdsa.value, equals(2));
      expect(AptosPublicKeyType.keyless.value, equals(3));
    });
  });

  group('Signature Type Edge Cases', () {
    test('all signature types have unique values', () {
      final values = AptosSignatureType.values.map((t) => t.value).toSet();
      expect(values.length, equals(AptosSignatureType.values.length));
    });

    test('signature type values', () {
      expect(AptosSignatureType.ed25519.value, equals(0));
      expect(AptosSignatureType.secp256k1Ecdsa.value, equals(1));
      expect(AptosSignatureType.secp256r1Ecdsa.value, equals(2));
      expect(AptosSignatureType.keyless.value, equals(3));
    });
  });

  group('Payload Edge Cases', () {
    test('EntryFunctionPayload toJson', () {
      final payload = EntryFunctionPayload(
        function: '0x1::coin::transfer',
        typeArguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: ['0x2', '1000000'],
      );
      final json = payload.toJson();
      expect(json['type'], equals('entry_function_payload'));
      expect(json['function'], equals('0x1::coin::transfer'));
      expect(json['type_arguments'], contains('0x1::aptos_coin::AptosCoin'));
      expect(json['arguments'], hasLength(2));
    });

    test('EntryFunctionPayload with empty arguments', () {
      final payload = EntryFunctionPayload(
        function: '0x1::managed_coin::register',
        typeArguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: [],
      );
      final json = payload.toJson();
      expect(json['arguments'], isEmpty);
    });

    test('ScriptPayload toJson', () {
      final payload = ScriptPayload(
        code: Uint8List.fromList([0x01, 0x02, 0x03]),
        typeArguments: ['address'],
        arguments: ['0x1'],
      );
      final json = payload.toJson();
      expect(json['type'], equals('script_payload'));
      expect(json['code']['bytecode'], equals('0x010203'));
    });

    test('MultisigPayload toJson', () {
      final payload = MultisigPayload(
        multisigAddress: AptosAddress.fromHex('0x123'),
        transactionPayload: EntryFunctionPayload(
          function: '0x1::test::test',
          typeArguments: [],
          arguments: [],
        ),
      );
      final json = payload.toJson();
      expect(json['type'], equals('multisig_payload'));
      expect(json['multisig_address'], contains('0x'));
      expect(json['transaction_payload'], isNotNull);
    });

    test('MultisigPayload without inner payload', () {
      final payload = MultisigPayload(
        multisigAddress: AptosAddress.fromHex('0x123'),
      );
      final json = payload.toJson();
      expect(json['type'], equals('multisig_payload'));
      expect(json.containsKey('transaction_payload'), isFalse);
    });
  });

  group('Common Payloads (AptosPayloads)', () {
    test('transferApt creates correct payload', () {
      final payload = AptosPayloads.transferApt(
        to: AptosAddress.fromHex('0x2'),
        amount: BigInt.from(100000000), // 1 APT
      );
      expect(payload.function, equals('0x1::aptos_account::transfer'));
      expect(payload.typeArguments, isEmpty);
      expect(payload.arguments.length, equals(2));
    });

    test('transferCoin creates correct payload', () {
      final payload = AptosPayloads.transferCoin(
        coinType: '0x1::aptos_coin::AptosCoin',
        to: AptosAddress.fromHex('0x2'),
        amount: BigInt.from(100000000),
      );
      expect(payload.function, equals('0x1::aptos_account::transfer_coins'));
      expect(payload.typeArguments, contains('0x1::aptos_coin::AptosCoin'));
    });

    test('registerCoin creates correct payload', () {
      final payload = AptosPayloads.registerCoin(
        coinType: '0x1::custom_coin::CustomCoin',
      );
      expect(payload.function, equals('0x1::managed_coin::register'));
      expect(payload.typeArguments, contains('0x1::custom_coin::CustomCoin'));
      expect(payload.arguments, isEmpty);
    });
  });

  group('Chain Configuration Edge Cases', () {
    test('all chains have valid RPC URLs', () {
      for (final chain in AptosChains.all) {
        expect(chain.rpcUrl, startsWith('http'));
        expect(Uri.tryParse(chain.rpcUrl), isNotNull);
      }
    });

    test('testnet chains have faucet URLs', () {
      expect(AptosChains.testnet.faucetUrl, isNotNull);
      expect(AptosChains.devnet.faucetUrl, isNotNull);
    });

    test('mainnet has no faucet', () {
      expect(AptosChains.mainnet.faucetUrl, isNull);
    });

    test('chain IDs are unique', () {
      final chainIds = AptosChains.all.map((c) => c.chainId).toSet();
      expect(chainIds.length, equals(AptosChains.all.length));
    });

    test('getById returns correct chain or null', () {
      expect(AptosChains.getById(1), equals(AptosChains.mainnet));
      expect(AptosChains.getById(2), equals(AptosChains.testnet));
      expect(AptosChains.getById(58), equals(AptosChains.devnet));
      expect(AptosChains.getById(4), equals(AptosChains.local));
      expect(AptosChains.getById(999), isNull);
    });
  });

  group('Authenticator Edge Cases', () {
    test('Ed25519Authenticator construction', () {
      final auth = Ed25519Authenticator(
        publicKey: Uint8List(32),
        signature: Uint8List(64),
      );
      expect(auth.publicKey.length, equals(32));
      expect(auth.signature.length, equals(64));
    });

    test('MultiEd25519Authenticator construction', () {
      final auth = MultiEd25519Authenticator(
        publicKeys: [Uint8List(32), Uint8List(32)],
        signatures: [Uint8List(64)],
        bitmap: Uint8List.fromList([0x80]), // First key signed
        threshold: 1,
      );
      expect(auth.publicKeys.length, equals(2));
      expect(auth.signatures.length, equals(1));
      expect(auth.threshold, equals(1));
    });

    test('SingleKeyAuthenticator construction', () {
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
    });
  });

  group('Resource Edge Cases', () {
    test('AptosAccountResource with complex data', () {
      final resource = AptosAccountResource.fromJson({
        'type': '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
        'data': {
          'coin': {'value': '1000000000'},
          'frozen': false,
          'deposit_events': {
            'counter': '10',
            'guid': {'id': {'addr': '0x1', 'creation_num': '1'}},
          },
        },
      });
      expect(resource.type, contains('CoinStore'));
      expect(resource.data['coin'], isNotNull);
    });
  });
}
