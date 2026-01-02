import 'dart:typed_data';

import 'bc_ur_registry.dart';
import 'cbor_encoder.dart';
import 'fountain_encoder.dart';

/// BC-UR encoder for creating UR-formatted QR codes
class BCUREncoder {
  static const String urPrefix = 'ur:';
  static const int defaultFragmentLength = 200; // Optimal for QR codes
  
  /// Encode data as a single UR string
  static String encodeSingle(String type, Uint8List data) {
    final encoded = _base32Encode(data);
    return '$urPrefix$type/$encoded';
  }
  
  /// Encode data as multiple UR parts for animated QR codes
  static List<String> encodeMultiple(String type, Uint8List data, {int? fragmentLength}) {
    final actualFragmentLength = fragmentLength ?? defaultFragmentLength;
    
    if (data.length <= actualFragmentLength) {
      return [encodeSingle(type, data)];
    }
    
    final encoder = FountainEncoder(data, actualFragmentLength);
    final parts = <String>[];
    
    // Generate enough parts for reliable reconstruction
    // Typically need 1.1x to 1.5x the number of fragments
    final targetParts = (encoder.fragmentCount * 1.3).ceil();
    
    for (var i = 0; i < targetParts; i++) {
      final part = encoder.nextPart();
      final urPart = _encodeFountainPart(type, part);
      parts.add(urPart);
    }
    
    return parts;
  }
  
  /// Encode an Ethereum sign request
  static String encodeEthSignRequest(EthSignRequest request) {
    final cbor = CBOREncoder.encode(request.toCbor());
    return encodeSingle('eth-sign-request', cbor);
  }
  
  /// Encode an Ethereum signature
  static String encodeEthSignature(EthSignature signature) {
    final cbor = CBOREncoder.encode(signature.toCbor());
    return encodeSingle('eth-signature', cbor);
  }
  
  /// Encode a fountain part as UR string
  static String _encodeFountainPart(String type, FountainPart part) {
    if (part.isSinglePart) {
      return encodeSingle(type, part.data);
    }
    
    // Multi-part format: ur:type/seqNum-seqLen/data
    final seqNum = part.sequenceNumber + 1; // 1-based for display
    final seqLen = part.fragmentCount;
    final encoded = _base32Encode(part.data);
    
    return '$urPrefix$type/$seqNum-$seqLen/$encoded';
  }
  
  /// Base32 encode using the BC-UR alphabet (Bech32 without '1', 'b', 'i', 'o')
  static String _base32Encode(Uint8List data) {
    const alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    
    if (data.isEmpty) return '';
    
    final bits = <int>[];
    for (final byte in data) {
      for (var i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }
    
    // Pad to multiple of 5 bits
    while (bits.length % 5 != 0) {
      bits.add(0);
    }
    
    final result = StringBuffer();
    for (var i = 0; i < bits.length; i += 5) {
      var value = 0;
      for (var j = 0; j < 5; j++) {
        value = (value << 1) | bits[i + j];
      }
      result.write(alphabet[value]);
    }
    
    return result.toString();
  }
}

/// BC-UR part information for multi-part messages
class BCURPart {
  
  BCURPart({
    required this.type,
    required this.sequenceNumber,
    required this.totalParts,
    required this.data,
  });
  final String type;
  final int sequenceNumber;
  final int totalParts;
  final Uint8List data;
  
  bool get isSinglePart => totalParts == 1;
  
  @override
  String toString() {
    return 'BCURPart(type: $type, seq: $sequenceNumber/$totalParts)';
  }
}
