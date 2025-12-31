import 'dart:typed_data';

import 'package:dart_web3_abi/dart_web3_abi.dart' as abi;
import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

/// Mock PublicClient for testing.
class MockPublicClient extends PublicClient {
  CallRequest? lastCallRequest;
  Uint8List? _mockCallResult;
  BigInt? _mockEstimateGasResult;
  String? _mockCallError;

  MockPublicClient()
      : super(
          provider: MockRpcProvider(),
          chain: ChainConfig(
            chainId: 1,
            name: 'Test Chain',
            shortName: 'test',
            nativeCurrency: 'ETH',
            symbol: 'ETH',
            decimals: 18,
            rpcUrls: ['http://localhost:8545'],
            blockExplorerUrls: ['http://localhost'],
          ),
        );

  void mockCall(Uint8List result) {
    _mockCallResult = result;
    _mockCallError = null;
  }

  void mockCallThrow(String error) {
    _mockCallError = error;
    _mockCallResult = null;
  }

  void mockEstimateGas(BigInt gas) {
    _mockEstimateGasResult = gas;
  }

  @override
  Future<Uint8List> call(CallRequest request, [String block = 'latest']) async {
    lastCallRequest = request;
    if (_mockCallError != null) {
      throw Exception(_mockCallError);
    }
    return _mockCallResult ?? Uint8List(0);
  }

  @override
  Future<BigInt> estimateGas(CallRequest request) async {
    return _mockEstimateGasResult ?? BigInt.from(21000);
  }
}

/// Mock WalletClient for testing.
class MockWalletClient extends WalletClient {
  TransactionRequest? lastTransactionRequest;
  String? _mockSendTransactionResult;

  MockWalletClient()
      : super(
          provider: MockRpcProvider(),
          chain: ChainConfig(
            chainId: 1,
            name: 'Test Chain',
            shortName: 'test',
            nativeCurrency: 'ETH',
            symbol: 'ETH',
            decimals: 18,
            rpcUrls: ['http://localhost:8545'],
            blockExplorerUrls: ['http://localhost'],
          ),
          signer: MockSigner(),
        );

  void mockSendTransaction(String txHash) {
    _mockSendTransactionResult = txHash;
  }

  @override
  Future<String> sendTransaction(TransactionRequest request) async {
    lastTransactionRequest = request;
    return _mockSendTransactionResult ?? '0xmocktx';
  }

  @override
  Future<Uint8List> call(CallRequest request, [String block = 'latest']) async {
    return Uint8List(0);
  }

  @override
  Future<BigInt> estimateGas(CallRequest request) async {
    return BigInt.from(21000);
  }
}

/// Mock RpcProvider for testing.
class MockRpcProvider extends RpcProvider {
  MockRpcProvider() : super(MockTransport());

  @override
  Future<BigInt> getBalance(String address, [String block = 'latest']) async {
    return BigInt.zero;
  }

  @override
  Future<Map<String, dynamic>?> getBlockByHash(String blockHash, [bool fullTx = false]) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getBlockByNumber(String block, [bool fullTx = false]) async {
    return null;
  }

  @override
  Future<BigInt> getBlockNumber() async {
    return BigInt.zero;
  }

  @override
  Future<Map<String, dynamic>?> getTransaction(String txHash) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    return null;
  }

  @override
  Future<BigInt> getTransactionCount(String address, [String block = 'latest']) async {
    return BigInt.zero;
  }

  @override
  Future<String> ethCall(Map<String, dynamic> request, [String block = 'latest']) async {
    return '0x';
  }

  @override
  Future<BigInt> estimateGas(Map<String, dynamic> request) async {
    return BigInt.from(21000);
  }

  @override
  Future<List<Map<String, dynamic>>> getLogs(Map<String, dynamic> filter) async {
    return [];
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
  Future<String> getCode(String address, [String block = 'latest']) async {
    return '0x';
  }

  @override
  Future<String> sendRawTransaction(String signedTx) async {
    return '0xmocktx';
  }
}

/// Mock Transport for testing.
class MockTransport implements Transport {
  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    return [];
  }

  @override
  void dispose() {}
}

/// Mock Signer for testing.
class MockSigner implements Signer {
  @override
  EthereumAddress get address => EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');

  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signMessage(String message) async {
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signTypedData(abi.TypedData typedData) async {
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    return Uint8List(65);
  }
}