import 'dart:typed_data';

/// Pure Dart implementation of Base58 and Bech32 encoding.
///
/// This module provides encoding and decoding for:
/// - Base58 (used by Bitcoin legacy addresses, extended keys)
/// - Base58Check (Base58 with 4-byte checksum)
/// - Bech32 (BIP-173, used by SegWit v0 addresses)
/// - Bech32m (BIP-350, used by SegWit v1+ addresses)

// SHA-256 implementation for Base58Check (minimal inline version)
Uint8List _sha256(Uint8List data) {
  // Initial hash values
  final h = Uint32List.fromList([
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ]);

  // Round constants
  final k = Uint32List.fromList([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ]);

  // Pre-processing: adding padding bits
  final msgLen = data.length;
  final bitLen = msgLen * 8;
  final padLen = (56 - (msgLen + 1) % 64) % 64;
  final paddedLen = msgLen + 1 + padLen + 8;
  final padded = Uint8List(paddedLen);
  padded.setRange(0, msgLen, data);
  padded[msgLen] = 0x80;
  // Add length in bits as 64-bit big-endian
  for (int i = 0; i < 8; i++) {
    padded[paddedLen - 1 - i] = (bitLen >> (i * 8)) & 0xFF;
  }

  int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  // Process each 512-bit chunk
  final w = Uint32List(64);
  for (int chunk = 0; chunk < paddedLen; chunk += 64) {
    // Break chunk into sixteen 32-bit big-endian words
    for (int i = 0; i < 16; i++) {
      w[i] = (padded[chunk + i * 4] << 24) |
          (padded[chunk + i * 4 + 1] << 16) |
          (padded[chunk + i * 4 + 2] << 8) |
          padded[chunk + i * 4 + 3];
    }

    // Extend the first 16 words into the remaining 48 words
    for (int i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }

    // Initialize working variables
    int a = h[0], b = h[1], c = h[2], d = h[3];
    int e = h[4], f = h[5], g = h[6], hh = h[7];

    // Compression function main loop
    for (int i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (hh + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;

      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    // Add the compressed chunk to the current hash value
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }

  // Produce the final hash value (big-endian)
  final result = Uint8List(32);
  for (int i = 0; i < 8; i++) {
    result[i * 4] = (h[i] >> 24) & 0xFF;
    result[i * 4 + 1] = (h[i] >> 16) & 0xFF;
    result[i * 4 + 2] = (h[i] >> 8) & 0xFF;
    result[i * 4 + 3] = h[i] & 0xFF;
  }
  return result;
}

Uint8List _doubleSha256(Uint8List data) => _sha256(_sha256(data));

/// Base58 encoding and decoding.
///
/// Base58 is a binary-to-text encoding scheme used primarily for Bitcoin
/// addresses and extended keys. It uses 58 alphanumeric characters,
/// excluding visually similar characters (0, O, I, l).
class Base58 {
  Base58._();

  /// The Base58 alphabet (Bitcoin variant).
  static const String alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static final Map<String, int> _alphabetMap = {
    for (int i = 0; i < alphabet.length; i++) alphabet[i]: i,
  };

  /// Encodes bytes to Base58 string.
  static String encode(Uint8List data) {
    if (data.isEmpty) return '';

    // Count leading zeros
    int leadingZeros = 0;
    for (int byte in data) {
      if (byte == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }

    // Convert bytes to BigInt
    BigInt num = BigInt.zero;
    for (int byte in data) {
      num = num * BigInt.from(256) + BigInt.from(byte);
    }

    // Convert BigInt to Base58
    String result = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      result = alphabet[remainder.toInt()] + result;
      num = num ~/ BigInt.from(58);
    }

    // Add leading '1's for leading zeros
    return '1' * leadingZeros + result;
  }

  /// Decodes a Base58 string to bytes.
  static Uint8List decode(String encoded) {
    if (encoded.isEmpty) return Uint8List(0);

    // Count leading '1's (zeros)
    int leadingOnes = 0;
    for (int i = 0; i < encoded.length; i++) {
      if (encoded[i] == '1') {
        leadingOnes++;
      } else {
        break;
      }
    }

    // Convert Base58 to BigInt
    BigInt num = BigInt.zero;
    for (int i = 0; i < encoded.length; i++) {
      final char = encoded[i];
      final value = _alphabetMap[char];
      if (value == null) {
        throw FormatException('Invalid Base58 character: $char');
      }
      num = num * BigInt.from(58) + BigInt.from(value);
    }

    // Convert BigInt to bytes
    final bytes = <int>[];
    while (num > BigInt.zero) {
      bytes.insert(0, (num % BigInt.from(256)).toInt());
      num = num ~/ BigInt.from(256);
    }

    // Add leading zeros
    final result = Uint8List(leadingOnes + bytes.length);
    for (int i = 0; i < leadingOnes; i++) {
      result[i] = 0;
    }
    for (int i = 0; i < bytes.length; i++) {
      result[leadingOnes + i] = bytes[i];
    }

    return result;
  }
}

/// Base58Check encoding with checksum.
///
/// Adds a 4-byte double-SHA256 checksum to detect errors.
class Base58Check {
  Base58Check._();

  /// Encodes bytes with a 4-byte checksum.
  static String encode(Uint8List data) {
    final checksum = _doubleSha256(data).sublist(0, 4);
    final withChecksum = Uint8List(data.length + 4);
    withChecksum.setRange(0, data.length, data);
    withChecksum.setRange(data.length, data.length + 4, checksum);
    return Base58.encode(withChecksum);
  }

  /// Decodes and verifies the checksum.
  static Uint8List decode(String encoded) {
    final decoded = Base58.decode(encoded);
    if (decoded.length < 4) {
      throw FormatException('Base58Check string too short');
    }

    final data = decoded.sublist(0, decoded.length - 4);
    final checksum = decoded.sublist(decoded.length - 4);
    final expectedChecksum = _doubleSha256(data).sublist(0, 4);

    for (int i = 0; i < 4; i++) {
      if (checksum[i] != expectedChecksum[i]) {
        throw FormatException('Invalid Base58Check checksum');
      }
    }

    return data;
  }

  /// Encodes with a version byte prefix.
  static String encodeWithVersion(int version, Uint8List data) {
    final withVersion = Uint8List(1 + data.length);
    withVersion[0] = version;
    withVersion.setRange(1, 1 + data.length, data);
    return encode(withVersion);
  }

  /// Decodes and returns (version, data).
  static (int, Uint8List) decodeWithVersion(String encoded) {
    final decoded = decode(encoded);
    if (decoded.isEmpty) {
      throw FormatException('Empty Base58Check data');
    }
    return (decoded[0], decoded.sublist(1));
  }
}

/// Bech32 and Bech32m encoding (BIP-173 and BIP-350).
///
/// Used for SegWit addresses and other applications requiring
/// human-readable, error-detecting encoding.
class Bech32 {
  Bech32._();

  /// Bech32 character set.
  static const String charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static final Map<String, int> _charsetMap = {
    for (int i = 0; i < charset.length; i++) charset[i]: i,
  };

  /// Generator polynomial values for BCH code.
  static const List<int> _generator = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];

  /// Bech32 constant (BIP-173).
  static const int _bech32Const = 1;

  /// Bech32m constant (BIP-350).
  static const int _bech32mConst = 0x2bc830a3;

  /// Computes the Bech32 polymod.
  static int _polymod(List<int> values) {
    int chk = 1;
    for (int v in values) {
      int top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (int i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) {
          chk ^= _generator[i];
        }
      }
    }
    return chk;
  }

  /// Expands the HRP for checksum calculation.
  static List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (int c in hrp.codeUnits) {
      result.add(c >> 5);
    }
    result.add(0);
    for (int c in hrp.codeUnits) {
      result.add(c & 31);
    }
    return result;
  }

  /// Verifies the checksum.
  static bool _verifyChecksum(String hrp, List<int> data, int constant) {
    return _polymod([..._hrpExpand(hrp), ...data]) == constant;
  }

  /// Creates the checksum.
  static List<int> _createChecksum(String hrp, List<int> data, int constant) {
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    final polymod = _polymod(values) ^ constant;
    return [
      for (int i = 0; i < 6; i++) (polymod >> (5 * (5 - i))) & 31,
    ];
  }

  /// Encodes data to Bech32 format.
  ///
  /// [hrp] - Human-readable part (e.g., "bc" for Bitcoin mainnet)
  /// [data] - 5-bit values to encode
  /// [variant] - Bech32Variant.bech32 or Bech32Variant.bech32m
  static String encode(String hrp, List<int> data, Bech32Variant variant) {
    final combined = [
      ...data,
      ..._createChecksum(
        hrp,
        data,
        variant == Bech32Variant.bech32 ? _bech32Const : _bech32mConst,
      ),
    ];

    final result = StringBuffer(hrp.toLowerCase());
    result.write('1');
    for (int d in combined) {
      result.write(charset[d]);
    }
    return result.toString();
  }

  /// Decodes a Bech32 string.
  ///
  /// Returns (hrp, data, variant) or throws on error.
  static (String, List<int>, Bech32Variant) decode(String encoded) {
    // Check case consistency
    final hasLower = encoded.contains(RegExp(r'[a-z]'));
    final hasUpper = encoded.contains(RegExp(r'[A-Z]'));
    if (hasLower && hasUpper) {
      throw FormatException('Mixed case in Bech32 string');
    }

    final lowered = encoded.toLowerCase();

    // Find the separator
    final pos = lowered.lastIndexOf('1');
    if (pos < 1 || pos + 7 > lowered.length || lowered.length > 90) {
      throw FormatException('Invalid Bech32 string format');
    }

    final hrp = lowered.substring(0, pos);
    final dataStr = lowered.substring(pos + 1);

    // Validate HRP
    for (int c in hrp.codeUnits) {
      if (c < 33 || c > 126) {
        throw FormatException('Invalid character in HRP');
      }
    }

    // Decode data part
    final data = <int>[];
    for (int i = 0; i < dataStr.length; i++) {
      final value = _charsetMap[dataStr[i]];
      if (value == null) {
        throw FormatException('Invalid character in Bech32 data: ${dataStr[i]}');
      }
      data.add(value);
    }

    // Verify checksum
    if (_verifyChecksum(hrp, data, _bech32Const)) {
      return (hrp, data.sublist(0, data.length - 6), Bech32Variant.bech32);
    } else if (_verifyChecksum(hrp, data, _bech32mConst)) {
      return (hrp, data.sublist(0, data.length - 6), Bech32Variant.bech32m);
    } else {
      throw FormatException('Invalid Bech32 checksum');
    }
  }

  /// Converts 8-bit bytes to 5-bit values.
  static List<int> convertBits(
    List<int> data,
    int fromBits,
    int toBits, {
    bool pad = true,
  }) {
    int acc = 0;
    int bits = 0;
    final result = <int>[];
    final maxV = (1 << toBits) - 1;

    for (int value in data) {
      if (value < 0 || value >> fromBits != 0) {
        throw FormatException('Invalid value for bit conversion');
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxV);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxV);
      }
    } else {
      if (bits >= fromBits || ((acc << (toBits - bits)) & maxV) != 0) {
        throw FormatException('Invalid padding in Bech32 data');
      }
    }

    return result;
  }

  /// Encodes a SegWit address.
  ///
  /// [hrp] - "bc" for mainnet, "tb" for testnet
  /// [witnessVersion] - 0 for Bech32, 1+ for Bech32m
  /// [witnessProgram] - The witness program bytes
  static String encodeSegwit(
    String hrp,
    int witnessVersion,
    Uint8List witnessProgram,
  ) {
    if (witnessVersion < 0 || witnessVersion > 16) {
      throw ArgumentError('Invalid witness version: $witnessVersion');
    }
    if (witnessProgram.length < 2 || witnessProgram.length > 40) {
      throw ArgumentError(
        'Invalid witness program length: ${witnessProgram.length}',
      );
    }

    final data = [
      witnessVersion,
      ...convertBits(witnessProgram.toList(), 8, 5),
    ];

    final variant =
        witnessVersion == 0 ? Bech32Variant.bech32 : Bech32Variant.bech32m;
    return encode(hrp, data, variant);
  }

  /// Decodes a SegWit address.
  ///
  /// Returns (witnessVersion, witnessProgram).
  static (int, Uint8List) decodeSegwit(String hrp, String address) {
    final (decodedHrp, data, variant) = decode(address);

    if (decodedHrp != hrp.toLowerCase()) {
      throw FormatException(
        'HRP mismatch: expected $hrp, got $decodedHrp',
      );
    }

    if (data.isEmpty) {
      throw FormatException('Empty witness data');
    }

    final witnessVersion = data[0];
    if (witnessVersion < 0 || witnessVersion > 16) {
      throw FormatException('Invalid witness version: $witnessVersion');
    }

    // Check variant matches version
    if (witnessVersion == 0 && variant != Bech32Variant.bech32) {
      throw FormatException('Version 0 must use Bech32, not Bech32m');
    }
    if (witnessVersion != 0 && variant != Bech32Variant.bech32m) {
      throw FormatException('Version 1+ must use Bech32m, not Bech32');
    }

    final program = Uint8List.fromList(
      convertBits(data.sublist(1), 5, 8, pad: false),
    );

    if (program.length < 2 || program.length > 40) {
      throw FormatException('Invalid witness program length: ${program.length}');
    }

    // Version 0 requires 20 or 32 bytes
    if (witnessVersion == 0 && program.length != 20 && program.length != 32) {
      throw FormatException(
        'Invalid v0 witness program length: ${program.length}',
      );
    }

    return (witnessVersion, program);
  }
}

