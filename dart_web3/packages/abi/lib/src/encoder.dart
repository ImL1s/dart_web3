import 'dart:convert';
import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import 'types.dart';

/// ABI encoder for Ethereum smart contract calls.
class AbiEncoder {
  AbiEncoder._();

  /// Encodes values according to the given types.
  static Uint8List encode(List<AbiType> types, List<dynamic> values) {
    if (types.length != values.length) {
      throw ArgumentError('Types and values length mismatch');
    }

    final tuple = AbiTuple(types);
    return tuple.encode(values);
  }

  /// Encodes values in packed format (no padding).
  static Uint8List encodePacked(List<AbiType> types, List<dynamic> values) {
    if (types.length != values.length) {
      throw ArgumentError('Types and values length mismatch');
    }

    final parts = <Uint8List>[];
    for (var i = 0; i < types.length; i++) {
      parts.add(_encodePacked(types[i], values[i]));
    }

    return BytesUtils.concat(parts);
  }

  /// Encodes a function call with selector and arguments.
  static Uint8List encodeFunction(String signature, List<dynamic> args) {
    final selector = getFunctionSelector(signature);
    final types = _parseSignatureTypes(signature);

    if (args.isEmpty) {
      return selector;
    }

    final encodedArgs = encode(types, args);
    return BytesUtils.concat([selector, encodedArgs]);
  }

  /// Gets the 4-byte function selector from a signature.
  /// Per Solidity ABI specification, the signature is UTF-8 encoded before hashing.
  static Uint8List getFunctionSelector(String signature) {
    final hash = Keccak256.hash(Uint8List.fromList(utf8.encode(signature)));
    return BytesUtils.slice(hash, 0, 4);
  }

  /// Gets the 32-byte event topic from a signature.
  /// Per Solidity ABI specification, the signature is UTF-8 encoded before hashing.
  static Uint8List getEventTopic(String signature) {
    return Keccak256.hash(Uint8List.fromList(utf8.encode(signature)));
  }

  static Uint8List _encodePacked(AbiType type, dynamic value) {
    if (type is AbiUint) {
      final bigValue = value is BigInt ? value : BigInt.from(value as int);
      return BytesUtils.bigIntToBytes(bigValue, length: type.bits ~/ 8);
    }
    if (type is AbiInt) {
      final bigValue = value is BigInt ? value : BigInt.from(value as int);
      var v = bigValue;
      if (v.isNegative) {
        v = (BigInt.one << type.bits) + v;
      }
      return BytesUtils.bigIntToBytes(v, length: type.bits ~/ 8);
    }
    if (type is AbiAddress) {
      final address = value.toString().toLowerCase();
      final hex = address.startsWith('0x') ? address.substring(2) : address;
      return HexUtils.decode(hex);
    }
    if (type is AbiBool) {
      return Uint8List.fromList([if (value as bool) 1 else 0]);
    }
    if (type is AbiFixedBytes) {
      return value as Uint8List;
    }
    if (type is AbiBytes) {
      return value as Uint8List;
    }
    if (type is AbiString) {
      // Per Solidity ABI specification, strings are UTF-8 encoded
      return Uint8List.fromList(utf8.encode(value as String));
    }

    throw ArgumentError('Unsupported type for packed encoding: ${type.name}');
  }

  static List<AbiType> _parseSignatureTypes(String signature) {
    // Extract types from signature like "transfer(address,uint256)"
    final start = signature.indexOf('(');
    final end = signature.lastIndexOf(')');

    if (start == -1 || end == -1 || end <= start) {
      return [];
    }

    final typesStr = signature.substring(start + 1, end);
    if (typesStr.isEmpty) {
      return [];
    }

    // Use bracket-aware splitting to handle nested tuples like "(uint256,string)"
    return _splitTypes(typesStr).map(_parseType).toList();
  }

  /// Splits type string by commas, respecting bracket nesting.
  /// Handles nested tuples like "(uint256,string),address,(bool,bytes)"
  static List<String> _splitTypes(String typesStr) {
    final result = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < typesStr.length; i++) {
      final char = typesStr[i];
      if (char == '(' || char == '[') {
        depth++;
      } else if (char == ')' || char == ']') {
        depth--;
      } else if (char == ',' && depth == 0) {
        result.add(typesStr.substring(start, i).trim());
        start = i + 1;
      }
    }

    // Add the last segment
    if (start < typesStr.length) {
      result.add(typesStr.substring(start).trim());
    }

    return result;
  }

  static AbiType _parseType(String typeStr) {
    final type = typeStr.trim();

    if (type == 'address') return AbiAddress();
    if (type == 'bool') return AbiBool();
    if (type == 'string') return AbiString();
    if (type == 'bytes') return AbiBytes();

    if (type.startsWith('uint')) {
      final bits = int.parse(type.substring(4));
      return AbiUint(bits);
    }
    if (type.startsWith('int')) {
      final bits = int.parse(type.substring(3));
      return AbiInt(bits);
    }
    if (type.startsWith('bytes') && !type.contains('[')) {
      final length = int.parse(type.substring(5));
      return AbiFixedBytes(length);
    }

    // Tuple types - handle "(type1,type2,...)"
    if (type.startsWith('(') && type.endsWith(')')) {
      final innerTypes = type.substring(1, type.length - 1);
      if (innerTypes.isEmpty) {
        return AbiTuple([]);
      }
      final components = _splitTypes(innerTypes).map(_parseType).toList();
      return AbiTuple(components);
    }

    // Array types - must check after tuple to handle tuple arrays like "(uint256,string)[]"
    if (type.endsWith('[]')) {
      final elementType = _parseType(type.substring(0, type.length - 2));
      return AbiArray(elementType);
    }
    if (type.contains('[') && type.endsWith(']')) {
      // Find the last '[' that's not inside parentheses
      var depth = 0;
      var bracketStart = -1;
      for (var i = type.length - 1; i >= 0; i--) {
        final char = type[i];
        if (char == ')') {
          depth++;
        } else if (char == '(')
          depth--;
        else if (char == '[' && depth == 0) {
          bracketStart = i;
          break;
        }
      }

      if (bracketStart != -1) {
        final elementType = _parseType(type.substring(0, bracketStart));
        final lengthStr = type.substring(bracketStart + 1, type.length - 1);
        if (lengthStr.isEmpty) {
          return AbiArray(elementType);
        }
        final length = int.parse(lengthStr);
        return AbiArray(elementType, length);
      }
    }

    throw ArgumentError('Unknown type: $type');
  }
}
