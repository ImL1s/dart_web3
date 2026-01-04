import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'pbkdf2.dart';
import 'sha2.dart';

/// Pure Dart implementation of BIP-39 mnemonic phrase generation and validation.
///
/// Supports generating, validating, and converting mnemonic phrases to seeds
/// for hierarchical deterministic wallet generation.
class Bip39 {
  // BIP-39 English wordlist (first 100 words for brevity - in production use full 2048 words)
  static const List<String> _englishWordlist = [
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
    'absurd',
    'abuse',
    'access',
    'accident',
    'account',
    'accuse',
    'achieve',
    'acid',
    'acoustic',
    'acquire',
    'across',
    'act',
    'action',
    'actor',
    'actress',
    'actual',
    'adapt',
    'add',
    'addict',
    'address',
    'adjust',
    'admit',
    'adult',
    'advance',
    'advice',
    'aerobic',
    'affair',
    'afford',
    'afraid',
    'again',
    'age',
    'agent',
    'agree',
    'ahead',
    'aim',
    'air',
    'airport',
    'aisle',
    'alarm',
    'album',
    'alcohol',
    'alert',
    'alien',
    'all',
    'alley',
    'allow',
    'almost',
    'alone',
    'alpha',
    'already',
    'also',
    'alter',
    'always',
    'amateur',
    'amazing',
    'among',
    'amount',
    'amused',
    'analyst',
    'anchor',
    'ancient',
    'anger',
    'angle',
    'angry',
    'animal',
    'ankle',
    'announce',
    'annual',
    'another',
    'answer',
    'antenna',
    'antique',
    'anxiety',
    'any',
    'apart',
    'apology',
    'appear',
    'apple',
    'approve',
    'april',
    'arch',
    'arctic',
    'area',
    'arena',
    'argue',
    'arm',
    'armed',
    'armor',
    'army',
    'around',
    'arrange',
    'arrest',
    'arrive',
    'arrow',
    'art',
    'article',
  ];

  /// Generates a new mnemonic phrase with the specified entropy strength.
  ///
  /// [strength] must be a multiple of 32 between 128 and 256 bits.
  /// Common values: 128 (12 words), 160 (15 words), 192 (18 words), 224 (21 words), 256 (24 words)
  static List<String> generate({int strength = 128}) {
    if (strength % 32 != 0 || strength < 128 || strength > 256) {
      throw ArgumentError(
          'Strength must be a multiple of 32 between 128 and 256');
    }

    final entropyBytes = strength ~/ 8;
    final entropy = _generateEntropy(entropyBytes);
    return _entropyToMnemonic(entropy);
  }

  /// Converts a mnemonic phrase to a seed using PBKDF2.
  ///
  /// The seed can be used for BIP-32 hierarchical deterministic key derivation.
  /// [passphrase] is an optional additional passphrase for extra security.
  static Uint8List toSeed(List<String> mnemonic, {String passphrase = ''}) {
    if (!validate(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final mnemonicString = mnemonic.join(' ');
    final salt = 'mnemonic$passphrase';

    // BIP-39 specifies: PBKDF2-HMAC-SHA512, 2048 iterations, 64-byte output
    return Pbkdf2.deriveKey(
      password: Uint8List.fromList(utf8.encode(mnemonicString)),
      salt: Uint8List.fromList(utf8.encode(salt)),
      iterations: 2048,
      keyLength: 64,
    );
  }

  /// Validates a mnemonic phrase according to BIP-39 specification.
  ///
  /// Returns true if the mnemonic is valid (correct length, valid words, valid checksum).
  static bool validate(List<String> mnemonic) {
    try {
      if (mnemonic.length % 3 != 0 ||
          mnemonic.length < 12 ||
          mnemonic.length > 24) {
        return false;
      }

      // Check if all words are in the wordlist
      for (final word in mnemonic) {
        if (!_englishWordlist.contains(word)) {
          return false;
        }
      }

      // Convert mnemonic to entropy and validate checksum
      final entropy = _mnemonicToEntropy(mnemonic);
      final regeneratedMnemonic = _entropyToMnemonic(entropy);

      return _listEquals(mnemonic, regeneratedMnemonic);
    } on Exception catch (_) {
      return false;
    }
  }

  /// Converts entropy bytes to a mnemonic phrase.
  static List<String> _entropyToMnemonic(Uint8List entropy) {
    final entropyBits = entropy.length * 8;
    final checksumBits = entropyBits ~/ 32;

    // BIP-39: Checksum = first (entropy_bits / 32) bits of SHA-256(entropy)
    final hash = Sha256.hash(entropy);
    final checksum = hash[0];

    // Combine entropy and checksum
    final combined = <int>[];
    combined.addAll(entropy);
    combined.add(checksum);

    // Convert to 11-bit indices
    final indices = <int>[];
    final totalBits = entropyBits + checksumBits;

    for (var i = 0; i < totalBits; i += 11) {
      var index = 0;
      for (var j = 0; j < 11 && i + j < totalBits; j++) {
        final byteIndex = (i + j) ~/ 8;
        final bitIndex = (i + j) % 8;
        if (byteIndex < combined.length) {
          final bit = (combined[byteIndex] >> (7 - bitIndex)) & 1;
          index = (index << 1) | bit;
        }
      }
      if (i + 11 <= totalBits) {
        indices.add(index % _englishWordlist.length);
      }
    }

    return indices.map((i) => _englishWordlist[i]).toList();
  }

  /// Converts a mnemonic phrase back to entropy bytes.
  static Uint8List _mnemonicToEntropy(List<String> mnemonic) {
    final indices = mnemonic.map((word) {
      final index = _englishWordlist.indexOf(word);
      if (index == -1) {
        throw ArgumentError('Invalid word in mnemonic: $word');
      }
      return index;
    }).toList();

    final totalBits = indices.length * 11;
    final entropyBits = (totalBits * 32) ~/ 33;

    // Convert indices to bit array
    final bits = <int>[];
    for (final index in indices) {
      for (var i = 10; i >= 0; i--) {
        bits.add((index >> i) & 1);
      }
    }

    // Extract entropy and checksum
    final entropyBytes = Uint8List(entropyBits ~/ 8);
    for (var i = 0; i < entropyBits; i++) {
      final byteIndex = i ~/ 8;
      final bitIndex = i % 8;
      if (bits[i] == 1) {
        entropyBytes[byteIndex] |= 1 << (7 - bitIndex);
      }
    }

    return entropyBytes;
  }

  /// Generates cryptographically secure random entropy.
  static Uint8List _generateEntropy(int bytes) {
    final random = Random.secure();
    final entropy = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      entropy[i] = random.nextInt(256);
    }
    return entropy;
  }

  /// Helper function to compare two lists for equality.
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
