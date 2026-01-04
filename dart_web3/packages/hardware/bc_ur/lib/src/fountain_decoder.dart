import 'dart:typed_data';
import 'fountain_encoder.dart';

/// Fountain decoder for reconstructing data from multiple QR code fragments
/// Based on the Luby Transform fountain code algorithm
class FountainDecoder {
  FountainDecoder(this._fragmentLength);
  final int _fragmentLength;
  final Map<int, Uint8List> _solvedFragments = {};
  final List<FountainPart> _receivedParts = [];
  int? _expectedFragmentCount;
  bool _isComplete = false;

  /// Check if decoding is complete
  bool get isComplete => _isComplete;

  /// Get the expected fragment count (null if not yet determined)
  int? get expectedFragmentCount => _expectedFragmentCount;

  /// Get the number of solved fragments
  int get solvedFragmentCount => _solvedFragments.length;

  /// Get completion percentage (0.0 to 1.0)
  double get progress {
    if (_expectedFragmentCount == null) return 0;
    return _solvedFragments.length / _expectedFragmentCount!;
  }

  /// Process a received fountain part
  /// Returns true if this part was useful for decoding
  bool receivePart(FountainPart part) {
    if (_isComplete) return false;

    // Set expected fragment count from first part
    _expectedFragmentCount ??= part.fragmentCount;

    // Validate fragment count consistency
    if (part.fragmentCount != _expectedFragmentCount) {
      throw ArgumentError(
          'Inconsistent fragment count: expected $_expectedFragmentCount, got ${part.fragmentCount}');
    }

    // Handle single-part message
    if (part.isSinglePart) {
      _solvedFragments[0] = part.data;
      _isComplete = true;
      return true;
    }

    // Check if we already have all fragments referenced by this part
    final hasAllFragments =
        part.fragmentIndexes.every(_solvedFragments.containsKey);
    if (hasAllFragments) {
      return false; // This part doesn't provide new information
    }

    // Store the part for processing
    _receivedParts.add(part);

    // Try to solve fragments using Gaussian elimination
    final wasUseful = _processReceivedParts();

    // Check if we're complete
    if (_expectedFragmentCount != null &&
        _solvedFragments.length == _expectedFragmentCount) {
      _isComplete = true;
    }

    return wasUseful;
  }

  /// Get the reconstructed data (only available when complete)
  Uint8List? getResult() {
    if (!_isComplete || _expectedFragmentCount == null) return null;

    final result = BytesBuilder();
    for (var i = 0; i < _expectedFragmentCount!; i++) {
      final fragment = _solvedFragments[i];
      if (fragment == null) return null;
      result.add(fragment);
    }

    return result.toBytes();
  }

  /// Process received parts to solve fragments
  bool _processReceivedParts() {
    var madeProgress = false;

    // Keep processing until no more progress can be made
    var continueProcessing = true;
    while (continueProcessing) {
      continueProcessing = false;

      for (var i = 0; i < _receivedParts.length; i++) {
        final part = _receivedParts[i];

        // Find unsolved fragments in this part
        final unsolvedIndexes = part.fragmentIndexes
            .where((index) => !_solvedFragments.containsKey(index))
            .toList();

        if (unsolvedIndexes.length == 1) {
          // We can solve this fragment
          final targetIndex = unsolvedIndexes.first;
          final solvedData = _solveSingleFragment(part);

          _solvedFragments[targetIndex] = solvedData;
          _receivedParts.removeAt(i);

          madeProgress = true;
          continueProcessing = true;
          break;
        }
      }
    }

    return madeProgress;
  }

  /// Solve a single fragment from a part where all other fragments are known
  Uint8List _solveSingleFragment(FountainPart part) {
    final result = Uint8List.fromList(part.data);

    // XOR with all known fragments to isolate the unknown one
    for (final index in part.fragmentIndexes) {
      final knownFragment = _solvedFragments[index];
      if (knownFragment != null) {
        for (var i = 0; i < _fragmentLength; i++) {
          result[i] ^= knownFragment[i];
        }
      }
    }

    return result;
  }

  /// Reset the decoder state
  void reset() {
    _solvedFragments.clear();
    _receivedParts.clear();
    _expectedFragmentCount = null;
    _isComplete = false;
  }
}
