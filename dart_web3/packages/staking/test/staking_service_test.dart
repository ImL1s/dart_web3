import 'package:test/test.dart';
import 'package:dart_web3_staking/dart_web3_staking.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('Staking Service Types Tests', () {
    test('should create StakingOpportunity with correct values', () {
      final contractAddress = EthereumAddress.fromHex('0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84');
      final opportunity = StakingOpportunity(
        id: 'eth-lido',
        name: 'Lido Staked ETH',
        protocol: StakingProtocol.lido,
        contractAddress: contractAddress,
        tokenSymbol: 'stETH',
        apy: 3.5,
      );

      expect(opportunity.id, equals('eth-lido'));
      expect(opportunity.name, equals('Lido Staked ETH'));
      expect(opportunity.protocol, equals(StakingProtocol.lido));
      expect(opportunity.contractAddress, equals(contractAddress));
      expect(opportunity.tokenSymbol, equals('stETH'));
      expect(opportunity.apy, equals(3.5));
    });

    test('should create StakingPosition with correct values', () {
      final owner = EthereumAddress.fromHex('0x1111111111111111111111111111111111111111');
      final position = StakingPosition(
        opportunityId: 'eth-lido',
        owner: owner,
        stakedAmount: BigInt.from(1000000000000000000), // 1 ETH
        rewards: BigInt.from(50000000000000000), // 0.05 ETH
      );

      expect(position.opportunityId, equals('eth-lido'));
      expect(position.owner, equals(owner));
      expect(position.stakedAmount, equals(BigInt.from(1000000000000000000)));
      expect(position.rewards, equals(BigInt.from(50000000000000000)));
    });
  });
}
