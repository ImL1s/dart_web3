import 'package:dart_web3_core/dart_web3_core.dart';

/// Staking protocol types
enum StakingProtocol {
  lido,
  rocketPool,
  native, // Ethereum native staking
  custom,
}

/// Staking opportunity information
class StakingOpportunity {
  final String id;
  final String name;
  final StakingProtocol protocol;
  final EthereumAddress contractAddress;
  final String tokenSymbol;
  final double? apy;
  final BigInt? tvl;
  final String? description;

  const StakingOpportunity({
    required this.id,
    required this.name,
    required this.protocol,
    required this.contractAddress,
    required this.tokenSymbol,
    this.apy,
    this.tvl,
    this.description,
  });

  @override
  String toString() => 'StakingOpportunity(name: $name, protocol: $protocol, apy: $apy%)';
}

/// Staking position information
class StakingPosition {
  final String opportunityId;
  final EthereumAddress owner;
  final BigInt stakedAmount;
  final BigInt? rewards;
  final double? currentApy;

  const StakingPosition({
    required this.opportunityId,
    required this.owner,
    required this.stakedAmount,
    this.rewards,
    this.currentApy,
  });

  @override
  String toString() => 'StakingPosition(opportunity: $opportunityId, amount: $stakedAmount)';
}
