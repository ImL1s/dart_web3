import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_utxo/web3_universal_utxo.dart';

void main() {
  group('Bitcoin Vector Tests', () {
    final vectorsFile = File('test/vectors/bitcoin_tx.json');
    final vectors = json.decode(vectorsFile.readAsStringSync()) as List;

    for (var i = 0; i < vectors.length; i++) {
      final vector = vectors[i] as Map<String, dynamic>;
      final description = vector['description'] as String;

      test('Vector #$i: $description', () {
        final version = vector['version'] as int;
        final locktime = vector['locktime'] as int;
        final isSegwit = vector['segwit'] as bool? ?? false;
        final inputsSrc = vector['inputs'] as List;

        final inputs = inputsSrc.map((inData) {
          final inMap = inData as Map<String, dynamic>;
          final txid = HexUtils.decode(inMap['txid'] as String);
          final vout = inMap['vout'] as int;
          final scriptSig = HexUtils.decode(inMap['scriptSig'] as String);
          final sequence = inMap['sequence'] as int;
          final witnessSrc = inMap['witness'] as List?;
          final witness =
              witnessSrc?.map((w) => HexUtils.decode(w as String)).toList();

          return TransactionInput(
            txId: txid,
            vout: vout,
            scriptSig: scriptSig,
            sequence: sequence,
            witness: witness,
          );
        }).toList();

        final outputsSrc = vector['outputs'] as List;
        final outputs = outputsSrc.map((outData) {
          final outMap = outData as Map<String, dynamic>;
          final amount = BigInt.from(outMap['amount'] as int);
          final scriptPubKey =
              HexUtils.decode(outMap['scriptPubKey'] as String);
          return TransactionOutput(amount: amount, scriptPubKey: scriptPubKey);
        }).toList();

        final tx = BitcoinTransaction(
          version: version,
          inputs: inputs,
          outputs: outputs,
          lockTime: locktime,
        );

        final expectedHex = vector['hex'] as String;
        final actualHex =
            HexUtils.encode(tx.toBytes(segwit: isSegwit), prefix: false);

        expect(actualHex, equals(expectedHex),
            reason: 'Serialization mismatch');
      });
    }
  });
}
