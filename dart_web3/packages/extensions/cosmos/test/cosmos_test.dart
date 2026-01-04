import 'dart:typed_data';

import 'package:web3_universal_cosmos/web3_universal_cosmos.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmos Address', () {
    test('Encode and Decode', () {
      final hash = Uint8List(20);
      for (var i = 0; i < 20; i++) {
        hash[i] = i;
      }
      // 000102...13

      final addr = CosmosAddress(hash);
      expect(addr.hrp, equals('cosmos'));
      final str = addr.address;
      print('Cosmos Address: $str');

      final decoded = CosmosAddress.fromString(str);
      expect(decoded.hrp, equals('cosmos'));
      expect(decoded.hash, equals(hash));
    });

    test('Custom HRP', () {
      final hash = Uint8List(20);
      final addr = CosmosAddress(hash, hrp: 'osmo');
      expect(addr.address, startsWith('osmo1'));

      final decoded = CosmosAddress.fromString(addr.address);
      expect(decoded.hrp, equals('osmo'));
    });
  });
}
