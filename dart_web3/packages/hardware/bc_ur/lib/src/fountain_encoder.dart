import 'dart:math';
import 'dart:typed_data';

/// Fountain encoder for splitting large data into multiple QR code fragments
/// Based on the Luby Transform fountain code algorithm
class FountainEncoder {
  FountainEncoder(Uint8List data, this._fragmentLength, [int? seed])
      : _fragments = _splitData(data, _fragmentLength),
        _random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final int _fragmentLength;
  final List<Uint8List> _fragments;
  final Random _random;
  int _sequenceNumber = 0;

  /// Get the total number of fragments
  int get fragmentCount => _fragments.length;

  /// Get the fragment length
  int get fragmentLength => _fragmentLength;

  /// Check if this is a single-part message
  bool get isSinglePart => _fragments.length == 1;

  /// Generate the next fountain part
  FountainPart nextPart() {
    if (isSinglePart) {
      return FountainPart(
        sequenceNumber: _sequenceNumber++,
        fragmentCount: 1,
        fragmentIndexes: [0],
        data: _fragments[0],
      );
    }

    final degree = _chooseDegree();
    final indexes = _chooseFragments(degree);
    final data = _xorFragments(indexes);

    return FountainPart(
      sequenceNumber: _sequenceNumber++,
      fragmentCount: _fragments.length,
      fragmentIndexes: indexes,
      data: data,
    );
  }

  /// Split data into fragments of specified length
  static List<Uint8List> _splitData(Uint8List data, int fragmentLength) {
    final fragments = <Uint8List>[];

    for (var i = 0; i < data.length; i += fragmentLength) {
      final end =
          (i + fragmentLength < data.length) ? i + fragmentLength : data.length;
      final fragment = Uint8List(fragmentLength);

      // Copy data and pad with zeros if necessary
      final actualLength = end - i;
      fragment.setRange(0, actualLength, data, i);

      fragments.add(fragment);
    }

    return fragments;
  }

  /// Choose degree using ideal soliton distribution
  int _chooseDegree() {
    final fragmentCount = _fragments.length;

    // Simple degree selection - can be improved with proper soliton distribution
    if (_random.nextDouble() < 0.5) {
      return 1;
    } else if (_random.nextDouble() < 0.8) {
      return 2;
    } else {
      return _random.nextInt(fragmentCount) + 1;
    }
  }

  /// Choose random fragments for XOR
  List<int> _chooseFragments(int degree) {
    final indexes = <int>[];
    final fragmentCount = _fragments.length;

    while (indexes.length < degree) {
      final index = _random.nextInt(fragmentCount);
      if (!indexes.contains(index)) {
        indexes.add(index);
      }
    }

    indexes.sort();
    return indexes;
  }

  /// XOR selected fragments together
  Uint8List _xorFragments(List<int> indexes) {
    final result = Uint8List(_fragmentLength);

    for (final index in indexes) {
      final fragment = _fragments[index];
      for (var i = 0; i < _fragmentLength; i++) {
        result[i] ^= fragment[i];
      }
    }

    return result;
  }
}

/// Represents a single fountain part
class FountainPart {
  FountainPart({
    required this.sequenceNumber,
    required this.fragmentCount,
    required this.fragmentIndexes,
    required this.data,
  });
  final int sequenceNumber;
  final int fragmentCount;
  final List<int> fragmentIndexes;
  final Uint8List data;

  /// Check if this is a single-part message
  bool get isSinglePart => fragmentCount == 1;

  /// Get the degree (number of fragments XORed together)
  int get degree => fragmentIndexes.length;

  @override
  String toString() {
    return 'FountainPart(seq: $sequenceNumber, count: $fragmentCount, indexes: $fragmentIndexes, degree: $degree)';
  }
}
