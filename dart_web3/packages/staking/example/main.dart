import 'package:web3_universal_staking/web3_universal_staking.dart';

void main() async {
  // Initialize Staking service
  final staking = StakingService.lido();

  // Get staking APR
  // final apr = await staking.getApr();
  // print('Lido APR: $apr%');

  print('Staking service initialized');
}
