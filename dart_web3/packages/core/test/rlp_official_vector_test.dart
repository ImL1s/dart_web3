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
        final rawInput = data['in'];

        dynamic parseInput(dynamic input) {
          if (input is List) {
            return input.map(parseInput).toList();
          }

          if (input is int) {
            return input;
          }

          if (input is String) {
            if (input.startsWith('#')) {
              return BigInt.parse(input.substring(1));
            }
            return input;
          }
           
           return input;
        }

        try {
          final processedInput = parseInput(rawInput);
          final encoded = RLP.encode(processedInput);
          
          // Handle 0x prefix if present in expectedHex
          String expected = expectedHex;
          if (expected.startsWith('0x')) {
             expected = expected.substring(2);
          }
          
          final actual = HexUtils.encode(encoded, prefix: false);
          
          if (actual != expected) {
             print('FAILED: $name');
             // Find first difference
             for (var i = 0; i < actual.length && i < expected.length; i++) {
               if (actual[i] != expected[i]) {
                 print('Mismatch at index $i:');
                 print('Expected char: ${expected[i]} (around "...${expected.substring(i > 10 ? i - 10 : 0, i + 10 < expected.length ? i + 10 : expected.length)}...")');
                 print('Actual char:   ${actual[i]} (around "...${actual.substring(i > 10 ? i - 10 : 0, i + 10 < actual.length ? i + 10 : actual.length)}...")');
                 break;
               }
             }
             if (actual.length != expected.length) {
               print('Length mismatch: Expected ${expected.length}, Actual ${actual.length}');
             }
             fail('Mismatch for $name');
          }
        } catch (e, s) {
          print('ERROR: $name');
          print('Input: $rawInput');
          print('Exception: $e');
          print(s);
          rethrow;
        }
      });
    });
  });
}
