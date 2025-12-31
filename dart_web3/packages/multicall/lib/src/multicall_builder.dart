import 'dart:typed_data';
import 'package:dart_web3_contract/dart_web3_contract.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'multicall.dart';

/// Builder for creating multicall batches with type-safe contract calls.
class MulticallBuilder {
  final List<Call> _calls = [];
  
  /// Adds a contract function call to the batch.
  MulticallBuilder addCall({
    required Contract contract,
    required String functionName,
    required List<dynamic> args,
    bool allowFailure = false,
  }) {
    final callData = contract.encodeFunction(functionName, args);
    
    _calls.add(Call(
      target: contract.address,
      callData: callData,
      allowFailure: allowFailure,
    ));
    
    return this;
  }
  
  /// Adds a raw call to the batch.
  MulticallBuilder addRawCall({
    required String target,
    required Uint8List callData,
    bool allowFailure = false,
  }) {
    _calls.add(Call(
      target: target,
      callData: callData,
      allowFailure: allowFailure,
    ));
    
    return this;
  }
  
  /// Adds multiple calls from another builder.
  MulticallBuilder addAll(MulticallBuilder other) {
    _calls.addAll(other._calls);
    return this;
  }
  
  /// Clears all calls from the builder.
  MulticallBuilder clear() {
    _calls.clear();
    return this;
  }
  
  /// Gets the current list of calls.
  List<Call> get calls => List.unmodifiable(_calls);
  
  /// Gets the number of calls in the batch.
  int get length => _calls.length;
  
  /// Checks if the batch is empty.
  bool get isEmpty => _calls.isEmpty;
  
  /// Checks if the batch is not empty.
  bool get isNotEmpty => _calls.isNotEmpty;
  
  /// Executes the batch using the provided multicall instance.
  Future<List<CallResult>> execute(Multicall multicall) async {
    if (_calls.isEmpty) {
      return [];
    }
    
    return await multicall.aggregate(_calls);
  }
  
  /// Executes the batch with failure handling.
  Future<List<CallResult>> tryExecute(
    Multicall multicall, {
    bool requireSuccess = false,
  }) async {
    if (_calls.isEmpty) {
      return [];
    }
    
    return await multicall.tryAggregate(_calls, requireSuccess: requireSuccess);
  }
  
  /// Executes the batch and returns block information.
  Future<MulticallBlockResult> executeWithBlock(Multicall multicall) async {
    if (_calls.isEmpty) {
      return MulticallBlockResult(
        blockNumber: BigInt.zero,
        blockHash: '0x',
        results: [],
      );
    }
    
    return await multicall.aggregateWithBlock(_calls);
  }
  
  /// Estimates gas for the batch.
  Future<BigInt> estimateGas(Multicall multicall) async {
    if (_calls.isEmpty) {
      return BigInt.zero;
    }
    
    return await multicall.estimateGas(_calls);
  }
}

/// Extension on Contract to add multicall builder integration.
extension ContractMulticallExtension on Contract {
  /// Encodes a function call for use in multicall.
  Uint8List encodeFunction(String functionName, List<dynamic> args) {
    final function = functions.firstWhere(
      (f) => f.name == functionName,
      orElse: () => throw ArgumentError('Function $functionName not found'),
    );
    
    return AbiEncoder.encodeFunction(function.signature, args);
  }
  
  /// Creates a multicall builder with this contract's call.
  MulticallBuilder multicallBuilder({
    required String functionName,
    required List<dynamic> args,
    bool allowFailure = false,
  }) {
    return MulticallBuilder().addCall(
      contract: this,
      functionName: functionName,
      args: args,
      allowFailure: allowFailure,
    );
  }
}

/// Utility class for common multicall patterns.
class MulticallUtils {
  /// Creates a batch of ERC-20 balance calls.
  static MulticallBuilder createBalanceBatch({
    required List<String> tokens,
    required String account,
  }) {
    final builder = MulticallBuilder();
    
    for (final token in tokens) {
      // ERC-20 balanceOf function selector: 0x70a08231
      final selector = [0x70, 0xa0, 0x82, 0x31];
      final paddedAccount = _padAddress(account);
      final callData = Uint8List.fromList([...selector, ...paddedAccount]);
      
      builder.addRawCall(
        target: token,
        callData: callData,
        allowFailure: true, // Allow failure for invalid tokens
      );
    }
    
    return builder;
  }
  
  /// Creates a batch of ERC-20 allowance calls.
  static MulticallBuilder createAllowanceBatch({
    required List<String> tokens,
    required String owner,
    required String spender,
  }) {
    final builder = MulticallBuilder();
    
    for (final token in tokens) {
      // ERC-20 allowance function selector: 0xdd62ed3e
      final selector = [0xdd, 0x62, 0xed, 0x3e];
      final paddedOwner = _padAddress(owner);
      final paddedSpender = _padAddress(spender);
      final callData = Uint8List.fromList([
        ...selector,
        ...paddedOwner,
        ...paddedSpender,
      ]);
      
      builder.addRawCall(
        target: token,
        callData: callData,
        allowFailure: true,
      );
    }
    
    return builder;
  }
  
  /// Pads an Ethereum address to 32 bytes.
  static List<int> _padAddress(String address) {
    // Remove 0x prefix if present
    final cleanAddress = address.startsWith('0x') 
        ? address.substring(2) 
        : address;
    
    // Convert to bytes and pad to 32 bytes
    final bytes = <int>[];
    for (int i = 0; i < 12; i++) {
      bytes.add(0); // 12 zero bytes for padding
    }
    
    // Add the 20-byte address
    for (int i = 0; i < cleanAddress.length; i += 2) {
      final hex = cleanAddress.substring(i, i + 2);
      bytes.add(int.parse(hex, radix: 16));
    }
    
    return bytes;
  }
}