/// Address command - display addresses for all chains.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Address display command.
class AddressCommand {
  static ArgParser get parser => ArgParser()
    ..addOption('mnemonic',
        abbr: 'm', help: 'Mnemonic phrase (12 or 24 words)', mandatory: true)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  static Future<void> run(ArgResults args) async {
    if (args['help'] == true) {
      print('Display addresses for all supported chains.\n');
      print('Options:');
      print(parser.usage);
      return;
    }

    final mnemonic = args['mnemonic'] as String;

    if (!bip39.validateMnemonic(mnemonic)) {
      print('Error: Invalid mnemonic phrase');
      exit(1);
    }

    print('🔐 Deriving addresses...\n');

    final seed = bip39.mnemonicToSeed(mnemonic);
    final masterWallet = HDWallet.fromSeed(Uint8List.fromList(seed));

    // EVM (Ethereum, Polygon, BSC, etc.)
    const evmPath = "m/44'/60'/0'/0/0";
    final evmWallet = masterWallet.derive(evmPath);
    final evmAddress = evmWallet.getAddress();

    // Bitcoin (Native SegWit)
    const btcPath = "m/84'/0'/0'/0/0";
    final btcWallet = masterWallet.derive(btcPath);
    final btcPrivKey = btcWallet.getPrivateKey();
    final btcPubKey = Secp256k1.getPublicKey(btcPrivKey, compressed: true);
    final btcAddress = _deriveBitcoinAddress(btcPubKey);

    // Solana
    const solPath = "m/44'/501'/0'/0'";
    final solWallet = masterWallet.derive(solPath);
    final solPrivKey = solWallet.getPrivateKey();
    final solPubKey = Secp256k1.getPublicKey(solPrivKey, compressed: true);
    final solAddress = _base58Encode(solPubKey);

    print(
        '╔═══════════════════════════════════════════════════════════════════════════╗');
    print(
        '║                          WALLET ADDRESSES                                 ║');
    print(
        '╠═══════════════════════════════════════════════════════════════════════════╣');
    print(
        '║                                                                           ║');
    print(
        '║  🔷 EVM (Ethereum, Polygon, BSC, Arbitrum, etc.)                         ║');
    print('║     Path: $evmPath                                           ║');
    print('║     ${evmAddress.hex.padRight(58)}║');
    print(
        '║                                                                           ║');
    print(
        '║  🟠 Bitcoin (Native SegWit - bc1)                                        ║');
    print('║     Path: $btcPath                                          ║');
    print('║     ${btcAddress.padRight(58)}║');
    print(
        '║                                                                           ║');
    print(
        '║  🟣 Solana                                                               ║');
    print('║     Path: $solPath                                             ║');
    print('║     ${solAddress.padRight(58)}║');
    print(
        '║                                                                           ║');
    print(
        '╚═══════════════════════════════════════════════════════════════════════════╝');
  }

  /// Derive Bitcoin SegWit (bech32) address from public key.
  static String _deriveBitcoinAddress(Uint8List publicKey) {
    final sha256Hash = Sha256.hash(publicKey);
    final ripemd160Hash = Ripemd160.hash(sha256Hash);
    return _bech32Encode('bc', ripemd160Hash);
  }

  /// Bech32 encode for Bitcoin addresses.
  static String _bech32Encode(String hrp, Uint8List data) {
    final converted = _convertBits(data, 8, 5, true);
    if (converted == null) return 'Error encoding';

    const alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final checksum = _createBech32Checksum(hrp, converted);
    final combined = [...converted, ...checksum];

    return '$hrp${1}${combined.map((b) => alphabet[b]).join()}';
  }

  static List<int>? _convertBits(
      List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
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
    }

    return result;
  }

  static List<int> _createBech32Checksum(String hrp, List<int> data) {
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    final polymod = _bech32Polymod(values) ^ 1;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  static List<int> _hrpExpand(String hrp) {
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

  static int _bech32Polymod(List<int> values) {
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    int chk = 1;
    for (final v in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (var i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) {
          chk ^= gen[i];
        }
      }
    }
    return chk;
  }

  static String _base58Encode(Uint8List data) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var x = BigInt.zero;
    for (final byte in data) {
      x = x * BigInt.from(256) + BigInt.from(byte);
    }

    final result = StringBuffer();
    while (x > BigInt.zero) {
      final r = x % BigInt.from(58);
      x = x ~/ BigInt.from(58);
      result.write(alphabet[r.toInt()]);
    }

    // Add leading zeros
    for (final byte in data) {
      if (byte == 0) {
        result.write('1');
      } else {
        break;
      }
    }

    return result.toString().split('').reversed.join();
  }
}
