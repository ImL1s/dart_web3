import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';

import 'types.dart';
import 'decoder.dart';
import 'encoder.dart';
import 'parser.dart';

/// Represents a decoded contract error.
class DecodedError {
  /// The error name (e.g., 'InsufficientBalance').
  final String name;

  /// The error selector (first 4 bytes of error signature hash).
  final String selector;

  /// The decoded error arguments.
  final List<dynamic> args;

  /// Named arguments if available.
  final Map<String, dynamic>? namedArgs;

  /// The original error data.
  final String data;

  DecodedError({
    required this.name,
    required this.selector,
    required this.args,
    this.namedArgs,
    required this.data,
  });

  @override
  String toString() {
    if (namedArgs != null && namedArgs!.isNotEmpty) {
      final argsStr = namedArgs!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return '$name($argsStr)';
    }
    return '$name(${args.join(', ')})';
  }
}

/// Definition of a custom error for decoding.
class ErrorDefinition {
  /// The error name.
  final String name;

  /// The error parameter types.
  final List<AbiType> types;

  /// The error parameter names (optional).
  final List<String>? names;

  /// The error selector (calculated from signature).
  late final String selector;

  ErrorDefinition({
    required this.name,
    required this.types,
    this.names,
  }) {
    // Calculate selector from signature
    final typeNames = types.map((t) => _getTypeName(t)).join(',');
    final signature = '$name($typeNames)';
    final selectorBytes = AbiEncoder.getFunctionSelector(signature);
    selector = HexUtils.encode(selectorBytes);
  }

  static String _getTypeName(AbiType type) {
    if (type is AbiUint) return 'uint${type.bits}';
    if (type is AbiInt) return 'int${type.bits}';
    if (type is AbiAddress) return 'address';
    if (type is AbiBool) return 'bool';
    if (type is AbiFixedBytes) return 'bytes${type.length}';
    if (type is AbiBytes) return 'bytes';
    if (type is AbiString) return 'string';
    if (type is AbiArray) {
      final elemName = _getTypeName(type.elementType);
      return type.length != null ? '$elemName[${type.length}]' : '$elemName[]';
    }
    if (type is AbiTuple) {
      final inner = type.components.map(_getTypeName).join(',');
      return '($inner)';
    }
    return 'unknown';
  }

  /// Creates an error definition from a Solidity signature.
  ///
  /// Example: `InsufficientBalance(address account, uint256 balance)`
  factory ErrorDefinition.fromSignature(String signature) {
    final match = RegExp(r'^(\w+)\((.*)\)$').firstMatch(signature);
    if (match == null) {
      throw ArgumentError('Invalid error signature: $signature');
    }

    final name = match.group(1)!;
    final paramsStr = match.group(2)!;

    final types = <AbiType>[];
    final names = <String>[];

    if (paramsStr.isNotEmpty) {
      final params = _splitParams(paramsStr);
      for (final param in params) {
        final parts = param.trim().split(RegExp(r'\s+'));
        final typeStr = parts[0];
        final paramName = parts.length > 1 ? parts.last : null;

        types.add(AbiParser.parseType(typeStr));
        if (paramName != null) {
          names.add(paramName);
        }
      }
    }

    return ErrorDefinition(
      name: name,
      types: types,
      names: names.isNotEmpty ? names : null,
    );
  }

  static List<String> _splitParams(String params) {
    final result = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < params.length; i++) {
      final char = params[i];
      if (char == '(' || char == '[') depth++;
      else if (char == ')' || char == ']') depth--;
      else if (char == ',' && depth == 0) {
        result.add(params.substring(start, i).trim());
        start = i + 1;
      }
    }

    if (start < params.length) {
      result.add(params.substring(start).trim());
    }

    return result;
  }
}

/// Decodes contract errors including custom errors.
///
/// Based on viem's decodeErrorResult functionality.
///
/// Example:
/// ```dart
/// final decoder = ErrorDecoder([
///   ErrorDefinition.fromSignature('InsufficientBalance(address account, uint256 balance)'),
///   ErrorDefinition.fromSignature('Unauthorized(address caller)'),
/// ]);
///
/// final error = decoder.decode('0x...');
/// print(error?.name); // 'InsufficientBalance'
/// print(error?.args); // ['0x...', BigInt.from(100)]
/// ```
class ErrorDecoder {
  /// Map of selector to error definition.
  final Map<String, ErrorDefinition> _errors = {};

  /// Standard Error(string) selector.
  static const String errorSelector = '0x08c379a0';

  /// Standard Panic(uint256) selector.
  static const String panicSelector = '0x4e487b71';

  ErrorDecoder([List<ErrorDefinition>? errors]) {
    if (errors != null) {
      for (final error in errors) {
        _errors[error.selector] = error;
      }
    }
  }

  /// Adds an error definition.
  void addError(ErrorDefinition error) {
    _errors[error.selector] = error;
  }

  /// Adds an error from a signature string.
  void addErrorFromSignature(String signature) {
    final error = ErrorDefinition.fromSignature(signature);
    _errors[error.selector] = error;
  }

