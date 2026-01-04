import 'dart:convert';
import 'dart:typed_data';

/// Base class for all ABI types.
abstract class AbiType {
  /// The Solidity type name (e.g., "uint256", "address").
  String get name;

  /// Whether this type is dynamic (variable length).
  bool get isDynamic;

  /// Encodes a value of this type.
  Uint8List encode(dynamic value);

  /// Decodes a value of this type from data at the given offset.
  /// Returns the decoded value and the number of bytes consumed.
  (dynamic, int) decode(Uint8List data, int offset);

  /// Returns the static size in bytes for encoding.
  /// For dynamic types, this returns 32 (the offset pointer size).
  /// For static types, this returns the actual encoded size.
  int getStaticSize() => 32;
}

/// Unsigned integer type (uint8 to uint256).
class AbiUint extends AbiType {
  AbiUint(this.bits) {
    if (bits <= 0 || bits > 256 || bits % 8 != 0) {
      throw ArgumentError('Invalid uint bits: $bits');
    }
  }
  final int bits;

  @override
  String get name => 'uint$bits';

  @override
  bool get isDynamic => false;

  @override
  Uint8List encode(dynamic value) {
    BigInt bigValue;
    if (value is BigInt) {
      bigValue = value;
    } else if (value is int) {
      bigValue = BigInt.from(value);
    } else if (value is String) {
      final v = value.toLowerCase();
      if (v.startsWith('0x')) {
        bigValue = BigInt.parse(v.substring(2), radix: 16);
      } else {
        bigValue = BigInt.parse(v);
      }
    } else {
      throw ArgumentError('Unsupported type for uint: ${value.runtimeType}');
    }
    final result = Uint8List(32);

    // Big-endian encoding, right-aligned
    var v = bigValue;
    for (var i = 31; i >= 0 && v > BigInt.zero; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    var result = BigInt.zero;
    for (var i = 0; i < 32; i++) {
      result = (result << 8) | BigInt.from(data[offset + i]);
    }
    return (result, 32);
  }
}

/// Signed integer type (int8 to int256).
class AbiInt extends AbiType {
  AbiInt(this.bits) {
    if (bits <= 0 || bits > 256 || bits % 8 != 0) {
      throw ArgumentError('Invalid int bits: $bits');
    }
  }
  final int bits;

  @override
  String get name => 'int$bits';

  @override
  bool get isDynamic => false;

  @override
  Uint8List encode(dynamic value) {
    BigInt bigValue;
    if (value is BigInt) {
      bigValue = value;
    } else if (value is int) {
      bigValue = BigInt.from(value);
    } else if (value is String) {
      final v = value.toLowerCase();
      if (v.startsWith('0x')) {
        bigValue = BigInt.parse(v.substring(2), radix: 16);
      } else {
        bigValue = BigInt.parse(v);
      }
    } else {
      throw ArgumentError('Unsupported type for int: ${value.runtimeType}');
    }

    // Two's complement for negative values
    var v = bigValue;
    if (v.isNegative) {
      v = (BigInt.one << 256) + v;
    }

    final result = Uint8List(32);
    for (var i = 31; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    var result = BigInt.zero;
    for (var i = 0; i < 32; i++) {
      result = (result << 8) | BigInt.from(data[offset + i]);
    }

    // Handle negative (two's complement)
    if (data[offset] >= 0x80) {
      result = result - (BigInt.one << 256);
    }

    return (result, 32);
  }
}

/// Address type (20 bytes).
class AbiAddress extends AbiType {
  @override
  String get name => 'address';

  @override
  bool get isDynamic => false;

