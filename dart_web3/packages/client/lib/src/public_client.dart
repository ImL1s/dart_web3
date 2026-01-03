import 'dart:typed_data';

import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';

import 'ccip_read.dart';
import 'models.dart';

/// Public client for read-only blockchain operations.
class PublicClient {

  PublicClient({required this.provider, required this.chain}) {
    ccipHandler = CCIPReadHandler(this);
  }
  /// The RPC provider.
  final RpcProvider provider;

  /// The chain configuration.
  final ChainConfig chain;

  /// CCIP-Read handler (EIP-3668).
  late CCIPReadHandler ccipHandler;

  /// Gets the balance of an address.
  Future<BigInt> getBalance(String address, [String block = 'latest']) async {
    return provider.getBalance(address, block);
  }

  /// Gets a block by hash.
  Future<Block?> getBlock(String blockHash) async {
    final data = await provider.getBlockByHash(blockHash, true);
    return data != null ? Block.fromJson(data) : null;
  }

  /// Gets a block by number.
  Future<Block?> getBlockByNumber(String block) async {
    final data = await provider.getBlockByNumber(block, true);
    return data != null ? Block.fromJson(data) : null;
  }

  /// Gets the current block number.
  Future<BigInt> getBlockNumber() async {
    return provider.getBlockNumber();
  }

  /// Gets a transaction by hash.
  Future<Transaction?> getTransaction(String txHash) async {
    final data = await provider.getTransaction(txHash);
    return data != null ? Transaction.fromJson(data) : null;
  }

  /// Gets a transaction receipt.
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    final data = await provider.getTransactionReceipt(txHash);
    return data != null ? TransactionReceipt.fromJson(data) : null;
  }

  /// Gets the transaction count (nonce) for an address.
  Future<BigInt> getTransactionCount(String address, [String block = 'latest']) async {
    return provider.getTransactionCount(address, block);
  }

  /// Executes a call without creating a transaction.
  /// 
  /// Supports EIP-3668 (CCIP-Read) off-chain lookups.
  Future<Uint8List> call(CallRequest request, [String block = 'latest']) async {
    try {
      final result = await provider.ethCall(request.toJson(), block);
      return HexUtils.decode(result);
    } on RpcError catch (e) {
      if (e.data != null && e.data is String) {
        final errorData = HexUtils.decode(e.data as String);
        if (errorData.length >= 4 && 
            BytesUtils.equals(errorData.sublist(0, 4), CCIPReadHandler.offchainLookupSelector)) {
          return await ccipHandler.handle(request.to ?? '', errorData, block);
        }
      }
      rethrow;
    }
  }

  /// Estimates gas for a transaction.
  Future<BigInt> estimateGas(CallRequest request) async {
    return provider.estimateGas(request.toJson());
  }

  /// Gets logs matching a filter.
  Future<List<Log>> getLogs(LogFilter filter) async {
    final data = await provider.getLogs(filter.toJson());
    return data.map(Log.fromJson).toList();
  }

  /// Gets the current gas price.
  Future<BigInt> getGasPrice() async {
    return provider.getGasPrice();
  }

  /// Gets fee data for EIP-1559 transactions.
  Future<FeeData> getFeeData() async {
    final gasPrice = await getGasPrice();
    // Estimate priority fee (simplified)
    final maxPriorityFeePerGas = gasPrice ~/ BigInt.from(10);
    final maxFeePerGas = gasPrice * BigInt.two;

    return FeeData(
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Gets the chain ID.
  Future<int> getChainId() async {
    return provider.getChainId();
  }

  /// Gets the code at an address.
  Future<Uint8List> getCode(String address, [String block = 'latest']) async {
    final result = await provider.getCode(address, block);
    return HexUtils.decode(result);
  }

  /// Disposes of the client.
  void dispose() {
    provider.dispose();
  }
}
