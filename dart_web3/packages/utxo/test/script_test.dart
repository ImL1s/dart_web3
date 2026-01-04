import 'dart:typed_data';

import 'package:convert/convert.dart'; // for hex
import 'package:test/test.dart';
import 'package:web3_universal_utxo/src/script/script.dart';

void main() {
  group('Bitcoin Script Engine', () {
    Uint8List h(String text) => Uint8List.fromList(hex.decode(text));

    test('P2PKH Compilation & Parsing', () {
      final pubKeyHash = h('0000000000000000000000000000000000000000');
      final scriptBytes = Script.p2pkh(pubKeyHash);

      // OP_DUP OP_HASH160 <20> <hash> OP_EQUALVERIFY OP_CHECKSIG
      // 76     a9         14   ...    88             ac
      expect(scriptBytes.length, 25);
      expect(scriptBytes[0], OpCode.opDup);
      expect(scriptBytes[1], OpCode.opHash160);
      expect(scriptBytes[2], 0x14);
      expect(scriptBytes[24], OpCode.opCheckSig);

      final script = Script.fromBytes(scriptBytes);
      expect(script.isP2PKH, isTrue);
      expect(script.ops[2], equals(pubKeyHash));
    });

    test('P2SH Compilation & Parsing', () {
      final scriptHash = h('1111111111111111111111111111111111111111');
      final scriptBytes = Script.p2sh(scriptHash);

      // OP_HASH160 <20> <hash> OP_EQUAL
      // a9         14   ...    87
      expect(scriptBytes.length, 23);
      expect(scriptBytes[0], OpCode.opHash160);
      expect(scriptBytes[22], OpCode.opEqual);

      final script = Script.fromBytes(scriptBytes);
      expect(script.isP2SH, isTrue);
      expect(script.ops[1], equals(scriptHash));
    });

    test('P2WPKH Compilation & Parsing', () {
      final pubKeyHash = h('2222222222222222222222222222222222222222');
      final scriptBytes = Script.p2wpkh(pubKeyHash);

      // OP_0 <20> <hash>
      // 00   14   ...
      expect(scriptBytes.length, 22);
      expect(scriptBytes[0], OpCode.op0);

      final script = Script.fromBytes(scriptBytes);
      expect(script.isP2WPKH, isTrue);
      expect(script.ops[1], equals(pubKeyHash));
    });

    test('P2TR Compilation & Parsing', () {
      // Manual construction for P2TR as helper not strictly in script.dart yet?
      // Ah, implementation plan said "Script Type Matching (isP2TR)".
      // Let's check constructor.
      final witnessProgram =
          h('3333333333333333333333333333333333333333333333333333333333333333');
      final script = Script([OpCode.op1, witnessProgram]);
      final scriptBytes = script.compile();

      // OP_1 <32> <program>
      // 51   20   ...
      expect(scriptBytes.length, 34);
      expect(scriptBytes[0], OpCode.op1);

      final parsed = Script.fromBytes(scriptBytes);
      expect(parsed.isP2TR, isTrue);
      expect(parsed.ops[1], equals(witnessProgram));
    });

    test('Data Push Sizes', () {
      // 75 bytes -> direct len
      final data75 = Uint8List(75);
      final s75 = Script([data75]);
      expect(s75.compile()[0], 75);

      // 76 bytes -> OP_PUSHDATA1
      final data76 = Uint8List(76);
      final s76 = Script([data76]);
      expect(s76.compile()[0], OpCode.opPushData1);
      expect(s76.compile()[1], 76);

      // 256 bytes -> OP_PUSHDATA2
      final data256 = Uint8List(256);
      final s256 = Script([data256]);
      expect(s256.compile()[0], OpCode.opPushData2);

      // Helper check
      final parsed = Script.fromBytes(s256.compile());
      expect(parsed.ops[0], equals(data256));
    });
  });
}
