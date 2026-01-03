import 'dart:typed_data';

import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_multicall/web3_universal_multicall.dart';
import 'package:web3_universal_provider/web3_universal_provider.dart';

/// Mock Contract for testing multicall functionality.
class MockContract extends Contract {
  MockContract()
      : super(
          address: '0x1234567890123456789012345678901234567890',
          abi: _mockAbi,
          publicClient: _createMockClient(),
        );

  static const _mockAbi = '''
[
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [{"name": "account", "type": "address"}],
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "transfer",
      "inputs": [
        {"name": "to", "type": "address"},
        {"name": "amount", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "nonpayable"
    }
  ]''';

  static PublicClient _createMockClient() {
    // Create a minimal mock client for testing
    return MockPublicClientForContract();
  }

  Uint8List encodeFunction(String functionName, List<dynamic> args) {
    // Mock encoding - return function selector + padded args
    switch (functionName) {
      case 'balanceOf':
        // balanceOf(address) selector: 0x70a08231
        return Uint8List.fromList([
          0x70, 0xa0, 0x82, 0x31, // selector
          ...List.filled(12, 0), // padding
          ...List.filled(20, 0), // mock address
        ]);
      case 'transfer':
        // transfer(address,uint256) selector: 0xa9059cbb
        return Uint8List.fromList([
          0xa9, 0x05, 0x9c, 0xbb, // selector
          ...List.filled(12, 0), // padding for address
          ...List.filled(20, 0), // mock address
          ...List.filled(32, 0), // mock amount
        ]);
      default:
        throw ArgumentError('Unknown function: $functionName');
    }
  }
}

/// Minimal mock client for contract testing.
class MockPublicClientForContract extends PublicClient {
  MockPublicClientForContract()
      : super(
          provider: _MockRpcProvider(),
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
}

class _MockRpcProvider extends RpcProvider {
  _MockRpcProvider() : super(_MockTransport());
}

class _MockTransport implements Transport {
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

/// Mock Multicall for testing builder functionality.
class MockMulticall {
  List<Call>? lastAggregateCalls;
  List<Call>? lastTryAggregateCalls;
  List<Call>? lastAggregateWithBlockCalls;
  List<Call>? lastEstimateGasCalls;
  bool? lastRequireSuccess;

  List<CallResult>? _mockAggregateResult;
  List<CallResult>? _mockTryAggregateResult;
  MulticallBlockResult? _mockAggregateWithBlockResult;
  BigInt? _mockEstimateGasResult;

  void mockAggregate(List<CallResult> result) {
    _mockAggregateResult = result;
  }

  void mockTryAggregate(List<CallResult> result) {
    _mockTryAggregateResult = result;
  }

  void mockAggregateWithBlock(MulticallBlockResult result) {
    _mockAggregateWithBlockResult = result;
  }

  void mockEstimateGas(BigInt gas) {
    _mockEstimateGasResult = gas;
  }

  Future<List<CallResult>> aggregate(List<Call> calls) async {
    lastAggregateCalls = calls;
    return _mockAggregateResult ?? [];
  }

  Future<List<CallResult>> tryAggregate(
    List<Call> calls, {
    bool requireSuccess = false,
  }) async {
    lastTryAggregateCalls = calls;
    lastRequireSuccess = requireSuccess;
    return _mockTryAggregateResult ?? [];
  }

  Future<MulticallBlockResult> aggregateWithBlock(List<Call> calls) async {
    lastAggregateWithBlockCalls = calls;
    return _mockAggregateWithBlockResult ??
        MulticallBlockResult(
          blockNumber: BigInt.zero,
          blockHash: '0x',
          results: [],
        );
  }

  Future<BigInt> estimateGas(List<Call> calls) async {
    lastEstimateGasCalls = calls;
    return _mockEstimateGasResult ?? BigInt.zero;
  }
}
