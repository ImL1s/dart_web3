import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

// Helper to convert int to BigInt deeply, as dart_web3 often requires BigInt
dynamic sanitizeValue(dynamic value) {
  if (value is int) return BigInt.from(value);
  if (value is List) return value.map(sanitizeValue).toList();
  return value;
}

void main() {
  group('Official ABI Test Vectors', () {
    File? file;
    final possiblePaths = [
      'test/vectors/abi_vectors.json',
      'packages/abi/test/vectors/abi_vectors.json',
      'dart_web3/packages/abi/test/vectors/abi_vectors.json'
    ];

    for (final path in possiblePaths) {
      final f = File(path);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }

    if (file == null) {
      throw Exception('Could not find abi_vectors.json');
    }

    final List<dynamic> vectors = json.decode(file!.readAsStringSync());

    for (var vector in vectors) {
      test('Vector: ${vector['name']}', () {
        final typesStr = vector['types'] as List;
        final rawValues = vector['values'] as List;
        final expected = vector['result'] as String;

        // Sanitize values (int -> BigInt)
        final values = sanitizeValue(rawValues) as List;

        final types = typesStr.map((t) {
          if (t == 'uint256') return AbiUint(256);
          if (t == 'address') return AbiAddress();
          if (t == 'string') return AbiString();
          if (t == '(uint256,bool)') return AbiTuple([AbiUint(256), AbiBool()]);
          throw UnimplementedError('Unknown type for vector test: $t');
        }).toList();

        final encoded = AbiEncoder.encode(types, values);
        final resultHex = HexUtils.encode(encoded, prefix: true);
        
        if (resultHex.toLowerCase() != expected.toLowerCase()) {
           fail('Mismatch for ${vector['name']}.\nExpected: $expected\nActual:   $resultHex');
        }
      });
    }
  });
}
