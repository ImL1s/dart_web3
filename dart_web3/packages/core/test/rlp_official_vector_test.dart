import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('Official RLP Test Vectors', () {
    final file = File('test/vectors/rlp_vectors.json');
    final Map<String, dynamic> vectors = json.decode(file.readAsStringSync());

    vectors.forEach((name, data) {
      test('Vector: $name', () {
        final expectedHex = data['out'];
        final input = data['in'];

        final encoded = RLP.encode(input is String && name != "shortString" && name != "longString" && name != "emptyString"
            ? HexUtils.decode(input) 
            : input);
            
        expect(HexUtils.encode(encoded, prefix: false), equals(expectedHex));
      });
    });
  });
}
