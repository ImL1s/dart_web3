import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:test/test.dart';

void main() {
  group('EIP712TypedData Tests', () {
    test('creates EIP712TypedData from constructor', () {
      final typedData = EIP712TypedData(
        domain: {
          'name': 'Test App',
          'version': '1',
          'chainId': 1,
          'verifyingContract': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
        },
        types: {
          'Person': [
            TypedDataField(name: 'name', type: 'string'),
            TypedDataField(name: 'wallet', type: 'address'),
          ],
        },
        primaryType: 'Person',
        message: {
          'name': 'Alice',
          'wallet': '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
        },
      );

      expect(typedData.primaryType, equals('Person'));
      expect(typedData.domain['name'], equals('Test App'));
    });

    test('creates EIP712TypedData from JSON', () {
      final json = {
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
          ],
          'Mail': [
            {'name': 'from', 'type': 'string'},
            {'name': 'to', 'type': 'string'},
            {'name': 'contents', 'type': 'string'},
          ],
        },
        'primaryType': 'Mail',
        'domain': {
          'name': 'Ether Mail',
          'version': '1',
          'chainId': 1,
        },
        'message': {
          'from': 'Alice',
          'to': 'Bob',
          'contents': 'Hello!',
        },
      };

      final typedData = EIP712TypedData.fromJson(json);

      expect(typedData.primaryType, equals('Mail'));
      expect(typedData.types['Mail']!.length, equals(3));
    });

    test('computes hash correctly', () {
      final typedData = EIP712TypedData(
        domain: {
          'name': 'Test',
          'version': '1',
          'chainId': 1,
        },
        types: {
          'Message': [
            TypedDataField(name: 'content', type: 'string'),
          ],
        },
        primaryType: 'Message',
        message: {
          'content': 'Hello',
        },
      );

      final hash = typedData.hash();

      expect(hash.length, equals(32));
    });

    test('hash is deterministic', () {
      final typedData = EIP712TypedData(
        domain: {
          'name': 'Test',
          'version': '1',
          'chainId': 1,
        },
        types: {
          'Message': [
            TypedDataField(name: 'content', type: 'string'),
          ],
        },
        primaryType: 'Message',
        message: {
          'content': 'Hello',
        },
      );

      final hash1 = typedData.hash();
      final hash2 = typedData.hash();

      expect(BytesUtils.equals(hash1, hash2), isTrue);
    });

    test('different messages produce different hashes', () {
      final typedData1 = EIP712TypedData(
        domain: {'name': 'Test', 'version': '1', 'chainId': 1},
        types: {
          'Message': [TypedDataField(name: 'content', type: 'string')],
        },
        primaryType: 'Message',
        message: {'content': 'Hello'},
      );

      final typedData2 = EIP712TypedData(
        domain: {'name': 'Test', 'version': '1', 'chainId': 1},
        types: {
          'Message': [TypedDataField(name: 'content', type: 'string')],
        },
        primaryType: 'Message',
        message: {'content': 'World'},
      );

      final hash1 = typedData1.hash();
      final hash2 = typedData2.hash();

      expect(BytesUtils.equals(hash1, hash2), isFalse);
    });

    test('converts to JSON correctly', () {
      final typedData = EIP712TypedData(
        domain: {
          'name': 'Test',
          'version': '1',
          'chainId': 1,
        },
        types: {
          'Message': [
            TypedDataField(name: 'content', type: 'string'),
          ],
        },
        primaryType: 'Message',
        message: {
          'content': 'Hello',
        },
      );

      final json = typedData.toJson();

      expect(json['primaryType'], equals('Message'));
      expect(json['domain']['name'], equals('Test'));
      expect((json['types'] as Map).containsKey('EIP712Domain'), isTrue);
    });
  });
}
