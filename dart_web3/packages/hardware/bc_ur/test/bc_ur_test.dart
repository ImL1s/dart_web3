import 'dart:typed_data';

import 'package:dart_web3_bc_ur/dart_web3_bc_ur.dart';
import 'package:test/test.dart';

void main() {
  group('BC-UR Encoding/Decoding', () {
    test('should encode and decode single-part message', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = BCUREncoder.encodeSingle('test-data', data);
      
      expect(encoded, startsWith('ur:test-data/'));
      
      final decoded = BCURDecoder.decodeSingle(encoded);
      expect(decoded.type, equals('test-data'));
      expect(decoded.isSinglePart, isTrue);
      expect(decoded.data, equals(data));
    });
    
    test('should handle multi-part encoding', () {
      final largeData = Uint8List(1000);
      for (var i = 0; i < largeData.length; i++) {
        largeData[i] = i % 256;
      }
      
      final parts = BCUREncoder.encodeMultiple('large-data', largeData, fragmentLength: 100);
      expect(parts.length, greaterThan(1));
      
      // Each part should be a valid UR
      for (final part in parts) {
        expect(part, startsWith('ur:large-data/'));
      }
    });
    
    test('should encode and decode Ethereum sign request', () {
      final request = EthSignRequest(
        requestId: Uint8List.fromList([1, 2, 3, 4]),
        signData: Uint8List.fromList([5, 6, 7, 8]),
        dataType: 1,
        chainId: 1,
        derivationPath: "m/44'/60'/0'/0/0",
      );
      
      final encoded = BCUREncoder.encodeEthSignRequest(request);
      expect(encoded, startsWith('ur:eth-sign-request/'));
      
      final decoded = BCURDecoder.decodeEthSignRequest(encoded);
      expect(decoded?.requestId, equals(request.requestId));
      expect(decoded?.signData, equals(request.signData));
      expect(decoded?.dataType, equals(request.dataType));
      expect(decoded?.chainId, equals(request.chainId));
    });
  });
  
  group('CBOR Encoding/Decoding', () {
    test('should encode and decode basic types', () {
      final testCases = [
        null,
        true,
        false,
        42,
        -17,
        'hello world',
        Uint8List.fromList([1, 2, 3]),
        [1, 2, 3],
        {'key': 'value', 'number': 42},
      ];
      
      for (final testCase in testCases) {
        final encoded = CBOREncoder.encode(testCase);
        final decoded = CBORDecoder.decode(encoded);
        
        if (testCase is Uint8List) {
          expect(decoded, equals(testCase));
        } else {
          expect(decoded, equals(testCase));
        }
      }
    });
  });
  
  group('Fountain Codes', () {
    test('should encode and decode with fountain codes', () {
      final data = Uint8List(500);
      for (var i = 0; i < data.length; i++) {
        data[i] = i % 256;
      }
      
      final encoder = FountainEncoder(data, 100);
      final decoder = FountainDecoder(100);
      
      expect(encoder.fragmentCount, equals(5));
      expect(decoder.isComplete, isFalse);
      
      // Collect parts until decoding is complete
      var partsReceived = 0;
      while (!decoder.isComplete && partsReceived < 20) {
        final part = encoder.nextPart();
        decoder.receivePart(part);
        partsReceived++;
      }
      
      expect(decoder.isComplete, isTrue);
      final result = decoder.getResult();
      expect(result, equals(data));
    });
  });
  
  group('Animated QR', () {
    test('should create animated QR from parts', () {
      final parts = ['ur:test/1-3/part1', 'ur:test/2-3/part2', 'ur:test/3-3/part3'];
      final animatedQR = AnimatedQR.fromEncodedParts(parts);
      
      expect(animatedQR.partCount, equals(3));
      expect(animatedQR.isSinglePart, isFalse);
      expect(animatedQR.currentPart, equals(parts[0]));
    });
    
    test('should handle single-part QR', () {
      final parts = ['ur:test/single-part'];
      final animatedQR = AnimatedQR.fromEncodedParts(parts);
      
      expect(animatedQR.partCount, equals(1));
      expect(animatedQR.isSinglePart, isTrue);
    });
  });
}