  /// Adds errors from a JSON ABI.
  void addErrorsFromAbi(List<Map<String, dynamic>> abi) {
    for (final item in abi) {
      if (item['type'] == 'error') {
        final name = item['name'] as String;
        final inputs = (item['inputs'] as List?) ?? [];

        final types = <AbiType>[];
        final names = <String>[];

        for (final input in inputs) {
          final typeStr = input['type'] as String;
          types.add(AbiParser.parseType(typeStr));

          final inputName = input['name'] as String?;
          if (inputName != null) {
            names.add(inputName);
          }
        }

        final error = ErrorDefinition(
          name: name,
          types: types,
          names: names.isNotEmpty ? names : null,
        );
        _errors[error.selector] = error;
      }
    }
  }

  /// Decodes error data.
  ///
  /// Returns null if the error cannot be decoded.
  DecodedError? decode(String data) {
    if (data.length < 10) return null; // Minimum: 0x + 4 byte selector

    var hexData = data;
    if (hexData.startsWith('0x')) {
      hexData = hexData.substring(2);
    }

    final selector = '0x${hexData.substring(0, 8)}';
    final errorData = _hexToBytes(hexData.substring(8));

    // Check for standard Error(string)
    if (selector == errorSelector) {
      try {
        final decoded = AbiDecoder.decode([AbiString()], errorData);
        return DecodedError(
          name: 'Error',
          selector: selector,
          args: decoded,
          namedArgs: {'message': decoded[0]},
          data: data,
        );
      } catch (_) {
        return null;
      }
    }

    // Check for Panic(uint256)
    if (selector == panicSelector) {
      try {
        final decoded = AbiDecoder.decode([AbiUint(256)], errorData);
        final code = (decoded[0] as BigInt).toInt();
        return DecodedError(
          name: 'Panic',
          selector: selector,
          args: decoded,
          namedArgs: {'code': code, 'reason': _panicReason(code)},
          data: data,
        );
      } catch (_) {
        return null;
      }
    }

    // Check for custom errors
    final errorDef = _errors[selector];
    if (errorDef != null) {
      try {
        final decoded = AbiDecoder.decode(errorDef.types, errorData);

        Map<String, dynamic>? namedArgs;
        if (errorDef.names != null) {
          namedArgs = {};
          for (var i = 0; i < errorDef.names!.length && i < decoded.length; i++) {
            namedArgs[errorDef.names![i]] = decoded[i];
          }
        }

        return DecodedError(
          name: errorDef.name,
          selector: selector,
          args: decoded,
          namedArgs: namedArgs,
          data: data,
        );
      } catch (_) {
        return null;
      }
    }

    // Unknown error - return raw data
    return DecodedError(
      name: 'UnknownError',
      selector: selector,
      args: [data],
      data: data,
    );
  }

  /// Decodes error from an RPC error response.
  ///
  /// RPC errors often include revert data in the `data` field.
  DecodedError? decodeFromRpcError(Map<String, dynamic> error) {
    // Check various possible locations for error data
    final data = error['data'] as String? ??
        (error['error'] as Map<String, dynamic>?)?['data'] as String? ??
        (error['error'] as Map<String, dynamic>?)?['message'] as String?;

    if (data == null) return null;

    // Try to decode as hex data
    if (data.startsWith('0x')) {
      return decode(data);
    }

    // Try to extract hex data from message
    final hexMatch = RegExp(r'0x[a-fA-F0-9]+').firstMatch(data);
    if (hexMatch != null) {
      return decode(hexMatch.group(0)!);
    }

    // Return raw message as Error
    return DecodedError(
      name: 'Error',
      selector: errorSelector,
      args: [data],
      namedArgs: {'message': data},
      data: data,
    );
  }

  static String _panicReason(int code) {
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
        return 'Unknown panic code';
    }
  }

  static Uint8List _hexToBytes(String hex) {
    var data = hex;
    if (data.length.isOdd) {
      data = '0$data';
    }

    final result = Uint8List(data.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(data.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

/// Enhanced RPC error with decoded revert reason.
class DecodedRpcError implements Exception {
  /// The original RPC error code.
  final int code;

  /// The original RPC error message.
  final String message;

  /// The raw error data.
  final String? data;

  /// The decoded error information.
  final DecodedError? decoded;

  DecodedRpcError({
    required this.code,
    required this.message,
    this.data,
    this.decoded,
  });

  /// Creates from a raw RPC error, attempting to decode the revert reason.
  factory DecodedRpcError.fromRpcError(
    Map<String, dynamic> error, {
    ErrorDecoder? decoder,
  }) {
    final code = error['code'] as int;
    final message = error['message'] as String;
    final data = error['data'] as String?;

    DecodedError? decoded;
    if (data != null && decoder != null) {
      decoded = decoder.decode(data);
    } else if (data != null) {
      // Use default decoder
      decoded = ErrorDecoder().decode(data);
    }

    return DecodedRpcError(
      code: code,
      message: message,
      data: data,
      decoded: decoded,
    );
  }

  @override
  String toString() {
    if (decoded != null) {
      return 'RpcError($code): $message - ${decoded!.name}(${decoded!.args.join(', ')})';
    }
    return 'RpcError($code): $message';
  }

  /// Gets a human-readable error message.
  String get reason {
    if (decoded != null) {
      if (decoded!.name == 'Error' && decoded!.namedArgs?['message'] != null) {
        return decoded!.namedArgs!['message'] as String;
      }
      if (decoded!.name == 'Panic' && decoded!.namedArgs?['reason'] != null) {
        return decoded!.namedArgs!['reason'] as String;
      }
      return decoded.toString();
    }
    return message;
  }
}
