import 'dart:typed_data';

import 'sha2.dart';

/// Base58Check encoding used by Bitcoin and other UTXO chains.
///
/// Base58 is a binary-to-text encoding that avoids ambiguous characters
/// (0, O, I, l) and is used for Bitcoin addresses, WIF private keys,
/// and extended keys.
class Base58 {
  Base58._();

  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// Encodes bytes to Base58 string.
  static String encode(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Count leading zeros
    var leadingZeros = 0;
    for (final b in bytes) {
      if (b == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }

    // Convert to BigInt
    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }

    // Convert to base58
    final result = StringBuffer();
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      value = value ~/ BigInt.from(58);
      result.write(_alphabet[remainder]);
    }

    // Add leading '1's for leading zeros
    for (var i = 0; i < leadingZeros; i++) {
      result.write('1');
    }

    return result.toString().split('').reversed.join();
  }

  /// Decodes a Base58 string to bytes.
  static Uint8List decode(String input) {
    if (input.isEmpty) return Uint8List(0);

    // Count leading '1's
    var leadingOnes = 0;
    for (final c in input.split('')) {
      if (c == '1') {
        leadingOnes++;
      } else {
        break;
      }
    }

    // Convert from base58
    var value = BigInt.zero;
    for (final c in input.split('')) {
      final index = _alphabet.indexOf(c);
      if (index < 0) {
        throw FormatException('Invalid Base58 character: $c');
      }
      value = value * BigInt.from(58) + BigInt.from(index);
    }

    // Convert to bytes
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.insert(0, (value & BigInt.from(0xff)).toInt());
      value >>= 8;
    }

    // Add leading zeros
    for (var i = 0; i < leadingOnes; i++) {
      bytes.insert(0, 0);
    }

    return Uint8List.fromList(bytes);
  }

  /// Encodes bytes with Base58Check (includes version byte and checksum).
  static String encodeCheck(Uint8List payload, {int version = 0}) {
    final data = Uint8List(1 + payload.length);
    data[0] = version;
    data.setRange(1, data.length, payload);

    final checksum = _doubleSha256(data).sublist(0, 4);
    final full = Uint8List.fromList([...data, ...checksum]);

    return encode(full);
  }

  /// Decodes a Base58Check string to payload bytes.
  ///
  /// Returns the payload without version byte and checksum.
  /// Throws if checksum is invalid.
  static Uint8List decodeCheck(String input) {
    final decoded = decode(input);
    if (decoded.length < 5) {
      throw FormatException('Base58Check string too short');
    }

    final data = decoded.sublist(0, decoded.length - 4);
    final checksum = decoded.sublist(decoded.length - 4);
    final expectedChecksum = _doubleSha256(data).sublist(0, 4);

    for (var i = 0; i < 4; i++) {
      if (checksum[i] != expectedChecksum[i]) {
        throw FormatException('Invalid Base58Check checksum');
      }
    }

    // Return payload without version byte
    return data.sublist(1);
  }

  /// Gets the version byte from a Base58Check string.
  static int getVersion(String input) {
    final decoded = decode(input);
    if (decoded.isEmpty) {
      throw FormatException('Empty Base58Check string');
    }
    return decoded[0];
  }

  static Uint8List _doubleSha256(Uint8List data) {
    return Sha256.hash(Sha256.hash(data));
  }
}

/// Bech32 encoding (BIP-173) for SegWit addresses.
///
/// Also supports Bech32m (BIP-350) for Taproot addresses.
class Bech32 {
  Bech32._();

  static const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  static const int _bech32Const = 1;
  static const int _bech32mConst = 0x2bc830a3;

  /// Encodes a witness program to a Bech32 address.
  ///
  /// [hrp] is the human-readable part (e.g., 'bc' for mainnet, 'tb' for testnet).
  /// [witnessVersion] is 0 for SegWit v0, 1 for Taproot.
  /// [witnessProgram] is the hash (20 bytes for P2WPKH, 32 bytes for P2WSH/P2TR).
  static String encode(String hrp, int witnessVersion, Uint8List witnessProgram) {
    final useBech32m = witnessVersion > 0;
    final data = _convertBits(witnessProgram, 8, 5, true);
    final combined = [witnessVersion, ...data];
    final checksum = _createChecksum(hrp, combined, useBech32m);

    final result = StringBuffer(hrp);
    result.write('1');
    for (final d in [...combined, ...checksum]) {
      result.write(_charset[d]);
    }

    return result.toString();
  }

  /// Encodes data to Bech32 address without version byte.
  static String encodeGeneric(String hrp, Uint8List data) {
    // Cosmos uses Behc32 (original constant 1)
    final values = _convertBits(data, 8, 5, true);
    final checksum = _createChecksum(hrp, values, false); // Always false for generic Bech32? Or param?
    // Usually generic libraries use constant 1 (Bech32).

    final result = StringBuffer(hrp);
    result.write('1');
    for (final d in [...values, ...checksum]) {
      result.write(_charset[d]);
    }
    return result.toString();
  }

