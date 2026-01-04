# web3_universal_utxo

![Web3 Universal Banner](https://raw.githubusercontent.com/ImL1s/dart_web3/master/art/web3_universal_banner.png)

[![Pub Version](https://img.shields.io/pub/v/web3_universal_utxo)](https://pub.dev/packages/web3_universal_utxo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

UTXO chain support for the **Web3 Universal SDK**. This package provides comprehensive logic for Bitcoin, Litecoin, and Dogecoin protocols.

## Features

- 🟠 **Bitcoin Native**: Full support for Legacy (P2PKH), SegWit (P2WPKH), and Taproot (P2TR).
- 📜 **Script Engine**: Complete Bitcoin Script engine for parsing and compiling transaction scripts.
- 📦 **PSBT**: BIP-174 Partially Signed Bitcoin Transaction support for offline signing.
- ⚡ **RBF**: Helper functions for Replace-By-Fee and fee bumping.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  web3_universal_utxo: ^0.1.0
```

## Quick Start

```dart
import 'package:web3_universal_utxo/web3_universal_utxo.dart';

void main() {
  // Create a P2WPKH address from public key
  final pk = Uint8List.fromList([...]);
  final address = BitcoinAddress.p2wpkh(pk, network: BitcoinNetwork.mainnet);
  print('Address: ${address.toAddress()}');
}
```

## Platform Support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
