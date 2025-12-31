import 'package:test/test.dart';
import 'package:dart_web3_mev/dart_web3_mev.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('MEV Service Tests', () {
    test('should create FlashbotsBundleTransaction', () {
      final tx = FlashbotsBundleTransaction(
        signedTransaction: '0x123',
      );
      
      final json = tx.toJson();
      expect(json['signedTransaction'], equals('0x123'));
    });

    test('should create FlashbotsBundle', () {
      final bundle = FlashbotsBundle(
        txs: [FlashbotsBundleTransaction(signedTransaction: '0x123')],
        blockNumber: BigInt.from(100),
        minTimestamp: 1234567890,
      );

      final json = bundle.toJson();
      expect(json['txs'], isA<List>());
      expect((json['txs'] as List).length, equals(1));
      // Assuming HexUtils.encode handles the big int conversion correctly
      // We just check structure here
      expect(json.containsKey('blockNumber'), isTrue);
      expect(json['minTimestamp'], equals(1234567890));
    });
  });
}
