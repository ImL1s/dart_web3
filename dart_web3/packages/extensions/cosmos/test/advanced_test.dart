import 'package:web3_universal_cosmos/web3_universal_cosmos.dart'; // Ensure exported
import 'package:web3_universal_cosmos/src/models/ibc.dart';
import 'package:web3_universal_cosmos/src/models/staking.dart';
import 'package:web3_universal_cosmos/src/models/transaction.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmos Advanced', () {
    test('MsgTransfer serialization', () {
      final msg = MsgTransfer(
        sourcePort: 'transfer',
        sourceChannel: 'channel-0',
        token: Coin(denom: 'uatom', amount: '1000'),
        sender: 'cosmos1sender',
        receiver: 'osmo1receiver',
        timeoutHeight: Height(
            revisionNumber: BigInt.zero, revisionHeight: BigInt.from(100)),
        timeoutTimestamp: BigInt.zero,
      );

      final any = msg.toAny();
      expect(any.typeUrl, '/ibc.applications.transfer.v1.MsgTransfer');
      expect(any.value, isNotNull);
      expect(any.value, isNotEmpty);
    });

    test('MsgDelegate serialization', () {
      final msg = MsgDelegate(
        delegatorAddress: 'cosmos1del',
        validatorAddress: 'cosmosvaloper1val',
        amount: Coin(denom: 'uatom', amount: '1000'),
      );

      final any = msg.toAny();
      expect(any.typeUrl, '/cosmos.staking.v1beta1.MsgDelegate');
      expect(any.value, isNotNull);
      expect(any.value, isNotEmpty);
    });

    test('MsgUndelegate serialization', () {
      final msg = MsgUndelegate(
        delegatorAddress: 'cosmos1del',
        validatorAddress: 'cosmosvaloper1val',
        amount: Coin(denom: 'uatom', amount: '1000'),
      );

      final any = msg.toAny();
      expect(any.typeUrl, '/cosmos.staking.v1beta1.MsgUndelegate');
    });
  });
}