  @override
  Uint8List encode(dynamic value) {
    final result = Uint8List(32);
    final address = value.toString().toLowerCase();
    final hex = address.startsWith('0x') ? address.substring(2) : address;

    // Right-align 20 bytes in 32-byte slot
    for (var i = 0; i < 20; i++) {
      result[12 + i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    final addressBytes = data.sublist(offset + 12, offset + 32);
    final hex =
        addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return ('0x$hex', 32);
  }
}

/// Boolean type.
class AbiBool extends AbiType {
  @override
  String get name => 'bool';

  @override
  bool get isDynamic => false;

  @override
  Uint8List encode(dynamic value) {
    final result = Uint8List(32);
    result[31] = (value as bool) ? 1 : 0;
    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    return (data[offset + 31] != 0, 32);
  }
}

/// Fixed-size bytes type (bytes1 to bytes32).
class AbiFixedBytes extends AbiType {
  AbiFixedBytes(this.length) {
    if (length <= 0 || length > 32) {
      throw ArgumentError('Invalid bytes length: $length');
    }
  }
  final int length;

  @override
  String get name => 'bytes$length';

  @override
  bool get isDynamic => false;

  @override
  Uint8List encode(dynamic value) {
    Uint8List bytes;
    if (value is Uint8List) {
      bytes = value;
    } else if (value is String) {
      final hex = value.startsWith('0x') || value.startsWith('0X')
          ? value.substring(2)
          : value;
      if (hex.length != length * 2) {
        throw ArgumentError(
            'Expected $length bytes ($name), got ${hex.length ~/ 2}');
      }
      bytes = Uint8List(length);
      for (var i = 0; i < length; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
    } else {
      throw ArgumentError('Unsupported type for $name: ${value.runtimeType}');
    }

    if (bytes.length != length) {
      throw ArgumentError('Expected $length bytes, got ${bytes.length}');
    }

    final result = Uint8List(32);
    result.setRange(0, length, bytes);
    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    return (Uint8List.fromList(data.sublist(offset, offset + length)), 32);
  }
}

/// Dynamic bytes type.
class AbiBytes extends AbiType {
  @override
  String get name => 'bytes';

  @override
  bool get isDynamic => true;

  @override
  Uint8List encode(dynamic value) {
    final bytes = value as Uint8List;
    final length = bytes.length;
    final paddedLength = ((length + 31) ~/ 32) * 32;

    final result = Uint8List(32 + paddedLength);

    // Encode length
    final lengthType = AbiUint(256);
    result.setRange(0, 32, lengthType.encode(length));

    // Encode data
    result.setRange(32, 32 + length, bytes);

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    final lengthType = AbiUint(256);
    final (length, _) = lengthType.decode(data, offset);
    final len = (length as BigInt).toInt();
    final paddedLength = ((len + 31) ~/ 32) * 32;

    return (
      Uint8List.fromList(data.sublist(offset + 32, offset + 32 + len)),
      32 + paddedLength
    );
  }
}

/// String type (UTF-8 encoded per Solidity ABI specification).
class AbiString extends AbiType {
  @override
  String get name => 'string';

  @override
  bool get isDynamic => true;

  @override
  Uint8List encode(dynamic value) {
    final str = value as String;
    // Solidity ABI specification requires UTF-8 encoding for strings
    final bytes = Uint8List.fromList(utf8.encode(str));
    return AbiBytes().encode(bytes);
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    final (bytes, consumed) = AbiBytes().decode(data, offset);
    // Decode UTF-8 bytes back to string
    return (utf8.decode(bytes as Uint8List), consumed);
  }
}

/// Array type (fixed or dynamic length).
class AbiArray extends AbiType {
  // null for dynamic arrays

  AbiArray(this.elementType, [this.length]);
  final AbiType elementType;
  final int? length;

  @override
  String get name =>
      length != null ? '${elementType.name}[$length]' : '${elementType.name}[]';

  @override
  bool get isDynamic => length == null || elementType.isDynamic;

  @override
  int getStaticSize() {
    // Dynamic arrays are encoded as offset pointer (32 bytes)
    if (isDynamic) return 32;
    // Fixed-size arrays with static elements: length * element size
    return length! * elementType.getStaticSize();
  }

  @override
  Uint8List encode(dynamic value) {
    final list = value as List;

    if (length != null && list.length != length) {
      throw ArgumentError('Expected $length elements, got ${list.length}');
    }

    final parts = <Uint8List>[];

    // For dynamic arrays, prepend length
    if (length == null) {
      parts.add(AbiUint(256).encode(list.length));
    }

    if (elementType.isDynamic) {
      // Dynamic elements: encode offsets then data
      // Each offset pointer is 32 bytes, regardless of element size
      final offsets = <int>[];
      final encodedElements = <Uint8List>[];

      var currentOffset =
          list.length * 32; // Offset pointers are always 32 bytes
      for (final element in list) {
        offsets.add(currentOffset);
        final encoded = elementType.encode(element);
        encodedElements.add(encoded);
        currentOffset += encoded.length;
      }

      for (final offset in offsets) {
        parts.add(AbiUint(256).encode(offset));
      }
      parts.addAll(encodedElements);
    } else {
      // Static elements: encode directly (each element uses its full static size)
      for (final element in list) {
        parts.add(elementType.encode(element));
      }
    }

    // Concatenate all parts
    final totalLength = parts.fold<int>(0, (sum, p) => sum + p.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    var currentOffset = offset;
    int arrayLength;

    if (length == null) {
      final (len, _) = AbiUint(256).decode(data, currentOffset);
      arrayLength = (len as BigInt).toInt();
      currentOffset += 32;
    } else {
      arrayLength = length!;
    }

    final result = <dynamic>[];

    if (elementType.isDynamic) {
      // Read offsets first
      final offsets = <int>[];
      for (var i = 0; i < arrayLength; i++) {
        final (off, _) = AbiUint(256).decode(data, currentOffset + i * 32);
        offsets.add((off as BigInt).toInt());
      }

      // Decode elements at offsets
      for (final off in offsets) {
        final (element, _) = elementType.decode(data, currentOffset + off);
        result.add(element);
      }
    } else {
      for (var i = 0; i < arrayLength; i++) {
        final (element, consumed) = elementType.decode(data, currentOffset);
        result.add(element);
        currentOffset += consumed;
      }
    }

    return (result, currentOffset - offset);
  }
}

/// Tuple type (struct).
class AbiTuple extends AbiType {
  AbiTuple(this.components, [this.names]);
  final List<AbiType> components;
  final List<String>? names;

  @override
  String get name {
    final componentNames = components.map((c) => c.name).join(',');
    return '($componentNames)';
  }

  @override
  bool get isDynamic => components.any((c) => c.isDynamic);

  @override
  int getStaticSize() {
    // Dynamic tuples are encoded as offset pointer (32 bytes)
    if (isDynamic) return 32;
    // Static tuples: sum of all component sizes
    return components.fold(0, (sum, c) => sum + c.getStaticSize());
  }

  @override
  Uint8List encode(dynamic value) {
    final values = value is Map ? value.values.toList() : value as List;

    if (values.length != components.length) {
      throw ArgumentError(
          'Expected ${components.length} values, got ${values.length}');
    }

    // Similar to array encoding
    final parts = <Uint8List>[];

    if (isDynamic) {
      final offsets = <int?>[];
      final encodedElements = <Uint8List>[];

      // Calculate head size: sum of static sizes for each component
      // Dynamic components use 32 bytes for offset pointer
      // Static components use their actual static size
      var headSize = 0;
      for (final component in components) {
        if (component.isDynamic) {
          headSize += 32; // Offset pointer
        } else {
          headSize += component.getStaticSize();
        }
      }

      var currentOffset = headSize;
      for (var i = 0; i < components.length; i++) {
        if (components[i].isDynamic) {
          offsets.add(currentOffset);
          final encoded = components[i].encode(values[i]);
          encodedElements.add(encoded);
          currentOffset += encoded.length;
        } else {
          offsets.add(null);
          encodedElements.add(components[i].encode(values[i]));
        }
      }

      for (var i = 0; i < components.length; i++) {
        if (offsets[i] != null) {
          parts.add(AbiUint(256).encode(offsets[i]));
        } else {
          parts.add(encodedElements[i]);
        }
      }

      for (var i = 0; i < components.length; i++) {
        if (offsets[i] != null) {
          parts.add(encodedElements[i]);
        }
      }
    } else {
      for (var i = 0; i < components.length; i++) {
        parts.add(components[i].encode(values[i]));
      }
    }

    final totalLength = parts.fold<int>(0, (sum, p) => sum + p.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }

    return result;
  }

  @override
  (dynamic, int) decode(Uint8List data, int offset) {
    final result = <dynamic>[];
    var currentOffset = offset;

    for (final component in components) {
      if (component.isDynamic) {
        final (off, _) = AbiUint(256).decode(data, currentOffset);
        final (value, _) =
            component.decode(data, offset + (off as BigInt).toInt());
        result.add(value);
        currentOffset += 32;
      } else {
        final (value, consumed) = component.decode(data, currentOffset);
        result.add(value);
        currentOffset += consumed;
      }
    }

    return (result, currentOffset - offset);
  }
}
