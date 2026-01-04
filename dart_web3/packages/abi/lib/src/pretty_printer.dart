import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';

import 'types.dart';

/// Pretty printer for ABI-encoded data.
///
/// Formats ABI data into human-readable representation.
class AbiPrettyPrinter {
  AbiPrettyPrinter._();

  /// Formats ABI-encoded data according to the given types.
  ///
  /// Returns a human-readable string representation.
  static String format(List<AbiType> types, List<dynamic> values,
      {int indent = 0}) {
    if (types.length != values.length) {
      throw ArgumentError('Types and values length mismatch');
    }

    final buffer = StringBuffer();
    final indentStr = '  ' * indent;

    for (var i = 0; i < types.length; i++) {
      if (i > 0) buffer.writeln();
      buffer.write('$indentStr[${types[i].name}] ');
      buffer.write(_formatValue(types[i], values[i], indent));
    }

    return buffer.toString();
  }

  /// Formats a single value according to its type.
  static String formatValue(AbiType type, dynamic value) {
    return _formatValue(type, value, 0);
  }

  /// Formats raw bytes as hex with optional type annotation.
  static String formatBytes(Uint8List data, {String? typeName}) {
    final hex = HexUtils.encode(data);
    if (typeName != null) {
      return '[$typeName] $hex';
    }
    return hex;
  }

  /// Formats function call data with selector and arguments.
  static String formatFunctionCall(
    String functionName,
    Uint8List selector,
    List<AbiType> inputTypes,
    List<dynamic> inputValues,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Function: $functionName');
    buffer.writeln('Selector: ${HexUtils.encode(selector)}');

    if (inputTypes.isNotEmpty) {
      buffer.writeln('Arguments:');
      buffer.write(format(inputTypes, inputValues, indent: 1));
    }

    return buffer.toString();
  }

  /// Formats event log data.
  static String formatEventLog(
    String eventName,
    List<AbiType> types,
    List<String> names,
    Map<String, dynamic> decodedValues,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Event: $eventName');
    buffer.writeln('Parameters:');

    for (var i = 0; i < types.length; i++) {
      final name = i < names.length ? names[i] : 'arg$i';
      final value = decodedValues[name];
      buffer.writeln(
          '  $name [${types[i].name}]: ${_formatValue(types[i], value, 1)}');
    }

    return buffer.toString();
  }

  static String _formatValue(AbiType type, dynamic value, int indent) {
    if (value == null) return 'null';

    if (type is AbiUint || type is AbiInt) {
      return _formatBigInt(value);
    }

    if (type is AbiAddress) {
      return value.toString();
    }

    if (type is AbiBool) {
      return value.toString();
    }

    if (type is AbiFixedBytes) {
      return HexUtils.encode(value as Uint8List);
    }

    if (type is AbiBytes) {
      final bytes = value as Uint8List;
      if (bytes.length <= 32) {
        return HexUtils.encode(bytes);
      }
      return '${HexUtils.encode(bytes.sublist(0, 32))}... (${bytes.length} bytes)';
    }

    if (type is AbiString) {
      final str = value as String;
      if (str.length <= 64) {
        return '"$str"';
      }
      return '"${str.substring(0, 64)}..." (${str.length} chars)';
    }

    if (type is AbiArray) {
      return _formatArray(type, value as List, indent);
    }

    if (type is AbiTuple) {
      return _formatTuple(type, value, indent);
    }

    return value.toString();
  }

  static String _formatBigInt(dynamic value) {
    final bigValue = value is BigInt ? value : BigInt.from(value as int);

    // Show both decimal and hex for large numbers
    if (bigValue > BigInt.from(1000000)) {
      return '$bigValue (${HexUtils.encode(BytesUtils.bigIntToBytes(bigValue))})';
    }

    return bigValue.toString();
  }

  static String _formatArray(AbiArray type, List<dynamic> values, int indent) {
    if (values.isEmpty) return '[]';

    if (values.length <= 3 && !type.elementType.isDynamic) {
      // Compact format for small arrays
      final items = values
          .map((v) => _formatValue(type.elementType, v, indent))
          .join(', ');
      return '[$items]';
    }

    // Multi-line format for larger arrays
    final buffer = StringBuffer();
    buffer.writeln('[');
    final indentStr = '  ' * (indent + 1);

    for (var i = 0; i < values.length; i++) {
      buffer.write(
          '$indentStr[$i] ${_formatValue(type.elementType, values[i], indent + 1)}');
      if (i < values.length - 1) buffer.writeln(',');
    }

    buffer.write('\n${'  ' * indent}]');
    return buffer.toString();
  }

  static String _formatTuple(AbiTuple type, dynamic value, int indent) {
    final values = value is Map ? value.values.toList() : value as List;

    if (type.components.length <= 2) {
      // Compact format for small tuples
      final items = <String>[];
      for (var i = 0; i < type.components.length; i++) {
        final name = type.names != null && i < type.names!.length
            ? type.names![i]
            : null;
        final formatted = _formatValue(type.components[i], values[i], indent);
        items.add(name != null ? '$name: $formatted' : formatted);
      }
      return '(${items.join(', ')})';
    }

    // Multi-line format for larger tuples
    final buffer = StringBuffer();
    buffer.writeln('(');
    final indentStr = '  ' * (indent + 1);

    for (var i = 0; i < type.components.length; i++) {
      final name = type.names != null && i < type.names!.length
          ? type.names![i]
          : 'field$i';
      buffer.write(
          '$indentStr$name: ${_formatValue(type.components[i], values[i], indent + 1)}');
      if (i < type.components.length - 1) buffer.writeln(',');
    }

    buffer.write('\n${'  ' * indent})');
    return buffer.toString();
  }
}
