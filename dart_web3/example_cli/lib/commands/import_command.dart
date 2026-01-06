/// Import command - import wallet from mnemonic.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:bip39/bip39.dart' as bip39;

/// Import wallet command.
class ImportCommand {
  static ArgParser get parser => ArgParser()
    ..addOption('mnemonic',
        abbr: 'm', help: 'Mnemonic phrase (12 or 24 words)', mandatory: true)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  static Future<void> run(ArgResults args) async {
    if (args['help'] == true) {
      print('Import an existing wallet from mnemonic phrase.\n');
      print('Options:');
      print(parser.usage);
      return;
    }

    final mnemonic = args['mnemonic'] as String;
    final words = mnemonic.trim().split(RegExp(r'\s+'));

    if (words.length != 12 && words.length != 24) {
      print('Error: Mnemonic must be 12 or 24 words');
      exit(1);
    }

    if (!bip39.validateMnemonic(mnemonic)) {
      print('Error: Invalid mnemonic phrase');
      exit(1);
    }

    print('🔐 Importing wallet...\n');
    print('✅ Mnemonic validated successfully!');
    print('   Word count: ${words.length}');
    print('');
    print(
        'To view addresses: dart run bin/wallet_cli.dart address --mnemonic "$mnemonic"');
    print(
        'To check balance: dart run bin/wallet_cli.dart balance --mnemonic "$mnemonic"');
  }
}
