import 'package:test/test.dart';
import 'package:dart_web3_solana/dart_web3_solana.dart';

void main() {
  group('Solana Module Tests', () {
    test('should create SolanaAddress', () {
      final address = SolanaAddress.fromBase58('11111111111111111111111111111111');
      expect(address, isNotNull);
    });
  });
}
