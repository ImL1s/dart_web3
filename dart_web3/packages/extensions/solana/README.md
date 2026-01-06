# web3_universal_solana

![Web3 Universal Banner](https://raw.githubusercontent.com/ImL1s/dart_web3/master/art/web3_universal_banner.png)

<!-- Package not yet published to pub.dev -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Solana blockchain extension for the **Web3 Universal SDK**. Interact with Solana's high-performance network using pure Dart.

## Features

- ☀️ **Solana Native**: Support for PDAs (Program Derived Addresses) and SPL Tokens.
- 📝 **Versioned Transactions**: Full support for v0 Transactions and Address Lookup Tables (ALT).
- 🎨 **Metaplex**: Built-in decoding for Metaplex NFT metadata.
- 🌐 **RPC Client**: Comprehensive client for interacting with Solana's JSON-RPC API.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  web3_universal_solana: ^0.1.0
```

## Quick Start

```dart
import 'package:web3_universal_solana/web3_universal_solana.dart';

void main() async {
  final client = SolanaClient('https://api.mainnet-beta.solana.com');
  final balance = await client.getBalance('...');
  print('Balance: $balance lamports');
}
```

## Platform Support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
