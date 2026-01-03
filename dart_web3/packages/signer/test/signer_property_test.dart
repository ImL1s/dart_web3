import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/src/private_key_signer.dart';
import 'package:glados/glados.dart';
import 'package:test/test.dart' as test_pkg;

void main() {
  // Use testAsync for async tests
  Glados<int>().test('Signer: Key Generation Consistency', (seed) async {
    // Fuzzing logic:
    // 1. Generate Credential from a random seed (using int as poor man's entropy source for this demo)
    
    // valid private key must be > 0. Handle 0 case.
    if (seed == 0) return;

    // Note: Since PrivateKeySigner needs 32 bytes, we pad/hash the input
    final seedBytesStr = BigInt.from(seed.abs()).toRadixString(16).padLeft(64, '0');
    final privateKeyBytes = HexUtils.decode(seedBytesStr);
    
    // Ensure valid private key range (simple check for this fuzz test)
    if (BigInt.parse(seedBytesStr, radix: 16) == BigInt.zero) return;

    // Test direct signer creation
    final signer = PrivateKeySigner(privateKeyBytes, 1);
    
    // ... rest of test
    final signatureBytes = await signer.signMessage('test message'); 
    
    // Property 1: Signature should be 65 bytes (r, s, v)
    expect(signatureBytes.length, equals(65));
    
    // Additional check: public address derivation consistency
    final address = signer.address;
    expect(address.hex.length, equals(42)); // 0x + 40 hex chars
  });
}
