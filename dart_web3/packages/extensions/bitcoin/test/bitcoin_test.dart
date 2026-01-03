import 'package:web3_universal_bitcoin/web3_universal_bitcoin.dart';
import 'package:test/test.dart';

void main() {
  group('Bitcoin Module Tests', () {
    test('should initialize InscriptionService', () {
      final service = InscriptionService();
      expect(service, isNotNull);
    });
  });
}
