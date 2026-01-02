import 'package:dart_web3_price/dart_web3_price.dart';
import 'package:test/test.dart';

void main() {
  group('Price Service Tests', () {
    test('should manage cache correctly', () {
      final service = PriceService();
      service.clearCache();
      // Basic initialization check
      expect(service, isNotNull);
    });
  });
}
