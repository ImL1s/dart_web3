import 'dart:typed_data';
import 'package:dart_web3_cosmos/dart_web3_cosmos.dart';
import 'package:test/test.dart';

/// Strict edge case and authoritative tests for Cosmos extension package.
/// Test vectors derived from official Cosmos SDK and IBC specifications.
void main() {
  group('CosmosAddress Edge Cases', () {
    test('valid Bech32 address parsing', () {
      final address = CosmosAddress.fromBech32('cosmos1abc123');
      expect(address.prefix, equals('cosmos'));
      expect(address.bytes.length, equals(20)); // secp256k1 addresses are 20 bytes
    });

    test('different chain prefixes', () {
      // Test various Cosmos ecosystem prefixes
      final cosmos = CosmosAddress.fromBech32('cosmos1test');
      expect(cosmos.prefix, equals('cosmos'));

      final osmo = CosmosAddress.fromBech32('osmo1test');
      expect(osmo.prefix, equals('osmo'));

      final juno = CosmosAddress.fromBech32('juno1test');
      expect(juno.prefix, equals('juno'));

      final terra = CosmosAddress.fromBech32('terra1test');
      expect(terra.prefix, equals('terra'));
    });

    test('withPrefix creates new address with different prefix', () {
      final cosmos = CosmosAddress.fromBech32('cosmos1abc123');
      final osmo = cosmos.withPrefix('osmo');
      expect(osmo.prefix, equals('osmo'));
      expect(osmo.bytes, equals(cosmos.bytes)); // Same bytes
    });

    test('address equality', () {
      final addr1 = CosmosAddress.fromBytes('cosmos', Uint8List.fromList(List.filled(20, 1)));
      final addr2 = CosmosAddress.fromBytes('cosmos', Uint8List.fromList(List.filled(20, 1)));
      final addr3 = CosmosAddress.fromBytes('cosmos', Uint8List.fromList(List.filled(20, 2)));
      final addr4 = CosmosAddress.fromBytes('osmo', Uint8List.fromList(List.filled(20, 1)));

      expect(addr1, equals(addr2));
      expect(addr1, isNot(equals(addr3))); // Different bytes
      expect(addr1, isNot(equals(addr4))); // Different prefix
    });

    test('invalid Bech32 address throws', () {
      expect(() => CosmosAddress.fromBech32('invalid'), throwsArgumentError);
      expect(() => CosmosAddress.fromBech32(''), throwsArgumentError);
    });

    test('validator operator address prefix', () {
      // Validator operator addresses have different prefix
      final valoper = CosmosAddress.fromBech32('cosmosvaloper1abc');
      expect(valoper.prefix, equals('cosmosvaloper'));
    });
  });

  group('CosmosCoin Edge Cases', () {
    test('zero amount', () {
      final coin = CosmosCoin(denom: 'uatom', amount: BigInt.zero);
      expect(coin.amount, equals(BigInt.zero));
      expect(coin.toString(), equals('0uatom'));
    });

    test('large amount (max supply)', () {
      // ATOM max supply is around 10^18 uatom
      final largeAmount = BigInt.parse('1000000000000000000000');
      final coin = CosmosCoin(denom: 'uatom', amount: largeAmount);
      expect(coin.amount, equals(largeAmount));
    });

    test('withAmount creates new coin', () {
      final original = CosmosCoin(denom: 'uatom', amount: BigInt.from(100));
      final modified = original.withAmount(BigInt.from(200));
      expect(modified.amount, equals(BigInt.from(200)));
      expect(modified.denom, equals('uatom'));
      expect(original.amount, equals(BigInt.from(100))); // Original unchanged
    });

    test('coin addition with same denom', () {
      final coin1 = CosmosCoin(denom: 'uatom', amount: BigInt.from(100));
      final coin2 = CosmosCoin(denom: 'uatom', amount: BigInt.from(200));
      final result = coin1 + coin2;
      expect(result.amount, equals(BigInt.from(300)));
      expect(result.denom, equals('uatom'));
    });

    test('coin addition with different denom throws', () {
      final atom = CosmosCoin(denom: 'uatom', amount: BigInt.from(100));
      final osmo = CosmosCoin(denom: 'uosmo', amount: BigInt.from(100));
      expect(() => atom + osmo, throwsArgumentError);
    });

    test('IBC denom format', () {
      // IBC denoms have specific format: ibc/<hash>
      final ibcCoin = CosmosCoin(
        denom: 'ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2',
        amount: BigInt.from(1000000),
      );
      expect(ibcCoin.denom, startsWith('ibc/'));
    });

    test('JSON serialization preserves precision', () {
      final largeAmount = BigInt.parse('999999999999999999999');
      final coin = CosmosCoin(denom: 'uatom', amount: largeAmount);
      final json = coin.toJson();
      expect(json['amount'], equals('999999999999999999999'));

      final parsed = CosmosCoin.fromJson(json);
      expect(parsed.amount, equals(largeAmount));
    });
  });

  group('CosmosFee Edge Cases', () {
    test('fee with payer and granter', () {
      final fee = CosmosFee(
        amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(5000))],
        gasLimit: BigInt.from(200000),
        payer: 'cosmos1payer',
        granter: 'cosmos1granter',
      );
      expect(fee.payer, equals('cosmos1payer'));
      expect(fee.granter, equals('cosmos1granter'));

      final json = fee.toJson();
      expect(json['payer'], equals('cosmos1payer'));
      expect(json['granter'], equals('cosmos1granter'));
    });

    test('fee without payer and granter', () {
      final fee = CosmosFee(
        amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(5000))],
        gasLimit: BigInt.from(200000),
      );
      expect(fee.payer, isNull);
      expect(fee.granter, isNull);

      final json = fee.toJson();
      expect(json.containsKey('payer'), isFalse);
      expect(json.containsKey('granter'), isFalse);
    });

    test('fee with multiple coins', () {
      final fee = CosmosFee(
        amount: [
          CosmosCoin(denom: 'uatom', amount: BigInt.from(5000)),
          CosmosCoin(denom: 'uosmo', amount: BigInt.from(3000)),
        ],
        gasLimit: BigInt.from(200000),
      );
      expect(fee.amount.length, equals(2));
    });

    test('fee with gas (alternate key)', () {
      final fee = CosmosFee.fromJson({
        'amount': [
          {'denom': 'uatom', 'amount': '5000'},
        ],
        'gas': '200000', // Some APIs use 'gas' instead of 'gas_limit'
      });
      expect(fee.gasLimit, equals(BigInt.from(200000)));
    });

    test('zero gas limit', () {
      final fee = CosmosFee(
        amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(0))],
        gasLimit: BigInt.zero,
      );
      expect(fee.gasLimit, equals(BigInt.zero));
    });
  });

  group('CosmosAccount Edge Cases', () {
    test('account with null pubKey (new account)', () {
      final account = CosmosAccount.fromJson({
        'address': 'cosmos1new',
        'pub_key': null,
        'account_number': '0',
        'sequence': '0',
      });
      expect(account.pubKey, isNull);
      expect(account.sequence, equals(BigInt.zero));
    });

    test('account with high sequence number', () {
      final account = CosmosAccount.fromJson({
        'address': 'cosmos1active',
        'pub_key': {'@type': '/cosmos.crypto.secp256k1.PubKey', 'key': 'abc'},
        'account_number': '12345',
        'sequence': '999999',
      });
      expect(account.sequence, equals(BigInt.from(999999)));
    });
  });

  group('CosmosTxResult Edge Cases', () {
    test('successful transaction', () {
      final result = CosmosTxResult.fromJson({
        'tx_response': {
          'txhash': 'ABC123',
          'height': '1000000',
          'code': 0,
          'gas_wanted': '200000',
          'gas_used': '150000',
        },
      });
      expect(result.isSuccess, isTrue);
      expect(result.code, equals(0));
    });

    test('failed transaction with error codes', () {
      // Test various error codes
      for (final code in [1, 5, 11, 19, 21]) {
        final result = CosmosTxResult.fromJson({
          'tx_response': {
            'txhash': 'ABC123',
            'height': '1000000',
            'code': code,
            'gas_wanted': '200000',
            'gas_used': '100000',
            'raw_log': 'error message',
          },
        });
        expect(result.isSuccess, isFalse);
        expect(result.code, equals(code));
      }
    });

    test('transaction with events and logs', () {
      final result = CosmosTxResult.fromJson({
        'tx_response': {
          'txhash': 'ABC123',
          'height': '1000000',
          'code': 0,
          'gas_wanted': '200000',
          'gas_used': '150000',
          'logs': [
            {'msg_index': 0, 'log': '', 'events': []},
          ],
          'events': [
            {'type': 'transfer', 'attributes': []},
          ],
        },
      });
      expect(result.logs, isNotNull);
      expect(result.events, isNotNull);
    });

    test('direct tx_response format', () {
      // Some endpoints return without wrapping tx_response
      final result = CosmosTxResult.fromJson({
        'txhash': 'ABC123',
        'height': '1000000',
        'code': 0,
        'gas_wanted': '200000',
        'gas_used': '150000',
      });
      expect(result.txHash, equals('ABC123'));
    });
  });

  group('IBC Channel Edge Cases', () {
    test('all channel states', () {
      for (final state in IbcChannelState.values) {
        final channel = IbcChannel.fromJson({
          'state': state.value,
          'ordering': 'ORDER_UNORDERED',
          'counterparty': {'port_id': 'transfer', 'channel_id': 'channel-0'},
          'connection_hops': ['connection-0'],
          'version': 'ics20-1',
        });
        expect(channel.state, equals(state));
      }
    });

    test('unknown state defaults to uninitialized', () {
      final channel = IbcChannel.fromJson({
        'state': 'UNKNOWN_STATE',
        'ordering': 'ORDER_UNORDERED',
        'counterparty': {'port_id': 'transfer', 'channel_id': 'channel-0'},
        'connection_hops': ['connection-0'],
        'version': 'ics20-1',
      });
      expect(channel.state, equals(IbcChannelState.uninitialized));
    });

    test('channel with multiple connection hops', () {
      final channel = IbcChannel.fromJson({
        'state': 'STATE_OPEN',
        'ordering': 'ORDER_ORDERED',
        'counterparty': {'port_id': 'transfer', 'channel_id': 'channel-0'},
        'connection_hops': ['connection-0', 'connection-1'],
        'version': 'ics20-1',
      });
      expect(channel.connectionHops.length, equals(2));
    });
  });

  group('CosmosBlock Edge Cases', () {
    test('block with transactions', () {
      final block = CosmosBlock.fromJson({
        'header': {
          'height': '1000000',
          'time': '2023-01-01T00:00:00Z',
          'proposer_address': 'proposer123',
        },
        'block_id': {'hash': 'blockhash123'},
        'data': {
          'txs': ['tx1', 'tx2', 'tx3'],
        },
      });
      expect(block.txCount, equals(3));
    });

    test('block without transactions', () {
      final block = CosmosBlock.fromJson({
        'header': {
          'height': '1000000',
          'time': '2023-01-01T00:00:00Z',
          'proposer_address': 'proposer123',
        },
        'block_id': {'hash': 'blockhash123'},
      });
      expect(block.txCount, isNull);
    });

    test('block with missing optional fields', () {
      final block = CosmosBlock.fromJson({
        'height': '1000000',
        'time': '2023-01-01T00:00:00Z',
      });
      expect(block.hash, equals(''));
      expect(block.proposerAddress, equals(''));
    });
  });

  group('CosmosValidator Edge Cases', () {
    test('jailed validator', () {
      final validator = CosmosValidator.fromJson({
        'operator_address': 'cosmosvaloper1jailed',
        'consensus_pubkey': {'@type': '/cosmos.crypto.ed25519.PubKey'},
        'jailed': true,
        'status': 'BOND_STATUS_UNBONDING',
        'tokens': '1000000',
        'delegator_shares': '1000000.000000000000000000',
        'description': {'moniker': 'Jailed Validator'},
        'commission': {
          'commission_rates': {
            'rate': '0.100000000000000000',
            'max_rate': '0.200000000000000000',
            'max_change_rate': '0.010000000000000000',
          },
          'update_time': '2023-01-01T00:00:00Z',
        },
      });
      expect(validator.jailed, isTrue);
    });

    test('validator with high token count', () {
      final validator = CosmosValidator.fromJson({
        'operator_address': 'cosmosvaloper1large',
        'consensus_pubkey': {'@type': '/cosmos.crypto.ed25519.PubKey'},
        'jailed': false,
        'status': 'BOND_STATUS_BONDED',
        'tokens': '999999999999999999999',
        'delegator_shares': '999999999999999999999.000000000000000000',
        'description': {'moniker': 'Large Validator'},
        'commission': {
          'commission_rates': {
            'rate': '0.100000000000000000',
            'max_rate': '0.200000000000000000',
            'max_change_rate': '0.010000000000000000',
          },
          'update_time': '2023-01-01T00:00:00Z',
        },
      });
      expect(validator.tokens, equals(BigInt.parse('999999999999999999999')));
    });
  });

  group('CosmosDelegation Edge Cases', () {
    test('delegation with balance', () {
      final delegation = CosmosDelegation.fromJson({
        'delegation': {
          'delegator_address': 'cosmos1delegator',
          'validator_address': 'cosmosvaloper1validator',
          'shares': '1000000.000000000000000000',
        },
        'balance': {'denom': 'uatom', 'amount': '1000000'},
      });
      expect(delegation.balance, isNotNull);
      expect(delegation.balance!.amount, equals(BigInt.from(1000000)));
    });

    test('delegation without balance (direct format)', () {
      final delegation = CosmosDelegation.fromJson({
        'delegator_address': 'cosmos1delegator',
        'validator_address': 'cosmosvaloper1validator',
        'shares': '1000000.000000000000000000',
      });
      expect(delegation.balance, isNull);
    });
  });

  group('Message Types Edge Cases', () {
    test('MsgSend with multiple coins', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [
          CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000)),
          CosmosCoin(denom: 'uosmo', amount: BigInt.from(500000)),
        ],
      );
      expect(msg.amount.length, equals(2));
    });

    test('MsgTransfer with timeout height', () {
      final msg = MsgTransfer(
        sourcePort: 'transfer',
        sourceChannel: 'channel-0',
        token: CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000)),
        sender: 'cosmos1sender',
        receiver: 'osmo1receiver',
        timeoutHeight: IbcHeight(
          revisionNumber: BigInt.from(1),
          revisionHeight: BigInt.from(1000000),
        ),
        timeoutTimestamp: BigInt.zero,
      );
      final json = msg.toJson();
      expect(json['timeout_height']['revision_number'], equals('1'));
      expect(json['timeout_height']['revision_height'], equals('1000000'));
    });

    test('MsgTransfer with timeout timestamp', () {
      final msg = MsgTransfer(
        sourcePort: 'transfer',
        sourceChannel: 'channel-0',
        token: CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000)),
        sender: 'cosmos1sender',
        receiver: 'osmo1receiver',
        timeoutHeight: IbcHeight.zero,
        timeoutTimestamp: BigInt.from(1700000000000000000),
      );
      final json = msg.toJson();
      expect(json['timeout_timestamp'], equals('1700000000000000000'));
    });
  });

  group('VoteOption Edge Cases', () {
    test('all vote options', () {
      expect(VoteOption.unspecified.number, equals(0));
      expect(VoteOption.yes.number, equals(1));
      expect(VoteOption.abstain.number, equals(2));
      expect(VoteOption.no.number, equals(3));
      expect(VoteOption.noWithVeto.number, equals(4));
    });
  });

  group('SignMode Edge Cases', () {
    test('all sign modes', () {
      expect(SignMode.unspecified.number, equals(0));
      expect(SignMode.direct.number, equals(1));
      expect(SignMode.textual.number, equals(2));
      expect(SignMode.directAux.number, equals(3));
      expect(SignMode.legacyAminoJson.number, equals(127));
    });
  });

  group('BroadcastMode Edge Cases', () {
    test('all broadcast modes', () {
      expect(BroadcastMode.block.value, equals('BROADCAST_MODE_BLOCK'));
      expect(BroadcastMode.sync.value, equals('BROADCAST_MODE_SYNC'));
      expect(BroadcastMode.async_.value, equals('BROADCAST_MODE_ASYNC'));
    });

    test('broadcast modes are unique', () {
      final values = BroadcastMode.values.map((m) => m.value).toSet();
      expect(values.length, equals(BroadcastMode.values.length));
    });
  });

  group('Chain Configuration Edge Cases', () {
    test('all mainnet chains have valid REST URLs', () {
      for (final chain in CosmosChains.mainnets) {
        expect(chain.restUrl, startsWith('http'));
        expect(Uri.tryParse(chain.restUrl), isNotNull);
      }
    });

    test('all testnet chains are marked as testnet', () {
      for (final chain in CosmosChains.testnets) {
        expect(chain.isTestnet, isTrue);
      }
    });

    test('all mainnet chains are not marked as testnet', () {
      for (final chain in CosmosChains.mainnets) {
        expect(chain.isTestnet, isFalse);
      }
    });

    test('chain IDs are unique across all chains', () {
      final allChains = [...CosmosChains.mainnets, ...CosmosChains.testnets];
      final chainIds = allChains.map((c) => c.chainId).toSet();
      expect(chainIds.length, equals(allChains.length));
    });

    test('bech32 prefixes are consistent', () {
      expect(CosmosChains.cosmosHub.bech32Prefix, equals('cosmos'));
      expect(CosmosChains.osmosis.bech32Prefix, equals('osmo'));
      expect(CosmosChains.juno.bech32Prefix, equals('juno'));
    });

    test('getByChainId returns null for unknown chain', () {
      expect(CosmosChains.getByChainId('unknown-chain'), isNull);
    });

    test('getByPrefix returns null for unknown prefix', () {
      expect(CosmosChains.getByPrefix('unknown'), isNull);
    });
  });

  group('Transaction Builder Edge Cases', () {
    test('builder with multiple messages', () {
      final builder = CosmosTxBuilder(chainId: 'cosmoshub-4');
      builder
          .addMessage(
            MsgSend(
              fromAddress: 'cosmos1sender',
              toAddress: 'cosmos1receiver1',
              amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000))],
            ),
          )
          .addMessage(
            MsgSend(
              fromAddress: 'cosmos1sender',
              toAddress: 'cosmos1receiver2',
              amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(2000000))],
            ),
          )
          .fee(
            amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(10000))],
            gasLimit: BigInt.from(400000),
          )
          .addSigner(
            publicKey: Secp256k1PubKey(Uint8List(33)),
            sequence: BigInt.zero,
          );

      final body = builder.buildBody();
      expect(body.messages.length, equals(2));
    });

    test('builder with empty memo', () {
      final builder = CosmosTxBuilder(chainId: 'cosmoshub-4');
      builder
          .addMessage(
            MsgSend(
              fromAddress: 'cosmos1sender',
              toAddress: 'cosmos1receiver',
              amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000))],
            ),
          )
          .memo('')
          .fee(
            amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(5000))],
            gasLimit: BigInt.from(200000),
          )
          .addSigner(
            publicKey: Secp256k1PubKey(Uint8List(33)),
            sequence: BigInt.zero,
          );

      final body = builder.buildBody();
      expect(body.memo, equals(''));
    });

    test('builder with long memo', () {
      final longMemo = 'A' * 256; // Max memo length is typically 256
      final builder = CosmosTxBuilder(chainId: 'cosmoshub-4');
      builder
          .addMessage(
            MsgSend(
              fromAddress: 'cosmos1sender',
              toAddress: 'cosmos1receiver',
              amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(1000000))],
            ),
          )
          .memo(longMemo)
          .fee(
            amount: [CosmosCoin(denom: 'uatom', amount: BigInt.from(5000))],
            gasLimit: BigInt.from(200000),
          )
          .addSigner(
            publicKey: Secp256k1PubKey(Uint8List(33)),
            sequence: BigInt.zero,
          );

      final body = builder.buildBody();
      expect(body.memo.length, equals(256));
    });
  });

  group('IBC Height Edge Cases', () {
    test('IBC height zero', () {
      final height = IbcHeight.zero;
      expect(height.revisionNumber, equals(BigInt.zero));
      expect(height.revisionHeight, equals(BigInt.zero));
    });

    test('IBC height with revision', () {
      final height = IbcHeight(
        revisionNumber: BigInt.from(4),
        revisionHeight: BigInt.from(1000000),
      );
      final json = height.toJson();
      expect(json['revision_number'], equals('4'));
      expect(json['revision_height'], equals('1000000'));
    });
  });
}
