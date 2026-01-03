import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_client/web3_universal_client.dart'; // Ensure models are exported
import 'package:web3_universal_signer/web3_universal_signer.dart'; // For TransactionRequest
import 'package:glados/glados.dart';
import 'package:test/test.dart' as test_pkg;

void main() {
  // Test TransactionRequest construction consistency
  Glados3<int, int, int>().test('Client: TransactionRequest Composition', (nonce, value, gas) {
    // 1. Create request with fuzzed parameters
    final req = TransactionRequest(
      nonce: BigInt.from(nonce.abs()),
      value: BigInt.from(value.abs()),
      gasLimit: BigInt.from(gas.abs()),
      to: '0x1234567890123456789012345678901234567890', // Fixed valid address
    );

    // 2. Verify properties
    expect(req.nonce, isNotNull);
    expect(req.value, greaterThanOrEqualTo(BigInt.zero));
    
    // 3. Verify copyWith immutability/consistency
    final req2 = req.copyWith(value: BigInt.zero);
    expect(req2.value, equals(BigInt.zero));
    expect(req2.nonce, equals(req.nonce)); // Should persist
  });
}
