import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:glados/glados.dart';

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
    if (req.nonce == null) {
       throw Exception('Nonce should not be null');
    }
    
    // 3. Verify copyWith consistency
    final req2 = req.copyWith(value: BigInt.zero);
    if (req2.value != BigInt.zero) {
       throw Exception('Value mismatch after copyWith');
    }
    if (req2.nonce != req.nonce) {
       throw Exception('Nonce mismatch after copyWith');
    }
  });
}
