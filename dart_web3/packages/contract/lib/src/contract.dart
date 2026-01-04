import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'event_filter.dart';
import 'simulate_result.dart';

/// Smart contract abstraction for type-safe contract interactions.
class Contract {
  Contract({
    required this.address,
    required String abi,
    required this.publicClient,
    this.walletClient,
  })  : functions = AbiParser.parseFunctions(abi),
        events = AbiParser.parseEvents(abi),
        errors = AbiParser.parseErrors(abi);

  /// The contract address.
  final String address;

  /// The contract functions.
  final List<AbiFunction> functions;

  /// The contract events.
  final List<AbiEvent> events;

  /// The contract errors.
  final List<AbiError> errors;

  /// The public client for read operations.
  final PublicClient publicClient;

  /// The wallet client for write operations (optional).
  final WalletClient? walletClient;

  /// Executes a read-only contract function call.
  Future<List<dynamic>> read(
    String functionName,
    List<dynamic> args, [
    String block = 'latest',
  ]) async {
    final function = _getFunction(functionName);
    if (!function.isReadOnly) {
      throw ArgumentError('Function $functionName is not read-only');
    }

    final callData = AbiEncoder.encodeFunction(function.signature, args);
    final request = CallRequest(
      to: address,
      data: callData,
    );

    final result = await publicClient.call(request, block);
    return AbiDecoder.decodeFunction(function.outputs, result);
  }

  /// Executes a state-changing contract function.
  Future<String> write(
    String functionName,
    List<dynamic> args, {
    BigInt? value,
    BigInt? gasLimit,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    if (walletClient == null) {
      throw StateError('WalletClient required for write operations');
    }

    final function = _getFunction(functionName);
    final callData = AbiEncoder.encodeFunction(function.signature, args);

    final request = TransactionRequest(
      to: address,
      data: callData,
      value: value,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );

    return walletClient!.sendTransaction(request);
  }

  /// Simulates a contract function call.
  Future<SimulateResult> simulate(
    String functionName,
    List<dynamic> args, {
    String? from,
    BigInt? value,
    String block = 'latest',
  }) async {
    final function = _getFunction(functionName);
    final callData = AbiEncoder.encodeFunction(function.signature, args);

    final request = CallRequest(
      from: from,
      to: address,
      data: callData,
      value: value,
    );

    try {
      final result = await publicClient.call(request, block);
      final decoded = AbiDecoder.decodeFunction(function.outputs, result);

      // Estimate gas for the call
      final gasUsed = await publicClient.estimateGas(request);

      return SimulateResult(
        result: decoded,
        gasUsed: gasUsed,
        success: true,
      );
    } on Exception catch (e) {
      // Try to decode error message
      String? revertReason;
      if (e.toString().contains('execution reverted')) {
        // Extract revert data if available
        // This is a simplified implementation
        revertReason = e.toString();
      }

      return SimulateResult(
        result: [],
        gasUsed: BigInt.zero,
        success: false,
        revertReason: revertReason,
      );
    }
  }

  /// Estimates gas for a contract function call.
  Future<BigInt> estimateGas(
    String functionName,
    List<dynamic> args, {
    String? from,
    BigInt? value,
  }) async {
    final function = _getFunction(functionName);
    final callData = AbiEncoder.encodeFunction(function.signature, args);

    final request = CallRequest(
      from: from,
      to: address,
      data: callData,
      value: value,
    );

    return publicClient.estimateGas(request);
  }

  /// Creates an event filter for the specified event.
  EventFilter createEventFilter(
    String eventName, {
    Map<String, dynamic>? indexedArgs,
    String? fromBlock,
    String? toBlock,
  }) {
    final event = _getEvent(eventName);

    // Build topics array
    final topics = <String?>[];

    // Topic 0 is always the event signature hash
    final eventTopic =
        HexUtils.encode(AbiEncoder.getEventTopic(event.signature));
    topics.add(eventTopic);

    // Add indexed parameter topics
    if (indexedArgs != null) {
      for (var i = 0; i < event.inputs.length; i++) {
        if (event.indexed[i]) {
          final paramName = event.inputNames[i];
          if (indexedArgs.containsKey(paramName)) {
            final value = indexedArgs[paramName];
            final encodedValue = _encodeIndexedValue(event.inputs[i], value);
            topics.add(HexUtils.encode(encodedValue));
          } else {
            topics.add(null); // Any value for this topic
          }
        }
      }
    }

    return EventFilter(
      address: address,
      topics: topics,
      fromBlock: fromBlock,
      toBlock: toBlock,
      event: event,
    );
  }

  /// Decodes an event log.
  Map<String, dynamic>? decodeEventLog(Log log) {
    if (log.address.toLowerCase() != address.toLowerCase()) {
      return null; // Not from this contract
    }

    if (log.topics.isEmpty) {
      return null; // No event signature
    }

    final eventTopic = log.topics[0];

    // Find matching event
    for (final event in events) {
      final expectedTopic =
          HexUtils.encode(AbiEncoder.getEventTopic(event.signature));
      if (eventTopic.toLowerCase() == expectedTopic.toLowerCase()) {
        return AbiDecoder.decodeEvent(
          types: event.inputs,
          indexed: event.indexed,
          names: event.inputNames,
          topics: log.topics,
          data: log.data,
        );
      }
    }

    return null; // Unknown event
  }

  /// Decodes an error from revert data.
  String? decodeError(Uint8List data) {
    // First try standard Error(string) and Panic(uint256)
    final standardError = AbiDecoder.decodeError(data);
    if (standardError != null) {
      return standardError;
    }

    // Try custom errors
    if (data.length >= 4) {
      final selector = data.sublist(0, 4);

      for (final error in errors) {
        final expectedSelector =
            AbiEncoder.getFunctionSelector(error.signature);
        if (_bytesEqual(selector, expectedSelector)) {
          try {
            final decoded = AbiDecoder.decode(error.inputs, data.sublist(4));
            final args = decoded.map((v) => v.toString()).join(', ');
            return '${error.name}($args)';
          } on Exception catch (_) {
            return error.name;
          }
        }
      }
    }

    return null;
  }

  AbiFunction _getFunction(String name) {
    final matches = functions.where((f) => f.name == name);
    if (matches.isEmpty) {
      throw ArgumentError('Function $name not found in contract ABI');
    }
    return matches.first;
  }

  AbiEvent _getEvent(String name) {
    final matches = events.where((e) => e.name == name);
    if (matches.isEmpty) {
      throw ArgumentError('Event $name not found in contract ABI');
    }
    return matches.first;
  }

  Uint8List _encodeIndexedValue(AbiType type, dynamic value) {
    if (type.isDynamic) {
      // Dynamic types are hashed when indexed
      final encoded = type.encode(value);
      return Keccak256.hash(encoded);
    } else {
      // Static types are encoded normally but padded to 32 bytes
      final encoded = type.encode(value);
      if (encoded.length < 32) {
        return BytesUtils.pad(encoded, 32);
      }
      return encoded;
    }
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
