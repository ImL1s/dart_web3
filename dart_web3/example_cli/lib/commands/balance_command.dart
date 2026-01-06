/// Balance command - check wallet balances.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:http/http.dart' as http;
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Balance check command.
class BalanceCommand {
  static ArgParser get parser => ArgParser()
    ..addOption('mnemonic',
        abbr: 'm', help: 'Mnemonic phrase (12 or 24 words)', mandatory: true)
    ..addOption('chain',
        abbr: 'c',
        help: 'Specific chain to check (ethereum, polygon, bitcoin, solana)',
        defaultsTo: 'all')
    ..addFlag('testnet', abbr: 't', help: 'Use testnet RPCs', defaultsTo: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  static Future<void> run(ArgResults args) async {
    if (args['help'] == true) {
      print('Check wallet balances across chains.\n');
      print('Options:');
      print(parser.usage);
      return;
    }

    final mnemonic = args['mnemonic'] as String;
    final chain = args['chain'] as String;
    final useTestnet = args['testnet'] as bool;

    if (!bip39.validateMnemonic(mnemonic)) {
      print('Error: Invalid mnemonic phrase');
      exit(1);
    }

    print('🔍 Fetching balances${useTestnet ? ' (Testnet)' : ''}...\n');

    final seed = bip39.mnemonicToSeed(mnemonic);
    final masterWallet = HDWallet.fromSeed(Uint8List.fromList(seed));

    // EVM address
    const evmPath = "m/44'/60'/0'/0/0";
    final evmWallet = masterWallet.derive(evmPath);
    final evmAddress = evmWallet.getAddress().hex;

    print('╔═══════════════════════════════════════════════════════════════╗');
    print('║                       WALLET BALANCES                         ║');
    print('╠═══════════════════════════════════════════════════════════════╣');

    if (chain == 'all' || chain == 'ethereum') {
      await _printEvmBalance(
          'Ethereum',
          evmAddress,
          useTestnet
              ? 'https://eth-sepolia.g.alchemy.com/v2/demo'
              : 'https://eth.llamarpc.com');
    }

    if (chain == 'all' || chain == 'polygon') {
      await _printEvmBalance(
          'Polygon',
          evmAddress,
          useTestnet
              ? 'https://rpc-mumbai.maticvigil.com'
              : 'https://polygon-rpc.com');
    }

    if (chain == 'all' || chain == 'bsc') {
      await _printEvmBalance(
          'BSC',
          evmAddress,
          useTestnet
              ? 'https://data-seed-prebsc-1-s1.binance.org:8545'
              : 'https://bsc-dataseed.binance.org');
    }

    print('╚═══════════════════════════════════════════════════════════════╝');
    print('');
    print('💡 Tip: Use --testnet for testnet balances');
  }

  static Future<void> _printEvmBalance(
      String chainName, String address, String rpcUrl) async {
    try {
      final client = http.Client();
      final response = await client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
        }),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final resultHex = json['result'] as String? ?? '0x0';
      final balanceWei = BigInt.parse(resultHex.substring(2), radix: 16);
      final balanceEth = _formatBalance(balanceWei, 18);

      final symbol = switch (chainName) {
        'Ethereum' => 'ETH',
        'Polygon' => 'MATIC',
        'BSC' => 'BNB',
        _ => 'ETH',
      };

      print(
          '║  🔷 ${chainName.padRight(12)} ${balanceEth.padLeft(15)} $symbol        ║');
    } catch (e) {
      print(
          '║  🔷 ${chainName.padRight(12)}        Error fetching             ║');
    }
  }

  static String _formatBalance(BigInt wei, int decimals) {
    if (wei == BigInt.zero) return '0.0000';
    final divisor = BigInt.from(10).pow(decimals);
    final whole = wei ~/ divisor;
    final fraction = wei % divisor;
    final fractionStr =
        fraction.toString().padLeft(decimals, '0').substring(0, 4);
    return '$whole.$fractionStr';
  }
}
