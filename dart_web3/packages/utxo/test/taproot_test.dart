
import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_utxo/dart_web3_utxo.dart';
import 'package:test/test.dart';

void main() {
  group('BIP-341 Taproot', () {
    // Official vectors for Tagged Hash and Tweaking would be ideal.
    // Here we verify internal consistency and basic functionality.
    
    test('TapLeaf Tagged Hash', () {
        // Simple script: OP_CHECK_SIG (0xac)
        final script = Uint8List.fromList([0xac]);
        final leaf = TapLeaf(script: script);
        
        // This hash should be deterministic
        final hash1 = leaf.hash;
        final hash2 = leaf.hash;
        
        expect(HexUtils.encode(hash1), equals(HexUtils.encode(hash2)));
        expect(hash1.length, 32);
    });

    test('Taproot Tweak (Key Path Spend)', () {
        // Internal Key: P = 0x02 + 31 bytes (mock compressed) -> x-only
        // Just use a valid x-only key
        // x-only key from BIP-340 vectors
        final internalKey = HexUtils.decode('00000000000000000000006f8c296684725af9a61f224b74bb0f6c2f5d94713a');
        
        // Tweak with null merkle root (Key Path)
        final result = TaprootKey.tweak(internalKey);
        
        expect(result['outputKey'], isNotNull);
        expect((result['outputKey'] as Uint8List).length, 32);
        expect(result['parity'], isA<int>());
        // Parity should be 0 or 1
        expect(result['parity'] == 0 || result['parity'] == 1, isTrue);
    });
    
    test('Taproot Tweak (Script Path Spend)', () {
        final internalKey = HexUtils.decode('00000000000000000000006f8c296684725af9a61f224b74bb0f6c2f5d94713a');
        final script = Uint8List.fromList([0xac]);
        final leaf = TapLeaf(script: script);
        
        // Tweak with script merkle root
        final result = TaprootKey.tweak(internalKey, leaf.hash);
        
        expect(result['outputKey'], isNotNull);
        expect((result['outputKey'] as Uint8List).length, 32);
        
        // Output key should differ from internal key
        expect(HexUtils.encode(result['outputKey'] as Uint8List), isNot(equals(HexUtils.encode(internalKey))));
    });
  });
}
