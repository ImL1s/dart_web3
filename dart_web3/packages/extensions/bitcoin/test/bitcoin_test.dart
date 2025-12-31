import 'package:test/test.dart';
import 'package:dart_web3_bitcoin/dart_web3_bitcoin.dart';

void main() {
  group('Bitcoin Module Tests', () {
    test('should initialize InscriptionService', () {
      final service = InscriptionService();
      expect(service, isNotNull);
    });
  });
}
