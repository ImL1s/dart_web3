import 'dart:convert';
import 'dart:io';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('Official RLP Test Vectors', () {
    // Robust path resolution to handle running from package root or mono-repo root
    File? file;
    final possiblePaths = [
      'test/vectors/rlp_vectors.json',
      'packages/core/test/vectors/rlp_vectors.json',
      'dart_web3/packages/core/test/vectors/rlp_vectors.json',
    ];

    for (final path in possiblePaths) {
      final f = File(path);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }

    if (file == null) {
      throw Exception('Could not find rlp_vectors.json. Tried: $possiblePaths. Current dir: ${Directory.current.path}');
    }

    final vectors = json.decode(file.readAsStringSync()) as Map<String, dynamic>;

    vectors.forEach((name, data) {
      test('Vector: $name', () {
        final expectedHex = data['out'];
        final input = data['in'];

        // Determine input type based on vector name for this subsets
        // In a full runner we would use a more sophisticated parser
        dynamic processedInput = input;
        
        if (input is String) {
          if (name == 'singleByte' || name == 'emptyList' || name == 'nestedList') {
             // These are hex representions in the JSON or handled specially?
             // Actually input list is list. 
          }
          
          if (name != 'shortString' && name != 'longString' && name != 'emptyString') {
             // Assume Hex string for others if needed, but for 'singleByte' in="0f" it is hex
             try {
               processedInput = HexUtils.decode(input);
             } catch (_) {
               // keep as string if decode fails
             }
          }
        }

        final encoded = RLP.encode(processedInput);
        expect(HexUtils.encode(encoded, prefix: false), equals(expectedHex));
      });
    });
  });
}
