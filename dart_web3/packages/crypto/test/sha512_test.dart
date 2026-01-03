import 'dart:convert';
import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/src/sha2.dart';
import 'package:test/test.dart';

void main() {
  test('SHA-512 empty string', () {
    final digest = Sha512.hash(Uint8List(0));
    final expected = 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e';
    expect(HexUtils.encode(digest), equals(expected));
  });
}
