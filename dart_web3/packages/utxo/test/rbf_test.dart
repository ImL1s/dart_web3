
import 'dart:typed_data';
import 'package:dart_web3_utxo/dart_web3_utxo.dart';
import 'package:test/test.dart';

void main() {
  group('RBF (Replace-By-Fee)', () {
    test('Should identify RBF transaction', () {
      final inputRbf = TransactionInput(
        txId: Uint8List(32),
        vout: 0,
        sequence: 0xfffffffd, // RBF signaling
      );
      
      final txRbf = BitcoinTransaction(inputs: [inputRbf]);
      expect(txRbf.isRbf, isTrue);
    });

    test('Should identify non-RBF transaction', () {
      final inputFinal = TransactionInput(
        txId: Uint8List(32),
        vout: 0,
      );
      
      final txFinal = BitcoinTransaction(inputs: [inputFinal]);
      expect(txFinal.isRbf, isFalse);
       
      final inputOptOut = TransactionInput(
        txId: Uint8List(32),
        vout: 0,
        sequence: 0xfffffffe, // Opt-out RBF but not final
      );
      // Wait, 0xfffffffe is NOT RBF signaling according to BIP-125
      // "inheriting sequences of less than (0xffffffff - 1)"
      // So < 0xfffffffe.
      
      final txOptOut = BitcoinTransaction(inputs: [inputOptOut]);
      expect(txOptOut.isRbf, isFalse);
    });
  });
}
