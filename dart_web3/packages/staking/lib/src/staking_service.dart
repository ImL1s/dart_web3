import 'dart:async';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'staking_types.dart';

/// Service for managing staking operations across different protocols
class StakingService {

  StakingService({
    required PublicClient publicClient,
    WalletClient? walletClient,
  })  : _publicClient = publicClient,
        _walletClient = walletClient;
  final PublicClient _publicClient;
  final WalletClient? _walletClient;

  /// Get available staking opportunities
  Future<List<StakingOpportunity>> getOpportunities() async {
    // This would ideally fetch from a registry or external API
    // For now, returning pre-defined major protocols
    return [
      StakingOpportunity(
        id: 'eth-lido',
        name: 'Lido Staked ETH',
        protocol: StakingProtocol.lido,
        contractAddress: EthereumAddress.fromHex('0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84'),
        tokenSymbol: 'stETH',
        description: 'Liquid staking for Ethereum',
      ),
      StakingOpportunity(
        id: 'eth-rocketpool',
        name: 'Rocket Pool ETH',
        protocol: StakingProtocol.rocketPool,
        contractAddress: EthereumAddress.fromHex('0xae78736Cd615f374D3085123A210448E74Fc6393'),
        tokenSymbol: 'rETH',
        description: 'Decentralized Ethereum staking',
      ),
    ];
  }

  /// Get user's staking positions
  Future<List<StakingPosition>> getPositions(EthereumAddress owner) async {
    final positions = <StakingPosition>[];
    final opportunities = await getOpportunities();

    for (final opp in opportunities) {
      final balance = await _getStakedBalance(opp, owner);
      if (balance > BigInt.zero) {
        positions.add(StakingPosition(
          opportunityId: opp.id,
          owner: owner,
          stakedAmount: balance,
        ),);
      }
    }

    return positions;
  }

  /// Stake assets (requires wallet client)
  Future<String> stake(StakingOpportunity opportunity, BigInt amount) async {
    if (_walletClient == null) {
      throw Exception('Wallet client required for staking');
    }

    switch (opportunity.protocol) {
      case StakingProtocol.lido:
        return _stakeLido(opportunity, amount);
      case StakingProtocol.rocketPool:
        return _stakeRocketPool(opportunity, amount);
      default:
        throw UnimplementedError('Staking for ${opportunity.protocol} not implemented');
    }
  }

  /// Unstake assets (requires wallet client)
  Future<String> unstake(StakingOpportunity opportunity, BigInt amount) async {
    if (_walletClient == null) {
      throw Exception('Wallet client required for unstaking');
    }
    // Implementation varies by protocol (unstaking often involves a withdrawal request)
    throw UnimplementedError('Unstaking for ${opportunity.protocol} not implemented');
  }

  Future<BigInt> _getStakedBalance(StakingOpportunity opp, EthereumAddress owner) async {
    try {
      final contract = Contract(
        address: opp.contractAddress.hex,
        abi: _erc20BalanceOfAbi,
        publicClient: _publicClient,
      );
      return await contract.read('balanceOf', [owner.hex]) as BigInt;
    } on Exception catch (_) {
      return BigInt.zero;
    }
  }

  Future<String> _stakeLido(StakingOpportunity opp, BigInt amount) async {
    final contract = Contract(
      address: opp.contractAddress.hex,
      abi: '[{"inputs":[],"name":"submit","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"payable","type":"function"}]',
      publicClient: _publicClient,
      walletClient: _walletClient,
    );

    return contract.write('submit', [], value: amount);
  }

  Future<String> _stakeRocketPool(StakingOpportunity opp, BigInt amount) async {
    // Rocket Pool deposit requires interacting with the Deposit Pool contract
    // This is a simplified example
    throw UnimplementedError('Rocket Pool staking logic pending complex contract integration');
  }

  static const _erc20BalanceOfAbi = '[{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]';
}
