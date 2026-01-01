# dart_web3

[![Pub](https://img.shields.io/pub/v/dart_web3.svg)](https://pub.dev/packages/dart_web3)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A **comprehensive, pure Dart Web3 SDK** for EVM-compatible blockchains and multi-chain expansion (Solana, Bitcoin, Polkadot, etc.). This package is a meta-package that re-exports all 32 modular packages for ease of use.

## 🚀 Key Modules

By importing `dart_web3`, you gain access to:

- **EVM Core**: `core`, `crypto`, `abi`, `client`, `contract`.
- **Identity**: `ens`, `aa` (Account Abstraction), `reown`.
- **Finance**: `swap`, `bridge`, `staking`, `price`.
- **Infrastructure**: `provider`, `events`, `multicall`, `debug`, `mev`.
- **Hardware**: `ledger`, `trezor`, `keystone`, `bc_ur`, `mpc`.
- **Extensions**: `solana`, `polkadot`, `tron`, `ton`, `bitcoin`.

## 🏗️ Quick Start

```dart
import 'package:dart_web3/dart_web3.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
    chain: Chains.ethereum,
  );

  final block = await client.getBlockNumber();
  print('Latest Block: $block');
}
```

## 📖 Documentation

For detailed guides and advanced usage, please refer to:
- [Usage Guide](../USAGE_GUIDE.md)
- [Monorepo README](../../README.md)

## 📦 Installation

```yaml
dependencies:
  dart_web3: ^0.1.0
```
