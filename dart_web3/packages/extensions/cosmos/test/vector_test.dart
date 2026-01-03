import 'dart:convert';
import 'dart:io';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_cosmos/dart_web3_cosmos.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmos Vector Tests', () {
    final vectorsFile = File('test/vectors/cosmos_tx.json');
    final vectors = json.decode(vectorsFile.readAsStringSync()) as List;

    for (var i = 0; i < vectors.length; i++) {
        final vector = vectors[i] as Map<String, dynamic>;
        final description = vector['description'] as String;

        test('Vector #$i: $description', () {
            final fromAddress = vector['fromAddress'] as String;
            final toAddress = vector['toAddress'] as String;
            final amountList = vector['amount'] as List;
            final amount = amountList.map((c) {
                final cMap = c as Map<String, dynamic>;
                return Coin(
                    denom: cMap['denom'] as String,
                    amount: cMap['amount'] as String,
                );
            }).toList();

            final msgSend = MsgSend(
                fromAddress: fromAddress,
                toAddress: toAddress,
                amount: amount,
            );

            final any = msgSend.toAny(); // This returns GoogleAny
            
            final expectedValueHex = vector['expectedValueHex'] as String;
            final actualValueHex = HexUtils.encode(any.value, prefix: false);
            expect(actualValueHex, equals(expectedValueHex), reason: 'Inner MsgSend serialization mismatch');
            
            expect(any.typeUrl, equals(vector['typeUrl'] as String));
        });
    }
  });
}
