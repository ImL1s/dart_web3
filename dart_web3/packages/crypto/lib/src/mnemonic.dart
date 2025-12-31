import 'dart:math';
import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';

import 'keccak.dart';

/// BIP-39 mnemonic phrase generation and validation.
class Mnemonic {
  Mnemonic._();

  /// Generates a new mnemonic phrase.
  static List<String> generate({int strength = 128}) {
    if (strength % 32 != 0 || strength < 128 || strength > 256) {
      throw ArgumentError('Strength must be 128, 160, 192, 224, or 256');
    }
    final random = Random.secure();
    final entropy = Uint8List(strength ~/ 8);
    for (var i = 0; i < entropy.length; i++) {
      entropy[i] = random.nextInt(256);
    }
    return _entropyToMnemonic(entropy);
  }

  /// Converts entropy bytes to a mnemonic phrase.
  static List<String> fromEntropy(Uint8List entropy) {
    if (entropy.length < 16 || entropy.length > 32 || entropy.length % 4 != 0) {
      throw ArgumentError('Invalid entropy length');
    }
    return _entropyToMnemonic(entropy);
  }

  /// Converts a mnemonic phrase to entropy bytes.
  static Uint8List toEntropy(List<String> words) {
    if (words.length < 12 || words.length > 24 || words.length % 3 != 0) {
      throw ArgumentError('Invalid mnemonic length');
    }
    final indices = <int>[];
    for (final word in words) {
      final index = _wordlist.indexOf(word.toLowerCase());
      if (index == -1) throw ArgumentError('Invalid word: $word');
      indices.add(index);
    }
    final bits = StringBuffer();
    for (final index in indices) {
      bits.write(index.toRadixString(2).padLeft(11, '0'));
    }
    final entropyBits = words.length * 11 * 32 ~/ 33;
    final entropyStr = bits.toString().substring(0, entropyBits);
    final entropy = Uint8List(entropyBits ~/ 8);
    for (var i = 0; i < entropy.length; i++) {
      entropy[i] = int.parse(entropyStr.substring(i * 8, i * 8 + 8), radix: 2);
    }
    final expectedMnemonic = _entropyToMnemonic(entropy);
    if (!_listEquals(expectedMnemonic, words)) {
      throw ArgumentError('Invalid mnemonic checksum');
    }
    return entropy;
  }

  /// Converts a mnemonic phrase to a seed.
  static Uint8List toSeed(List<String> words, {String passphrase = ''}) {
    final mnemonic = words.join(' ');
    final salt = 'mnemonic$passphrase';
    return _pbkdf2(
      Uint8List.fromList(mnemonic.codeUnits),
      Uint8List.fromList(salt.codeUnits),
      2048, 64,
    );
  }

  /// Validates a mnemonic phrase.
  static bool validate(List<String> words) {
    try { toEntropy(words); return true; } catch (_) { return false; }
  }

  static List<String> _entropyToMnemonic(Uint8List entropy) {
    final hash = Keccak256.hash(entropy);
    final checksumBits = entropy.length ~/ 4;
    final bits = StringBuffer();
    for (final byte in entropy) {
      bits.write(byte.toRadixString(2).padLeft(8, '0'));
    }
    for (var i = 0; i < checksumBits; i++) {
      final byteIndex = i ~/ 8;
      final bitIndex = 7 - (i % 8);
      bits.write((hash[byteIndex] >> bitIndex) & 1);
    }
    final bitString = bits.toString();
    final words = <String>[];
    for (var i = 0; i < bitString.length; i += 11) {
      final index = int.parse(bitString.substring(i, i + 11), radix: 2);
      words.add(_wordlist[index]);
    }
    return words;
  }

  static Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations, int keyLength) {
    final result = Uint8List(keyLength);
    final combined = BytesUtils.concat([password, salt]);
    var hash = Keccak256.hash(combined);
    for (var i = 0; i < iterations; i++) { hash = Keccak256.hash(hash); }
    var offset = 0;
    while (offset < keyLength) {
      final chunk = Keccak256.hash(BytesUtils.concat([hash, BytesUtils.intToBytes(offset)]));
      final copyLength = (keyLength - offset).clamp(0, 32);
      result.setRange(offset, offset + copyLength, chunk);
      offset += copyLength;
    }
    return result;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) return false;
    }
    return true;
  }

  static const _wordlist = <String>[