  /// Decodes a Bech32/Bech32m address.
  ///
  /// Returns (hrp, witnessVersion, witnessProgram).
  static ({String hrp, int witnessVersion, Uint8List witnessProgram}) decode(String address) {
    final lower = address.toLowerCase();
    final upper = address.toUpperCase();

    if (address != lower && address != upper) {
      throw FormatException('Mixed case in Bech32 address');
    }

    final pos = lower.lastIndexOf('1');
    if (pos < 1 || pos + 7 > lower.length || lower.length > 90) {
      throw FormatException('Invalid Bech32 format');
    }

    final hrp = lower.substring(0, pos);
    final dataStr = lower.substring(pos + 1);

    final data = <int>[];
    for (final c in dataStr.split('')) {
      final index = _charset.indexOf(c);
      if (index < 0) {
        throw FormatException('Invalid Bech32 character: $c');
      }
      data.add(index);
    }

    // Try Bech32m first, then Bech32
    var useBech32m = true;
    if (!_verifyChecksum(hrp, data, true)) {
      if (!_verifyChecksum(hrp, data, false)) {
        throw FormatException('Invalid Bech32 checksum');
      }
      useBech32m = false;
    }

    final values = data.sublist(0, data.length - 6);
    if (values.isEmpty) {
      throw FormatException('Empty Bech32 data');
    }

    final witnessVersion = values[0];
    if (witnessVersion > 16) {
      throw FormatException('Invalid witness version: $witnessVersion');
    }

    // Bech32m required for v1+
    if (witnessVersion == 0 && useBech32m) {
      throw FormatException('Bech32m used for witness v0');
    }
    if (witnessVersion > 0 && !useBech32m) {
      throw FormatException('Bech32 used for witness v$witnessVersion');
    }

    final program = _convertBits(values.sublist(1), 5, 8, false);
    if (program.length < 2 || program.length > 40) {
      throw FormatException('Invalid witness program length');
    }
    if (witnessVersion == 0 && program.length != 20 && program.length != 32) {
      throw FormatException('Invalid v0 witness program length');
    }
    if (witnessVersion == 1 && program.length != 32) {
      throw FormatException('Invalid v1 witness program length');
    }

    return (
      hrp: hrp,
      witnessVersion: witnessVersion,
      witnessProgram: Uint8List.fromList(program),
    );
  }

  /// Decodes a generic Bech32 address.
  /// Returns (hrp, data).
  static ({String hrp, Uint8List data}) decodeGeneric(String address) {
    final lower = address.toLowerCase();
    final upper = address.toUpperCase();

    if (address != lower && address != upper) {
      throw FormatException('Mixed case in Bech32 address');
    }

    final pos = lower.lastIndexOf('1');
    if (pos < 1 || pos + 7 > lower.length || lower.length > 90) {
      throw FormatException('Invalid Bech32 format');
    }

    final hrp = lower.substring(0, pos);
    final dataStr = lower.substring(pos + 1);

    final data = <int>[];
    for (final c in dataStr.split('')) {
      final index = _charset.indexOf(c);
      if (index < 0) {
        throw FormatException('Invalid Bech32 character: $c');
      }
      data.add(index);
    }

    // Use constant 1 (Bech32)
    if (!_verifyChecksum(hrp, data, false)) {
        throw FormatException('Invalid Bech32 checksum');
    }

    final values = data.sublist(0, data.length - 6);
    if (values.isEmpty) {
        // Empty data allowed? Maybe. But usually not.
    }
    
    final program = _convertBits(values, 5, 8, false);
    return (hrp: hrp, data: Uint8List.fromList(program));
  }

  static List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        throw FormatException('Invalid value in convertBits');
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      throw FormatException('Invalid padding in convertBits');
    }

    return result;
  }

  static int _polymod(List<int> values) {
    const generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    var chk = 1;
    for (final v in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (var i = 0; i < 5; i++) {
        if (((top >> i) & 1) != 0) {
          chk ^= generator[i];
        }
      }
    }
    return chk;
  }

  static List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (final c in hrp.split('')) {
      result.add(c.codeUnitAt(0) >> 5);
    }
    result.add(0);
    for (final c in hrp.split('')) {
      result.add(c.codeUnitAt(0) & 31);
    }
    return result;
  }

  static bool _verifyChecksum(String hrp, List<int> data, bool bech32m) {
    final constant = bech32m ? _bech32mConst : _bech32Const;
    return _polymod([..._hrpExpand(hrp), ...data]) == constant;
  }

  static List<int> _createChecksum(String hrp, List<int> data, bool bech32m) {
    final constant = bech32m ? _bech32mConst : _bech32Const;
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    final polymod = _polymod(values) ^ constant;
    final result = <int>[];
    for (var i = 0; i < 6; i++) {
      result.add((polymod >> (5 * (5 - i))) & 31);
    }
    return result;
  }
}
