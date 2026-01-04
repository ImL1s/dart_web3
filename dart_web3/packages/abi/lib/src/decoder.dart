import 'dart:typed_data';

import 'types.dart';

/// ABI decoder for Ethereum smart contract return values and events.
class AbiDecoder {
  AbiDecoder._();

  /// Decodes data according to the given types.
  static List<dynamic> decode(List<AbiType> types, Uint8List data) {
    final tuple = AbiTuple(types);
    final (result, _) = tuple.decode(data, 0);
    return result as List<dynamic>;
  }

  /// Decodes function return data.
  static List<dynamic> decodeFunction(
      List<AbiType> outputTypes, Uint8List data) {
    return decode(outputTypes, data);
  }

  /// Decodes event log data.
  ///
  /// [topics] contains the indexed parameters (topic[0] is the event signature).
  /// [data] contains the non-indexed parameters.
  static Map<String, dynamic> decodeEvent({
    required List<AbiType> types,
    required List<bool> indexed,
    required List<String>? names,
    required List<String> topics,
    required Uint8List data,
  }) {
    final result = <String, dynamic>{};

    var topicIndex = 1; // Skip topic[0] (event signature)

    final nonIndexedTypes = <AbiType>[];
    final nonIndexedIndices = <int>[];

    for (var i = 0; i < types.length; i++) {
      if (indexed[i]) {
        // Indexed parameters are in topics
        if (topicIndex < topics.length) {
          final topic = topics[topicIndex];
          final topicBytes = _hexToBytes(topic);

          dynamic value;
          if (types[i].isDynamic) {
            // Dynamic types are hashed, return the hash
            value = topic;
          } else {
            final (decoded, _) = types[i].decode(topicBytes, 0);
            value = decoded;
          }

          final name = names != null && i < names.length ? names[i] : 'arg$i';
          result[name] = value;
          topicIndex++;
        }
      } else {
        nonIndexedTypes.add(types[i]);
        nonIndexedIndices.add(i);
      }
    }

    // Decode non-indexed parameters from data
    if (nonIndexedTypes.isNotEmpty && data.isNotEmpty) {
      final decoded = decode(nonIndexedTypes, data);
      for (var i = 0; i < decoded.length; i++) {
        final originalIndex = nonIndexedIndices[i];
        final name = names != null && originalIndex < names.length
            ? names[originalIndex]
            : 'arg$originalIndex';
        result[name] = decoded[i];
      }
    }

    return result;
  }

  /// Decodes an error message from revert data.
  static String? decodeError(Uint8List data) {
    if (data.length < 4) return null;

    // Check for Error(string) selector: 0x08c379a0
    if (data[0] == 0x08 &&
        data[1] == 0xc3 &&
        data[2] == 0x79 &&
        data[3] == 0xa0) {
      try {
        final decoded = decode([AbiString()], data.sublist(4));
        return decoded[0] as String;
      } on Object catch (_) {
        return null;
      }
    }

    // Check for Panic(uint256) selector: 0x4e487b71
    if (data[0] == 0x4e &&
        data[1] == 0x48 &&
        data[2] == 0x7b &&
        data[3] == 0x71) {
      try {
        final decoded = decode([AbiUint(256)], data.sublist(4));
        final code = (decoded[0] as BigInt).toInt();
        return _panicMessage(code);
      } on Object catch (_) {
        return null;
      }
    }

    return null;
  }

  static Uint8List _hexToBytes(String hex) {
    var data = hex;
    if (data.startsWith('0x')) {
      data = data.substring(2);
    }
    if (data.length.isOdd) {
      data = '0$data';
    }

    final result = Uint8List(data.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(data.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _panicMessage(int code) {
    switch (code) {
      case 0x00:
        return 'Generic compiler panic';
      case 0x01:
        return 'Assert failed';
      case 0x11:
        return 'Arithmetic overflow/underflow';
      case 0x12:
        return 'Division by zero';
      case 0x21:
        return 'Invalid enum value';
      case 0x22:
        return 'Storage byte array encoding error';
      case 0x31:
        return 'Pop on empty array';
      case 0x32:
        return 'Array index out of bounds';
      case 0x41:
        return 'Memory allocation overflow';
      case 0x51:
        return 'Zero-initialized function pointer';
      default:
        return 'Panic($code)';
    }
  }
}
