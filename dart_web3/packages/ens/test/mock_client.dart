import 'dart:typed_data';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_provider/web3_universal_provider.dart';

class MockPublicClient implements PublicClient {
  final List<Uint8List> _mockCallResults = [];
  final List<Exception> _mockCallExceptions = [];

  void mockCall(Uint8List result) {
    _mockCallResults.add(result);
  }

  void mockCallThrow(String message) {
    _mockCallExceptions.add(Exception(message));
  }

  @override
  Future<Uint8List> call(CallRequest request, [String block = 'latest']) async {
    if (_mockCallExceptions.isNotEmpty) {
      throw _mockCallExceptions.removeAt(0);
    }
    if (_mockCallResults.isNotEmpty) {
      return _mockCallResults.removeAt(0);
    }
    throw Exception('No mock result set for request to ${request.to}');
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
  Future<BigInt> getTransactionCount(String address,
      [String block = 'latest']) async {
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

  @override
  Future<String> sendTransaction(Uint8List tx) async {
    return '0x${List.generate(64, (_) => '0').join()}';
  }

  @override
  late CCIPReadHandler ccipHandler;
}
