import 'package:test/test.dart';
import 'package:dart_web3_history/dart_web3_history.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('History Service Types Tests', () {
    test('should create HistoryItem with correct values', () {
      final now = DateTime.now();
      final from = EthereumAddress.fromHex('0x1111111111111111111111111111111111111111');
      final to = EthereumAddress.fromHex('0x2222222222222222222222222222222222222222');
      
      final item = HistoryItem(
        hash: '0xabc',
        blockNumber: BigInt.from(100),
        timestamp: now,
        from: from,
        to: to,
        value: BigInt.from(1000),
        type: TransactionType.transfer,
        rawTransaction: {},
      );

      expect(item.hash, equals('0xabc'));
      expect(item.type, equals(TransactionType.transfer));
      expect(item.value, equals(BigInt.from(1000)));
    });
  });
}