/// Bech32 encoding variants.
enum Bech32Variant {
  /// Original Bech32 (BIP-173), used for SegWit v0.
  bech32,

  /// Bech32m (BIP-350), used for SegWit v1+.
  bech32m,
}

/// Cosmos-style Bech32 address encoding.
///
/// Used by Cosmos SDK chains (Cosmos, Osmosis, Juno, etc.)
/// for account, validator, and other address types.
class CosmosBech32 {
  CosmosBech32._();

  /// Encodes bytes to a Cosmos Bech32 address.
  static String encode(String hrp, Uint8List data) {
    final converted = Bech32.convertBits(data.toList(), 8, 5);
    return Bech32.encode(hrp, converted, Bech32Variant.bech32);
  }

  /// Decodes a Cosmos Bech32 address to bytes.
  static Uint8List decode(String address) {
    final (_, data, _) = Bech32.decode(address);
    return Uint8List.fromList(Bech32.convertBits(data, 5, 8, pad: false));
  }

  /// Decodes and returns both HRP and data.
  static (String, Uint8List) decodeWithHrp(String address) {
    final (hrp, data, _) = Bech32.decode(address);
    return (hrp, Uint8List.fromList(Bech32.convertBits(data, 5, 8, pad: false)));
  }
}

/// Cardano-style Bech32 address encoding.
///
/// Used for Cardano Shelley-era addresses.
class CardanoBech32 {
  CardanoBech32._();

  /// Mainnet address prefix.
  static const String mainnetPrefix = 'addr';

  /// Testnet address prefix.
  static const String testnetPrefix = 'addr_test';

  /// Stake address prefix.
  static const String stakePrefix = 'stake';

  /// Encodes a Cardano address.
  static String encode(String hrp, Uint8List data) {
    final converted = Bech32.convertBits(data.toList(), 8, 5);
    return Bech32.encode(hrp, converted, Bech32Variant.bech32);
  }

  /// Decodes a Cardano address.
  static (String, Uint8List) decode(String address) {
    final (hrp, data, _) = Bech32.decode(address);
    return (hrp, Uint8List.fromList(Bech32.convertBits(data, 5, 8, pad: false)));
  }
}
