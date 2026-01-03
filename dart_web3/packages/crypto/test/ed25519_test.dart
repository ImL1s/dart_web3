import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('Ed25519', () {
    test('RFC 8032 Test Vector 1', () {
      final sk = HexUtils.decode('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
      final expectedPk = HexUtils.decode('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
      final msg = Uint8List(0);
      final expectedSig = HexUtils.decode('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b');

      final pk = Ed25519.getPublicKey(sk);
      expect(HexUtils.encode(pk), equals(HexUtils.encode(expectedPk)));

      final sig = Ed25519.sign(msg, sk);
      expect(HexUtils.encode(sig), equals(HexUtils.encode(expectedSig)));

      final valid = Ed25519.verify(sig, msg, pk);
      expect(valid, isTrue);
    });
  });
}
