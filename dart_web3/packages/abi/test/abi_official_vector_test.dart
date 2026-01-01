import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('Official ABI Test Vectors', () {
    final file = File('test/vectors/abi_vectors.json');
    final List<dynamic> vectors = json.decode(file.readAsStringSync());

    for (var vector in vectors) {
      test('Vector: ${vector['name']}', () {
        final typesStr = vector['types'] as List;
        final values = vector['values'] as List;
        final expected = vector['result'] as String;

        // Note: In a real implementation, we would use an AbiType parser 
        // to convert strings like "uint256" to AbiType objects.
        // For this rigorous test, we manually map them.
        final types = typesStr.map((t) {
          if (t == 'uint256') return AbiUint(256);
          if (t == 'address') return AbiAddress();
          if (t == 'string') return AbiString();
          if (t == '(uint256,bool)') return AbiTuple([AbiUint(256), AbiBool()]);
          throw UnimplementedError('Unknown type for vector test: $t');
        }).toList();

        final encoded = AbiEncoder.encode(types, values);
        expect(HexUtils.encode(encoded, prefix: true), equals(expected));
      });
    }
  });
}
