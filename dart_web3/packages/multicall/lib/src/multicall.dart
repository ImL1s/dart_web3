import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

/// Represents a single call in a multicall batch.
class Call {
  const Call({
    required this.target,
    required this.callData,
    this.allowFailure = false,
  });

  /// The target contract address.
  final String target;

  /// The encoded call data.
  final Uint8List callData;

  /// Whether this call is allowed to fail.
  final bool allowFailure;
}

/// Result of a single call in a multicall batch.
class CallResult {
  const CallResult({
    required this.success,
    required this.returnData,
  });

  /// Whether the call succeeded.
  final bool success;

  /// The return data from the call.
  final Uint8List returnData;
}

/// Multicall contract interface for batching multiple contract calls.
class Multicall {
  Multicall({
    required PublicClient publicClient,
    required String contractAddress,
    MulticallVersion version = MulticallVersion.v3,
  })  : _publicClient = publicClient,
        _contractAddress = contractAddress,
        _version = version;
  final PublicClient _publicClient;
  final String _contractAddress;
  final MulticallVersion _version;

  /// Gets the public client for testing purposes.
  @visibleForTesting
  PublicClient get publicClient => _publicClient;

  /// Executes multiple calls in a single transaction (read-only).
  Future<List<CallResult>> aggregate(List<Call> calls) async {
    final callData = _encodeAggregate(calls);

    final result = await _publicClient.call(
      CallRequest(
        to: _contractAddress,
        data: callData,
      ),
    );

    return _decodeAggregateResult(result, calls.length);
  }

  /// Executes multiple calls with failure handling (read-only).
  Future<List<CallResult>> tryAggregate(List<Call> calls,
      {bool requireSuccess = false}) async {
    if (_version == MulticallVersion.v1) {
      throw UnsupportedError('tryAggregate is not supported in Multicall v1');
    }

    final callData = _encodeTryAggregate(calls, requireSuccess);

    final result = await _publicClient.call(
      CallRequest(
        to: _contractAddress,
        data: callData,
      ),
    );

    return _decodeTryAggregateResult(result);
  }

  /// Executes multiple calls and returns block information (read-only).
  Future<MulticallBlockResult> aggregateWithBlock(List<Call> calls) async {
    if (_version != MulticallVersion.v3) {
      throw UnsupportedError(
          'aggregateWithBlock is only supported in Multicall v3');
    }

    final callData = _encodeAggregateWithBlock(calls);

    final result = await _publicClient.call(
      CallRequest(
        to: _contractAddress,
        data: callData,
      ),
    );

    return _decodeAggregateWithBlockResult(result, calls.length);
  }

  /// Estimates gas for multiple calls.
  Future<BigInt> estimateGas(List<Call> calls) async {
    final callData = _encodeAggregate(calls);

    return _publicClient.estimateGas(
      CallRequest(
        to: _contractAddress,
        data: callData,
      ),
    );
  }

  /// Encodes aggregate call data for Multicall v1/v2.
  Uint8List _encodeAggregate(List<Call> calls) {
    // Function selector for aggregate(Call[] calls)
    final selector = HexUtils.decode('0x252dba42');

    // Encode calls array
    final encodedCalls = <Uint8List>[];
    for (final call in calls) {
      // Encode (address target, bytes callData)
      final targetBytes = HexUtils.decode(call.target);
      final paddedTarget = BytesUtils.pad(targetBytes, 32);

      // Encode callData as dynamic bytes
      final callDataLength = BytesUtils.pad(
        _bigIntToBytes(BigInt.from(call.callData.length)),
        32,
      );
      final paddedCallData = BytesUtils.pad(
        call.callData,
        ((call.callData.length + 31) ~/ 32) * 32,
        left: false,
      );

      encodedCalls.add(
        BytesUtils.concat([
          paddedTarget,
          callDataLength,
          paddedCallData,
        ]),
      );
    }

    // Encode array length and data
    final arrayLength = BytesUtils.pad(
      _bigIntToBytes(BigInt.from(calls.length)),
      32,
    );
    final arrayData = BytesUtils.concat(encodedCalls);

    return BytesUtils.concat([
      selector,
      arrayLength,
      arrayData,
    ]);
  }

  /// Encodes tryAggregate call data for Multicall v2/v3.
  Uint8List _encodeTryAggregate(List<Call> calls, bool requireSuccess) {
    // Function selector for tryAggregate(bool requireSuccess, Call[] calls)
    final selector = HexUtils.decode('0xbce38bd7');

    // Encode requireSuccess
    final requireSuccessBytes = BytesUtils.pad(
      Uint8List.fromList(requireSuccess ? [1] : [0]),
      32,
    );

    // Encode calls (same as aggregate but with allowFailure flag)
    final encodedCalls = <Uint8List>[];
    for (final call in calls) {
      final targetBytes = HexUtils.decode(call.target);
      final paddedTarget = BytesUtils.pad(targetBytes, 32);

      final callDataLength = BytesUtils.pad(
        _bigIntToBytes(BigInt.from(call.callData.length)),
        32,
      );
      final paddedCallData = BytesUtils.pad(
        call.callData,
        ((call.callData.length + 31) ~/ 32) * 32,
        left: false,
      );

      encodedCalls.add(
        BytesUtils.concat([
          paddedTarget,
          callDataLength,
          paddedCallData,
        ]),
      );
    }

    final arrayLength = BytesUtils.pad(
      _bigIntToBytes(BigInt.from(calls.length)),
      32,
    );
    final arrayData = BytesUtils.concat(encodedCalls);

    return BytesUtils.concat([
      selector,
      requireSuccessBytes,
      arrayLength,
      arrayData,
    ]);
  }

