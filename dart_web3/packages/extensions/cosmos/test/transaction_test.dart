import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_web3_cosmos/dart_web3_cosmos.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmos Transaction', () {
    test('Serialize MsgSend', () {
        // Create MsgSend
        final msg = MsgSend(
            fromAddress: 'cosmos1ExampleFrom',
            toAddress: 'cosmos1ExampleTo',
            amount: [Coin(denom: 'uatom', amount: '1000')],
        );
        
        final anyMsg = msg.toAny();
        expect(anyMsg.typeUrl, equals('/cosmos.bank.v1beta1.MsgSend'));
        
        // Create TxBody
        final body = TxBody(messages: [anyMsg], memo: 'test memo');
        final bodyBytes = body.toBytes();
        expect(bodyBytes, isNotEmpty);
        
        // Verify body structure (manual inspection or known vector check)
        // 0A len (0A len typeUrl 1A len value(0A ...)) 12 len memo
        
        // Pseudo SignDoc
        final signDoc = SignDoc(
            bodyBytes: bodyBytes,
            authInfoBytes: Uint8List.fromList([0x0a]), // Dummy
            chainId: 'cosmoshub-4',
            accountNumber: 12345,
        );
        
        final signBytes = signDoc.serialize();
        expect(signBytes, isNotEmpty);
    });
  });
}
