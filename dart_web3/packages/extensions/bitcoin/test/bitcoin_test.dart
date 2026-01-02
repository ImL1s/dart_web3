import 'package:dart_web3_bitcoin/dart_web3_bitcoin.dart';
import 'package:test/test.dart';

void main() {
  group('Bitcoin Module Tests', () {
    test('should initialize InscriptionService', () {
      final service = InscriptionService();
      expect(service, isNotNull);
    });
  });
}
