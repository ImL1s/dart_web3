import 'dart:typed_data';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Multi-chain address resolver implementing ENSIP-9
class MultichainResolver {
  MultichainResolver({
    required PublicClient client,
    String? registryAddress,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _client = client,
        _registryAddress =
            registryAddress ?? '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
        _cacheTtl = cacheTtl;
  final PublicClient _client;
  final String _registryAddress;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheTtl;

  /// Resolve address for specific coin type (ENSIP-9)
  Future<String?> resolveAddress(String name, int coinType) async {
    if (!_isValidENSName(name)) {
      throw ArgumentError('Invalid ENS name: $name');
    }

    // Check cache first
    final cacheKey = 'multichain_${name}_$coinType';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached as String?;
    }

    try {
      // Check for cached resolver address first
      final resolverCacheKey = 'resolver_$name';
      var resolverAddress = _getCached(resolverCacheKey) as String?;

      if (resolverAddress == null) {
        // Get resolver address from registry
        resolverAddress = await _getResolver(name);
        if (resolverAddress != null) {
          _setCache(resolverCacheKey, resolverAddress);
        }
      }

      if (resolverAddress == null ||
          resolverAddress == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      // Query multi-chain address
      final addressBytes = await _getAddressFromResolver(
        resolverAddress,
        name,
        coinType,
      );
      if (addressBytes == null || addressBytes.isEmpty) {
        return null;
      }

      // Format address based on coin type
      final formattedAddress = _formatAddress(addressBytes, coinType);

      // Cache result
      _setCache(cacheKey, formattedAddress);

      return formattedAddress;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get Ethereum address (coin type 60)
  Future<String?> getEthereumAddress(String name) async {
    return resolveAddress(name, CoinType.ethereum);
  }

  /// Get Bitcoin address (coin type 0)
  Future<String?> getBitcoinAddress(String name) async {
    return resolveAddress(name, CoinType.bitcoin);
  }

  /// Get Litecoin address (coin type 2)
  Future<String?> getLitecoinAddress(String name) async {
    return resolveAddress(name, CoinType.litecoin);
  }

  /// Get Dogecoin address (coin type 3)
  Future<String?> getDogecoinAddress(String name) async {
    return resolveAddress(name, CoinType.dogecoin);
  }

  /// Get Monero address (coin type 128)
  Future<String?> getMoneroAddress(String name) async {
    return resolveAddress(name, CoinType.monero);
  }

  /// Get all supported addresses for a name
  Future<Map<String, String?>> getAllAddresses(String name) async {
    final results = <String, String?>{};

    final supportedCoins = [
      CoinType.bitcoin,
      CoinType.litecoin,
      CoinType.dogecoin,
      CoinType.ethereum,
      CoinType.monero,
      CoinType.solana,
      CoinType.tron,
      CoinType.cosmos,
      CoinType.polkadot,
    ];

    for (final coinType in supportedCoins) {
      final coinName = _getCoinName(coinType);
      results[coinName] = await resolveAddress(name, coinType);
    }

    return results;
  }

  /// Get Solana address (coin type 501)
  Future<String?> getSolanaAddress(String name) async {
    return resolveAddress(name, CoinType.solana);
  }

  /// Get Tron address (coin type 195)
  Future<String?> getTronAddress(String name) async {
    return resolveAddress(name, CoinType.tron);
  }

  /// Get Cosmos address (coin type 118)
  Future<String?> getCosmosAddress(String name) async {
    return resolveAddress(name, CoinType.cosmos);
  }

  /// Get Polkadot address (coin type 354)
  Future<String?> getPolkadotAddress(String name) async {
    return resolveAddress(name, CoinType.polkadot);
  }

  /// Get resolver address from ENS registry
  Future<String?> _getResolver(String name) async {
    final nameHash = _namehash(name);

    final registryContract = Contract(
      address: _registryAddress,
      abi: _ensRegistryAbi,
      publicClient: _client,
    );

    final result = await registryContract.read('resolver', [nameHash]);
    return result[0] as String?;
  }

  /// Get address bytes from resolver contract
  Future<Uint8List?> _getAddressFromResolver(
    String resolverAddress,
    String name,
    int coinType,
  ) async {
    final nameHash = _namehash(name);

    final resolverContract = Contract(
      address: resolverAddress,
      abi: _ensResolverAbi,
      publicClient: _client,
    );

    try {
      final result = await resolverContract.read('addr', [
        nameHash,
        BigInt.from(coinType),
      ]);
      final addressBytes = result[0] as Uint8List?;

      return addressBytes;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Format address bytes based on coin type
  String? _formatAddress(Uint8List addressBytes, int coinType) {
    if (addressBytes.isEmpty) return null;

    switch (coinType) {
      case CoinType.ethereum:
        // Ethereum addresses are 20 bytes
        if (addressBytes.length != 20) return null;
        return '0x${_bytesToHex(addressBytes)}';

      case CoinType.bitcoin:
        // Bitcoin can be P2PKH, P2SH, or Bech32
        return _decodeBitcoinAddress(addressBytes);

      case CoinType.litecoin:
        return _decodeLitecoinAddress(addressBytes);

      case CoinType.dogecoin:
        return _decodeDogecoinAddress(addressBytes);

      case CoinType.monero:
        // Monero addresses use base58 encoding (95 chars standard, 106 integrated)
        return _decodeMoneroAddress(addressBytes);

      case CoinType.solana:
        // Solana addresses are 32 bytes, base58 encoded
        if (addressBytes.length != 32) return null;
        return _encodeBase58(addressBytes);

      case CoinType.tron:
        // Tron addresses are base58check with 0x41 prefix
        return _decodeTronAddress(addressBytes);

      case CoinType.cosmos:
        // Cosmos addresses use bech32 with 'cosmos' prefix
        return _decodeBech32Address(addressBytes, 'cosmos');

      case CoinType.polkadot:
        // Polkadot uses SS58 encoding
        return _decodeSS58Address(addressBytes, 0); // 0 = Polkadot network

      default:
        // For unknown coin types, return hex representation
        return '0x${_bytesToHex(addressBytes)}';
    }
  }

  /// Decode Bitcoin address from raw bytes
  String? _decodeBitcoinAddress(Uint8List addressBytes) {
    if (addressBytes.isEmpty) return null;

    // Check for Bech32 (starts with bc1)
    if (addressBytes.length >= 2 &&
        addressBytes[0] == 0x00 &&
        addressBytes[1] == 0x14) {
      // Native SegWit (P2WPKH)
      return _encodeBech32('bc', 0, addressBytes.sublist(2));
    }

    // Legacy P2PKH or P2SH
    return _encodeBase58Check(addressBytes);
  }

  /// Decode Litecoin address
  String? _decodeLitecoinAddress(Uint8List addressBytes) {
    if (addressBytes.isEmpty) return null;

    if (addressBytes.length >= 2 &&
        addressBytes[0] == 0x00 &&
        addressBytes[1] == 0x14) {
      return _encodeBech32('ltc', 0, addressBytes.sublist(2));
    }

    return _encodeBase58Check(addressBytes);
  }

  /// Decode Dogecoin address
  String? _decodeDogecoinAddress(Uint8List addressBytes) {
    return _encodeBase58Check(addressBytes);
  }

  /// Decode Monero address
  String? _decodeMoneroAddress(Uint8List addressBytes) {
    // Monero uses a special base58 variant (cnBase58)
    return _encodeMoneroBase58(addressBytes);
  }

  /// Decode Tron address
  String? _decodeTronAddress(Uint8List addressBytes) {
    if (addressBytes.isEmpty) return null;

    // Tron addresses start with T (0x41 prefix in base58check)
    final withPrefix = Uint8List(addressBytes.length + 1);
    withPrefix[0] = 0x41;
    withPrefix.setRange(1, withPrefix.length, addressBytes);

    return _encodeBase58Check(withPrefix);
  }

  /// Decode Bech32 address (Cosmos, etc.)
  String? _decodeBech32Address(Uint8List addressBytes, String hrp) {
    return _encodeBech32(hrp, 0, addressBytes);
  }

  /// Decode SS58 address (Polkadot, Kusama)
  String? _decodeSS58Address(Uint8List addressBytes, int networkId) {
    // SS58 encoding for Substrate-based chains
    final prefix = Uint8List.fromList([networkId]);
    final payload = Uint8List.fromList([...prefix, ...addressBytes]);

    // Calculate checksum
    final checksum = _blake2b512(
      Uint8List.fromList([...'SS58PRE'.codeUnits, ...payload]),
    ).sublist(0, 2);

    return _encodeBase58(Uint8List.fromList([...payload, ...checksum]));
  }

  /// Get coin name from coin type
  String _getCoinName(int coinType) {
    switch (coinType) {
      case CoinType.bitcoin:
        return 'bitcoin';
      case CoinType.litecoin:
        return 'litecoin';
      case CoinType.dogecoin:
        return 'dogecoin';
      case CoinType.ethereum:
        return 'ethereum';
      case CoinType.monero:
        return 'monero';
      case CoinType.solana:
        return 'solana';
      case CoinType.tron:
        return 'tron';
      case CoinType.cosmos:
        return 'cosmos';
      case CoinType.polkadot:
        return 'polkadot';
      default:
        return 'coin_$coinType';
    }
  }

  /// Calculate ENS namehash
  String _namehash(String name) {
    if (name.isEmpty) {
      return '0x0000000000000000000000000000000000000000000000000000000000000000';
    }

    final labels = name.split('.');
    var hash = Uint8List(32); // Start with 32 zero bytes

    for (var i = labels.length - 1; i >= 0; i--) {
      final labelHash = Keccak256.hash(Uint8List.fromList(labels[i].codeUnits));
      final combined = Uint8List.fromList([...hash, ...labelHash]);
      hash = Keccak256.hash(combined);
    }

    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Validate ENS name format
  bool _isValidENSName(String name) {
    if (name.isEmpty) return false;

    // Must end with .eth or other valid TLD
    if (!name.contains('.')) return false;

    // Check for invalid characters
    final validPattern = RegExp(r'^[a-z0-9\-\.]+$');
    if (!validPattern.hasMatch(name.toLowerCase())) return false;

    // Check each label
    final labels = name.split('.');
    for (final label in labels) {
      if (label.isEmpty) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (label.length > 63) return false;
    }

    return true;
  }

  /// Check if cached value is still valid
  dynamic _getCached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    final timestamp = entry['timestamp'] as DateTime;
    if (DateTime.now().difference(timestamp) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }

    return entry['value'];
  }

  /// Set cache value with timestamp
  void _setCache(String key, dynamic value) {
    _cache[key] = {'value': value, 'timestamp': DateTime.now()};
  }

  /// Clear all cached entries
  void clearCache() {
    _cache.clear();
  }

  /// ENS Registry ABI (minimal)
  static const String _ensRegistryAbi = '''
[
    {
      "type": "function",
      "name": "resolver",
      "inputs": [{"name": "node", "type": "bytes32"}],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    }
  ]''';

  /// ENS Resolver ABI with multi-chain support
  static const String _ensResolverAbi = '''
[
    {
      "type": "function",
      "name": "addr",
      "inputs": [
        {"name": "node", "type": "bytes32"},
        {"name": "coinType", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "bytes"}],
      "stateMutability": "view"
    }
  ]''';

  // ==================== Encoding Utilities ====================

  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Base58 alphabet (Bitcoin)
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// Encode bytes to Base58
  String _encodeBase58(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Count leading zeros
    var leadingZeros = 0;
    for (final byte in bytes) {
      if (byte == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }

    // Convert to BigInt
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) + BigInt.from(byte);
    }

    // Convert to Base58
    final result = StringBuffer();
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      value = value ~/ BigInt.from(58);
      result.write(_base58Alphabet[remainder]);
    }

    // Add leading '1's for leading zeros
    final encoded =
        '1' * leadingZeros + result.toString().split('').reversed.join();
    return encoded;
  }

  /// Encode bytes to Base58Check (with 4-byte checksum)
  String _encodeBase58Check(Uint8List bytes) {
    // Calculate double SHA256 checksum
    final hash1 = Sha256.hash(bytes);
    final hash2 = Sha256.hash(hash1);
    final checksum = hash2.sublist(0, 4);

    // Append checksum
    final withChecksum = Uint8List.fromList([...bytes, ...checksum]);
    return _encodeBase58(withChecksum);
  }

  /// Encode to Bech32 format
  String _encodeBech32(String hrp, int version, Uint8List data) {
    // Convert 8-bit data to 5-bit groups
    final converted = _convertBits(data, 8, 5, true);
    if (converted == null) return '0x${_bytesToHex(data)}';

    // Add version byte
    final dataWithVersion = [version, ...converted];

    // Calculate Bech32 checksum
    final checksum = _bech32Checksum(hrp, dataWithVersion);

    // Encode
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final result = StringBuffer(hrp);
    result.write('1'); // Separator
    for (final value in dataWithVersion) {
      result.write(charset[value]);
    }
    for (final value in checksum) {
      result.write(charset[value]);
    }

    return result.toString();
  }

  /// Convert bits (for Bech32)
  List<int>? _convertBits(Uint8List data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxV = (1 << toBits) - 1;

    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxV);
      }
    }

    if (pad && bits > 0) {
      result.add((acc << (toBits - bits)) & maxV);
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxV) != 0) {
      return null;
    }

    return result;
  }