  /// Encodes aggregateWithBlock call data for Multicall v3.
  Uint8List _encodeAggregateWithBlock(List<Call> calls) {
    // Function selector for aggregate3(Call3[] calls)
    final selector = HexUtils.decode('0x82ad56cb');

    // Encode Call3 array (target, allowFailure, callData)
    final encodedCalls = <Uint8List>[];
    for (final call in calls) {
      final targetBytes = HexUtils.decode(call.target);
      final paddedTarget = BytesUtils.pad(targetBytes, 32);

      final allowFailureBytes = BytesUtils.pad(
        Uint8List.fromList(call.allowFailure ? [1] : [0]),
        32,
      );

      final callDataLength = BytesUtils.pad(
        _bigIntToBytes(BigInt.from(call.callData.length)),
        32,
      );
      final paddedCallData = BytesUtils.pad(
        call.callData,
        ((call.callData.length + 31) ~/ 32) * 32,
        left: false,
      );

      encodedCalls.add(
        BytesUtils.concat([
          paddedTarget,
          allowFailureBytes,
          callDataLength,
          paddedCallData,
        ]),
      );
    }

    final arrayLength = BytesUtils.pad(
      _bigIntToBytes(BigInt.from(calls.length)),
      32,
    );
    final arrayData = BytesUtils.concat(encodedCalls);

    return BytesUtils.concat([
      selector,
      arrayLength,
      arrayData,
    ]);
  }

  /// Decodes aggregate result.
  List<CallResult> _decodeAggregateResult(Uint8List data, int callCount) {
    // Skip function selector and decode array
    var offset = 0;

    // Read array length
    final arrayLength = _bytesToBigInt(data.sublist(offset, offset + 32));
    offset += 32;

    final results = <CallResult>[];
    for (var i = 0; i < arrayLength.toInt(); i++) {
      // Read return data length
      final dataLength = _bytesToBigInt(data.sublist(offset, offset + 32));
      offset += 32;

      // Read return data
      final returnData = data.sublist(offset, offset + dataLength.toInt());
      offset += ((dataLength.toInt() + 31) ~/ 32) * 32; // Padded length

      results.add(
        CallResult(
          success: true, // aggregate always succeeds or reverts
          returnData: returnData,
        ),
      );
    }

    return results;
  }

  /// Decodes tryAggregate result.
  List<CallResult> _decodeTryAggregateResult(Uint8List data) {
    var offset = 0;

    // Read array length
    final arrayLength = _bytesToBigInt(data.sublist(offset, offset + 32));
    offset += 32;

    final results = <CallResult>[];
    for (var i = 0; i < arrayLength.toInt(); i++) {
      // Read success flag
      final success = data[offset + 31] == 1;
      offset += 32;

      // Read return data length
      final dataLength = _bytesToBigInt(data.sublist(offset, offset + 32));
      offset += 32;

      // Read return data
      final returnData = data.sublist(offset, offset + dataLength.toInt());
      offset += ((dataLength.toInt() + 31) ~/ 32) * 32;

      results.add(
        CallResult(
          success: success,
          returnData: returnData,
        ),
      );
    }

    return results;
  }

  /// Decodes aggregateWithBlock result.
  MulticallBlockResult _decodeAggregateWithBlockResult(
      Uint8List data, int callCount) {
    var offset = 0;

    // Read block number
    final blockNumber = _bytesToBigInt(data.sublist(offset, offset + 32));
    offset += 32;

    // Read block hash
    final blockHash = HexUtils.encode(data.sublist(offset, offset + 32));
    offset += 32;

    // Read results array
    final arrayLength = _bytesToBigInt(data.sublist(offset, offset + 32));
    offset += 32;

    final results = <CallResult>[];
    for (var i = 0; i < arrayLength.toInt(); i++) {
      final success = data[offset + 31] == 1;
      offset += 32;

      final dataLength = _bytesToBigInt(data.sublist(offset, offset + 32));
      offset += 32;

      final returnData = data.sublist(offset, offset + dataLength.toInt());
      offset += ((dataLength.toInt() + 31) ~/ 32) * 32;

      results.add(
        CallResult(
          success: success,
          returnData: returnData,
        ),
      );
    }

    return MulticallBlockResult(
      blockNumber: blockNumber,
      blockHash: blockHash,
      results: results,
    );
  }

  /// Converts BigInt to bytes.
  Uint8List _bigIntToBytes(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    return HexUtils.decode('0x$hex');
  }

  /// Converts bytes to BigInt.
  BigInt _bytesToBigInt(Uint8List bytes) {
    final hex = HexUtils.encode(bytes);
    return BigInt.parse(hex.substring(2), radix: 16);
  }
}

/// Multicall version enum.
enum MulticallVersion {
  v1,
  v2,
  v3,
}

/// Result of aggregateWithBlock call.
class MulticallBlockResult {
  const MulticallBlockResult({
    required this.blockNumber,
    required this.blockHash,
    required this.results,
  });

  /// The block number when the call was executed.
  final BigInt blockNumber;

  /// The block hash when the call was executed.
  final String blockHash;

  /// The results of individual calls.
  final List<CallResult> results;
}
