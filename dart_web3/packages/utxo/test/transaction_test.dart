import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_utxo/dart_web3_utxo.dart';
import 'package:test/test.dart';

void main() {
  group('BitcoinTransaction', () {
    test('serialize basic legacy transaction', () {
      final tx = BitcoinTransaction(
        inputs: [
          TransactionInput(
            txId: Uint8List(32), // 32 bytes of zeros
            vout: 0,
            scriptSig: Uint8List.fromList([0x01, 0xff]),
          ),
        ],
        outputs: [
          TransactionOutput(
            amount: BigInt.from(100000),
            scriptPubKey: Uint8List.fromList([0x76, 0xa9, 0x88, 0xac]),
          ),
        ],
      );

      final bytes = tx.toBytes(segwit: false);
      expect(bytes.length, greaterThan(0));
      // Version 4 + inputCount 1 + input (32+4+1+2+4) + outputCount 1 + output (8+1+4) + lockTime 4
      // 4 + 1 + 43 + 1 + 13 + 4 = 66
      expect(bytes.length, equals(66));
    });

    test('serialize segwit transaction', () {
      final tx = BitcoinTransaction(
        inputs: [
          TransactionInput(
            txId: Uint8List(32),
            vout: 1,
            // SegWit inputs usually have empty scriptSig for P2WPKH
            scriptSig: Uint8List(0),
            witness: [
              Uint8List.fromList([0x01, 0x02]), // dummy witness
            ],
          ),
        ],
        outputs: [
          TransactionOutput(
            amount: BigInt.from(50000),
            scriptPubKey: Uint8List(22),
          ),
        ],
      );

      final bytes = tx.toBytes(segwit: true);
      // Marker 2 + Version 4 + inputCount 1 + input (32+4+1+0+4) + outputCount 1 + output (8+1+22) + witnesses + lockTime 4
      // witness count 1 + witness item len 1 + witness item 2 => 4 bytes
      // 2 + 4 + 1 + 41 + 1 + 31 + 4 + 4 = 88
      expect(bytes.length, equals(88));
      expect(bytes[4], equals(0x00)); // Marker
      expect(bytes[5], equals(0x01)); // Flag
    });
  });
}
