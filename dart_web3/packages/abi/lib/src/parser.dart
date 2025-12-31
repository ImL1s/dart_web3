import 'dart:convert';

import 'types.dart';

/// Parser for ABI JSON definitions.
class AbiParser {
  AbiParser._();

  /// Parses functions from an ABI JSON string.
  static List<AbiFunction> parseFunctions(String abiJson) {
    final abi = json.decode(abiJson) as List;
    return abi
        .where((item) => item['type'] == 'function')
        .map((item) => AbiFunction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses events from an ABI JSON string.
  static List<AbiEvent> parseEvents(String abiJson) {
    final abi = json.decode(abiJson) as List;
    return abi
        .where((item) => item['type'] == 'event')
        .map((item) => AbiEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses errors from an ABI JSON string.
  static List<AbiError> parseErrors(String abiJson) {
    final abi = json.decode(abiJson) as List;
    return abi
        .where((item) => item['type'] == 'error')
        .map((item) => AbiError.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses a type string into an AbiType.
  static AbiType parseType(String typeStr) {
    final type = typeStr.trim();

    if (type == 'address') return AbiAddress();
    if (type == 'bool') return AbiBool();
    if (type == 'string') return AbiString();
    if (type == 'bytes') return AbiBytes();

    // Array types - check these BEFORE basic types
    if (type.endsWith('[]')) {
      final elementType = parseType(type.substring(0, type.length - 2));
      return AbiArray(elementType);
    }
    if (type.contains('[') && type.endsWith(']')) {
      final bracketStart = type.lastIndexOf('[');
      final elementType = parseType(type.substring(0, bracketStart));
      final length = int.parse(type.substring(bracketStart + 1, type.length - 1));
      return AbiArray(elementType, length);
    }

    // Basic numeric types
    if (type.startsWith('uint')) {
      final bits = type.length > 4 ? int.parse(type.substring(4)) : 256;
      return AbiUint(bits);
    }
    if (type.startsWith('int')) {
      final bits = type.length > 3 ? int.parse(type.substring(3)) : 256;
      return AbiInt(bits);
    }
    if (type.startsWith('bytes') && !type.contains('[')) {
      final length = int.parse(type.substring(5));
      return AbiFixedBytes(length);
    }

    // Tuple type
    if (type.startsWith('(') && type.endsWith(')')) {
      final inner = type.substring(1, type.length - 1);
      final components = _splitTupleComponents(inner).map(parseType).toList();
      return AbiTuple(components);
    }

    throw ArgumentError('Unknown type: $type');
  }

  static List<String> _splitTupleComponents(String inner) {
    final components = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < inner.length; i++) {
      final char = inner[i];
      if (char == '(' || char == '[') {
        depth++;
      } else if (char == ')' || char == ']') {
        depth--;
      } else if (char == ',' && depth == 0) {
        components.add(inner.substring(start, i).trim());
        start = i + 1;
      }
    }

    if (start < inner.length) {
      components.add(inner.substring(start).trim());
    }

    return components;
  }
}

/// Represents a function in an ABI.
class AbiFunction {
  final String name;
  final List<AbiType> inputs;
  final List<String> inputNames;
  final List<AbiType> outputs;
  final List<String> outputNames;
  final String stateMutability;

  AbiFunction({
    required this.name,
    required this.inputs,
    required this.inputNames,
    required this.outputs,
    required this.outputNames,
    required this.stateMutability,
  });

  factory AbiFunction.fromJson(Map<String, dynamic> json) {
    final inputs = <AbiType>[];
    final inputNames = <String>[];
    final outputs = <AbiType>[];
    final outputNames = <String>[];

    for (final input in (json['inputs'] as List?) ?? []) {
      inputs.add(_parseInput(input as Map<String, dynamic>));
      inputNames.add(input['name'] as String? ?? '');
    }

    for (final output in (json['outputs'] as List?) ?? []) {
      outputs.add(_parseInput(output as Map<String, dynamic>));
      outputNames.add(output['name'] as String? ?? '');
    }

    return AbiFunction(
      name: json['name'] as String,
      inputs: inputs,
      inputNames: inputNames,
      outputs: outputs,
      outputNames: outputNames,
      stateMutability: json['stateMutability'] as String? ?? 'nonpayable',
    );
  }

  /// Gets the function signature (e.g., "transfer(address,uint256)").
  String get signature {
    final inputTypes = inputs.map((i) => i.name).join(',');
    return '$name($inputTypes)';
  }

  /// Gets the 4-byte function selector.
  String get selector {
    // This would use Keccak256 - implemented in encoder
    throw UnimplementedError('Use AbiEncoder.getFunctionSelector');
  }

  /// Whether this function is read-only (view or pure).
  bool get isReadOnly => stateMutability == 'view' || stateMutability == 'pure';

  /// Whether this function is payable.
  bool get isPayable => stateMutability == 'payable';

  static AbiType _parseInput(Map<String, dynamic> input) {
    final type = input['type'] as String;

    // Handle tuple types
    if (type == 'tuple' || type.startsWith('tuple[')) {
      final components = (input['components'] as List?)
              ?.map((c) => _parseInput(c as Map<String, dynamic>))
              .toList() ??
          [];

      if (type == 'tuple') {
        return AbiTuple(components);
      }

      // tuple[]
      if (type == 'tuple[]') {
        return AbiArray(AbiTuple(components));
      }

      // tuple[n]
      final match = RegExp(r'tuple\[(\d+)\]').firstMatch(type);
      if (match != null) {
        final length = int.parse(match.group(1)!);
        return AbiArray(AbiTuple(components), length);
      }
    }

    return AbiParser.parseType(type);
  }
}

/// Represents an event in an ABI.
class AbiEvent {
  final String name;
  final List<AbiType> inputs;
  final List<String> inputNames;
  final List<bool> indexed;
  final bool anonymous;

  AbiEvent({
    required this.name,
    required this.inputs,
    required this.inputNames,
    required this.indexed,
    required this.anonymous,
  });

  factory AbiEvent.fromJson(Map<String, dynamic> json) {
    final inputs = <AbiType>[];
    final inputNames = <String>[];
    final indexed = <bool>[];

    for (final input in (json['inputs'] as List?) ?? []) {
      final inputMap = input as Map<String, dynamic>;
      inputs.add(AbiParser.parseType(inputMap['type'] as String));
      inputNames.add(inputMap['name'] as String? ?? '');
      indexed.add(inputMap['indexed'] as bool? ?? false);
    }

    return AbiEvent(
      name: json['name'] as String,
      inputs: inputs,
      inputNames: inputNames,
      indexed: indexed,
      anonymous: json['anonymous'] as bool? ?? false,
    );
  }

  /// Gets the event signature.
  String get signature {
    final inputTypes = inputs.map((i) => i.name).join(',');
    return '$name($inputTypes)';
  }

  /// Gets the event topic (keccak256 of signature).
  String get topic {
    throw UnimplementedError('Use AbiEncoder.getEventTopic');
  }
}

/// Represents an error in an ABI.
class AbiError {
  final String name;
  final List<AbiType> inputs;
  final List<String> inputNames;

  AbiError({
    required this.name,
    required this.inputs,
    required this.inputNames,
  });

  factory AbiError.fromJson(Map<String, dynamic> json) {
    final inputs = <AbiType>[];
    final inputNames = <String>[];

    for (final input in (json['inputs'] as List?) ?? []) {
      final inputMap = input as Map<String, dynamic>;
      inputs.add(AbiParser.parseType(inputMap['type'] as String));
      inputNames.add(inputMap['name'] as String? ?? '');
    }

    return AbiError(
      name: json['name'] as String,
      inputs: inputs,
      inputNames: inputNames,
    );
  }

  /// Gets the error signature.
  String get signature {
    final inputTypes = inputs.map((i) => i.name).join(',');
    return '$name($inputTypes)';
  }
}
