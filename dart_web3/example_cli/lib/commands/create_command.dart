/// Create command - generate a new wallet.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:bip39/bip39.dart' as bip39;

/// Create wallet command.
class CreateCommand {
  static ArgParser get parser => ArgParser()
    ..addOption('strength',
        abbr: 's',
        help: 'Mnemonic strength (128=12 words, 256=24 words)',
        defaultsTo: '128')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  static Future<void> run(ArgResults args) async {
    if (args['help'] == true) {
      print('Create a new wallet with random mnemonic.\n');
      print('Options:');
      print(parser.usage);
      return;
    }

    final strength = int.tryParse(args['strength'] as String) ?? 128;
    if (strength != 128 && strength != 256) {
      print('Error: Strength must be 128 (12 words) or 256 (24 words)');
      exit(1);
    }

    print('🔐 Generating new wallet...\n');

    final mnemonic = bip39.generateMnemonic(strength: strength);

    print('✅ Wallet created successfully!\n');
    print('╔═══════════════════════════════════════════════════════════════╗');
    print('║                    MNEMONIC PHRASE                            ║');
    print('╠═══════════════════════════════════════════════════════════════╣');
    
    final words = mnemonic.split(' ');
    for (var i = 0; i < words.length; i += 3) {
      final line = words
          .skip(i)
          .take(3)
          .toList()
          .asMap()
          .entries
          .map((e) => '${(i + e.key + 1).toString().padLeft(2)}. ${e.value.padRight(10)}')
          .join('  ');
      print('║  $line  ║');
    }
    
    print('╚═══════════════════════════════════════════════════════════════╝');
    print('');
    print('⚠️  IMPORTANT: Write down these words and store them securely!');
    print('    Never share your mnemonic phrase with anyone.');
    print('');
    print('To view addresses: dart run bin/wallet_cli.dart address --mnemonic "$mnemonic"');
  }
}
