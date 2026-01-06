/// CLI Wallet Demo - Main Entry Point
///
/// A command-line interface for the web3_universal SDK demonstrating
/// multi-chain wallet operations.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'package:example_cli/commands/create_command.dart';
import 'package:example_cli/commands/import_command.dart';
import 'package:example_cli/commands/balance_command.dart';
import 'package:example_cli/commands/send_command.dart';
import 'package:example_cli/commands/address_command.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('create', CreateCommand.parser)
    ..addCommand('import', ImportCommand.parser)
    ..addCommand('balance', BalanceCommand.parser)
    ..addCommand('send', SendCommand.parser)
    ..addCommand('address', AddressCommand.parser)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  try {
    final results = parser.parse(arguments);

    if (results['help'] == true || results.command == null) {
      _printUsage(parser);
      return;
    }

    switch (results.command!.name) {
      case 'create':
        await CreateCommand.run(results.command!);
        break;
      case 'import':
        await ImportCommand.run(results.command!);
        break;
      case 'balance':
        await BalanceCommand.run(results.command!);
        break;
      case 'send':
        await SendCommand.run(results.command!);
        break;
      case 'address':
        await AddressCommand.run(results.command!);
        break;
      default:
        _printUsage(parser);
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('''
╔═══════════════════════════════════════════════════════════════╗
║                 Web3 Universal CLI Wallet                     ║
╚═══════════════════════════════════════════════════════════════╝

A multi-chain wallet command-line interface powered by web3_universal SDK.

Usage: dart run bin/wallet_cli.dart <command> [options]

Commands:
  create    Generate a new wallet with random mnemonic
  import    Import wallet from existing mnemonic phrase
  balance   Check wallet balances across all chains
  send      Send transaction on specified chain
  address   Display addresses for all supported chains

Options:
${parser.usage}

Examples:
  dart run bin/wallet_cli.dart create
  dart run bin/wallet_cli.dart import --mnemonic "word1 word2 ..."
  dart run bin/wallet_cli.dart balance --mnemonic "word1 word2 ..."
  dart run bin/wallet_cli.dart send --to 0x... --amount 0.1 --chain ethereum
''');
}
