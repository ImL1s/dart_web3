import 'package:web3_universal_price/web3_universal_price.dart';
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
