
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

import 'contract.dart';

/// Factory for creating and deploying contracts.
class ContractFactory {
  ContractFactory._();

  /// Creates a contract instance.
  static Contract create({
    required String address,
    required String abi,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) {
    return Contract(
      address: address,
      abi: abi,
      publicClient: publicClient,
      walletClient: walletClient,
    );
  }

  /// Deploys a new contract.
  static Future<DeployResult> deploy({
    required String bytecode,
    required WalletClient walletClient,
    String? abi,
    List<dynamic> constructorArgs = const [],
    BigInt? value,
    BigInt? gasLimit,
  }) async {
    // For now, we'll keep deployment simple without constructor args
    if (constructorArgs.isNotEmpty) {
      throw UnimplementedError('Constructor arguments not yet supported');
    }

    final deployData = HexUtils.decode(bytecode);

    // Create deployment transaction
    final request = TransactionRequest(
      data: deployData,
      value: value,
      gasLimit: gasLimit,
    );

    // Send deployment transaction
    final txHash = await walletClient.sendTransaction(request);

    // Wait for transaction receipt to get contract address
    TransactionReceipt? receipt;
    var attempts = 0;
    const maxAttempts = 60; // Wait up to 60 seconds

    while (receipt == null && attempts < maxAttempts) {
      await Future<void>.delayed(const Duration(seconds: 1));
      receipt = await walletClient.getTransactionReceipt(txHash);
      attempts++;
    }

    if (receipt == null) {
      throw Exception('Deployment transaction not mined within timeout');
    }

    if (!receipt.success) {
      throw Exception('Contract deployment failed');
    }

    if (receipt.contractAddress == null) {
      throw Exception('No contract address in deployment receipt');
    }

    // Create contract instance
    final contract = Contract(
      address: receipt.contractAddress!,
      abi: abi ?? '[]',
      publicClient: walletClient,
      walletClient: walletClient,
    );

    return DeployResult(
      contract: contract,
      transactionHash: txHash,
      receipt: receipt,
    );
  }

  /// Estimates gas for contract deployment.
  static Future<BigInt> estimateDeployGas({
    required String bytecode,
    required PublicClient publicClient,
    required String from,
    List<dynamic> constructorArgs = const [],
    BigInt? value,
  }) async {
    // For now, we'll keep deployment simple without constructor args
    if (constructorArgs.isNotEmpty) {
      throw UnimplementedError('Constructor arguments not yet supported');
    }

    final deployData = HexUtils.decode(bytecode);

    final request = CallRequest(
      from: from,
      data: deployData,
      value: value,
    );

    return publicClient.estimateGas(request);
  }
}

/// Result of a contract deployment.
class DeployResult {

  DeployResult({
    required this.contract,
    required this.transactionHash,
    required this.receipt,
  });
  /// The deployed contract instance.
  final Contract contract;

  /// The deployment transaction hash.
  final String transactionHash;

  /// The deployment transaction receipt.
  final TransactionReceipt receipt;

  /// The deployed contract address.
  String get address => contract.address;
}
