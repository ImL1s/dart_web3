import 'dart:typed_data';

import 'bc_ur_encoder.dart';
import 'bc_ur_registry.dart';
import 'cbor_decoder.dart';
import 'fountain_decoder.dart';
import 'fountain_encoder.dart';

/// BC-UR decoder for parsing UR-formatted QR codes
class BCURDecoder {
  static const String urPrefix = 'ur:';

  FountainDecoder? _fountainDecoder;
  String? _expectedType;

  /// Check if decoding is complete
  bool get isComplete => _fountainDecoder?.isComplete ?? false;

  /// Get decoding progress (0.0 to 1.0)
  double get progress => _fountainDecoder?.progress ?? 0.0;

  /// Get expected fragment count
  int? get expectedFragmentCount => _fountainDecoder?.expectedFragmentCount;

  /// Get solved fragment count
  int get solvedFragmentCount => _fountainDecoder?.solvedFragmentCount ?? 0;

  /// Decode a single UR string
  static BCURPart decodeSingle(String ur) {
    if (!ur.startsWith(urPrefix)) {
      throw FormatException('Invalid UR format: missing prefix');
    }

    final content = ur.substring(urPrefix.length);
    final parts = content.split('/');

    if (parts.length < 2) {
      throw FormatException('Invalid UR format: insufficient parts');
    }

    final type = parts[0];

    if (parts.length == 2) {
      // Single-part message: ur:type/data
      final data = _base32Decode(parts[1]);
      return BCURPart(
        type: type,
        sequenceNumber: 1,
        totalParts: 1,
        data: data,
      );
    } else if (parts.length == 3) {
      // Multi-part message: ur:type/seqNum-totalParts/data
      final seqInfo = parts[1].split('-');
      if (seqInfo.length != 2) {
        throw FormatException('Invalid sequence format');
      }

      final sequenceNumber = int.parse(seqInfo[0]);
      final totalParts = int.parse(seqInfo[1]);
      final data = _base32Decode(parts[2]);

      return BCURPart(
        type: type,
        sequenceNumber: sequenceNumber,
        totalParts: totalParts,
        data: data,
      );
    } else {
      throw FormatException('Invalid UR format: too many parts');
    }
  }

  /// Process a UR part for multi-part decoding
  /// Returns true if this part was useful
  bool receivePart(String ur) {
    final part = decodeSingle(ur);

    // Initialize type from first part
    _expectedType ??= part.type;

    // Validate type consistency
    if (part.type != _expectedType) {
      throw ArgumentError(
          'Type mismatch: expected $_expectedType, got ${part.type}');
    }

    // Handle single-part message
    if (part.isSinglePart) {
      _fountainDecoder = FountainDecoder(part.data.length);
      final fountainPart = FountainPart(
        sequenceNumber: 0,
        fragmentCount: 1,
        fragmentIndexes: [0],
        data: part.data,
      );
      return _fountainDecoder!.receivePart(fountainPart);
    }

    // Initialize fountain decoder if needed
    _fountainDecoder ??= FountainDecoder(part.data.length);

    // Convert to fountain part (sequence numbers are 0-based internally)
    final fountainPart = FountainPart(
      sequenceNumber: part.sequenceNumber - 1,
      fragmentCount: part.totalParts,
      fragmentIndexes: [part.sequenceNumber - 1], // Simple mapping for now
      data: part.data,
    );

    return _fountainDecoder!.receivePart(fountainPart);
  }

  /// Get the decoded result (only available when complete)
  Uint8List? getResult() {
    return _fountainDecoder?.getResult();
  }

  /// Decode an Ethereum sign request
  static EthSignRequest? decodeEthSignRequest(String ur) {
    final part = decodeSingle(ur);
    if (part.type != 'eth-sign-request') {
      throw ArgumentError('Expected eth-sign-request, got ${part.type}');
    }

    final cbor = CBORDecoder.decode(part.data);
    final intMap = _convertToIntMap(cbor as Map<dynamic, dynamic>);
    return EthSignRequest.fromCbor(intMap);
  }

  /// Decode an Ethereum signature
  static EthSignature? decodeEthSignature(String ur) {
    final part = decodeSingle(ur);
    if (part.type != 'eth-signature') {
      throw ArgumentError('Expected eth-signature, got ${part.type}');
    }

    final cbor = CBORDecoder.decode(part.data);
    final intMap = _convertToIntMap(cbor as Map<dynamic, dynamic>);
    return EthSignature.fromCbor(intMap);
  }

  /// Convert dynamic map to int-keyed map
  static Map<int, dynamic> _convertToIntMap(Map<dynamic, dynamic> map) {
    final result = <int, dynamic>{};
    map.forEach((key, value) {
      if (key is int) {
        result[key] = value;
      }
    });
    return result;
  }

  /// Base32 decode using the BC-UR alphabet
  static Uint8List _base32Decode(String encoded) {
    const alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final charToValue = <String, int>{};

    for (var i = 0; i < alphabet.length; i++) {
      charToValue[alphabet[i]] = i;
    }

    if (encoded.isEmpty) return Uint8List(0);

    final bits = <int>[];
    for (final char in encoded.split('')) {
      final value = charToValue[char];
      if (value == null) {
        throw FormatException('Invalid character in base32: $char');
      }

      for (var i = 4; i >= 0; i--) {
        bits.add((value >> i) & 1);
      }
    }

    // Remove padding bits
    while (bits.length % 8 != 0) {
      bits.removeLast();
    }

    final result = <int>[];
    for (var i = 0; i < bits.length; i += 8) {
      var byte = 0;
      for (var j = 0; j < 8; j++) {
        byte = (byte << 1) | bits[i + j];
      }
      result.add(byte);
    }

    return Uint8List.fromList(result);
  }

  /// Reset decoder state
  void reset() {
    _fountainDecoder?.reset();
    _fountainDecoder = null;
    _expectedType = null;
  }
}