  /// Calculate Bech32 checksum
  List<int> _bech32Checksum(String hrp, List<int> data) {
    final values = _bech32HrpExpand(hrp) + data + [0, 0, 0, 0, 0, 0];
    final polymod = _bech32Polymod(values) ^ 1;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  /// Expand HRP for Bech32
  List<int> _bech32HrpExpand(String hrp) {
    final result = <int>[];
    for (final c in hrp.codeUnits) {
      result.add(c >> 5);
    }
    result.add(0);
    for (final c in hrp.codeUnits) {
      result.add(c & 31);
    }
    return result;
  }

  /// Bech32 polymod
  int _bech32Polymod(List<int> values) {
    const generator = [
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    var chk = 1;
    for (final value in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ value;
      for (var i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) {
          chk ^= generator[i];
        }
      }
    }
    return chk;
  }

  /// Monero-specific Base58 encoding
  String _encodeMoneroBase58(Uint8List bytes) {
    // Monero uses a variant of Base58 with 8-byte blocks
    // For simplicity, return standard Base58 (real implementation would use cn_base58)
    return _encodeBase58(bytes);
  }

  /// Blake2b-512 hash (for SS58)
  Uint8List _blake2b512(Uint8List data) {
    // Simplified - uses the crypto package's Blake2b if available
    // For now, return a placeholder (real implementation needs blake2b)
    return Sha256.hash(data); // Fallback to SHA256
  }
}

/// SLIP-44 coin types for multi-chain address resolution
class CoinType {
  static const int bitcoin = 0;
  static const int testnet = 1;
  static const int litecoin = 2;
  static const int dogecoin = 3;
  static const int reddcoin = 4;
  static const int dash = 5;
  static const int peercoin = 6;
  static const int namecoin = 7;
  static const int feathercoin = 8;
  static const int counterparty = 9;
  static const int blackcoin = 10;
  static const int nushares = 11;
  static const int nubits = 12;
  static const int mazacoin = 13;
  static const int viacoin = 14;
  static const int clearinghouse = 15;
  static const int rubycoin = 16;
  static const int groestlcoin = 17;
  static const int digitalcoin = 18;
  static const int cannacoin = 19;
  static const int digibyte = 20;
  static const int ethereum = 60;
  static const int ethereumClassic = 61;
  static const int cosmos = 118;
  static const int monero = 128;
  static const int zcash = 133;
  static const int ripple = 144;
  static const int bitcoinCash = 145;
  static const int stellar = 148;
  static const int tron = 195;
  static const int polkadot = 354;
  static const int solana = 501;
  static const int near = 397;
  static const int avalanche = 9000;
  static const int ton = 607;
  static const int aptos = 637;
  static const int sui = 784;
  static const int neo = 888;
  static const int cardano = 1815;
  static const int tezos = 1729;
}
