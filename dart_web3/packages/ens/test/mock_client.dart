import 'dart:typed_data';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';

class MockPublicClient implements PublicClient {
  Map<String, dynamic>? _mockCallResult;
  Exception? _mockCallException;
  
  void mockCall(Uint8List result) {
    _mockCallResult = {'result': result};
    _mockCallException = null;
  }
  
  void mockCallThrow(String message) {
    _mockCallResult = null;
    _mockCallException = Exception(message);
  }

  @override
  Future<Uint8List> call(CallRequest request, [String block = 'latest']) async {
    if (_mockCallException != null) {
      throw _mockCallException!;
    }
    if (_mockCallResult != null) {
      return _mockCallResult!['result'] as Uint8List;
    }
    throw Exception('No mock result set');
  }

  // Implement other required methods with minimal functionality
  @override
  Future<BigInt> getBalance(String address, [String block = 'latest']) async {
    return BigInt.zero;
  }

  @override
  Future<Block?> getBlock(String blockHash) async {
    return null;
  }

  @override
  Future<Block?> getBlockByNumber(String block) async {
    return null;
  }

  @override
  Future<BigInt> getBlockNumber() async {
    return BigInt.one;
  }

  @override
  Future<Transaction?> getTransaction(String txHash) async {
    return null;
  }

  @override
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    return null;
  }

  @override
  Future<BigInt> getTransactionCount(String address, [String block = 'latest']) async {
    return BigInt.zero;
  }

  @override
  Future<BigInt> estimateGas(CallRequest request) async {
    return BigInt.from(21000);
  }

  @override
  Future<List<Log>> getLogs(LogFilter filter) async {
    return [];
  }

  @override
  Future<FeeData> getFeeData() async {
    return FeeData(
      gasPrice: BigInt.from(20000000000),
      maxFeePerGas: BigInt.from(30000000000),
      maxPriorityFeePerGas: BigInt.from(2000000000),
    );
  }

  @override
  Future<BigInt> getGasPrice() async {
    return BigInt.from(20000000000);
  }

  @override
  Future<int> getChainId() async {
    return 1;
  }

  @override
  Future<Uint8List> getCode(String address, [String block = 'latest']) async {
    return Uint8List(0);
  }

  @override
  void dispose() {
    // No-op for mock
  }

  @override
  RpcProvider get provider => throw UnimplementedError();

  @override
  ChainConfig get chain => throw UnimplementedError();
}