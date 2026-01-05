# dart_web3_compat

![Web3 Universal Banner](https://raw.githubusercontent.com/ImL1s/dart_web3/master/art/web3_universal_banner.png)

[![Pub Version](https://img.shields.io/pub/v/web3_universal_compat)](https://pub.dev/packages/web3_universal_compat)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A drop-in compatibility layer for migrating from `web3dart` to the **Web3 Universal SDK**. This package preserves the legacy API while powering it with modern, secure, and authenticated cryptographic primitives from `web3_universal_crypto`.

## Features

- 🔄 **Drop-in Replacement**: minimal code changes required to migrate from `web3dart`.
- 🔐 **Enhanced Security**: Powered by strictly verified `web3_universal_crypto` (NIST/RFC compliant).
- 💼 **Keystore V3 Support**: Full support for Ethereum JSON wallets (Scrypt & PBKDF2).
  - `Wallet.createNew`: Generate new encrypted wallets.
  - `Wallet.fromJson`: Import existing V3 keystore files.
  - `Wallet.toJson`: Export wallets to standard JSON format.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  dart_web3_compat: ^0.1.0 
```

## Usage

### JSON Wallet Management (Keystore V3)

The `Wallet` class now utilizes verified Scrypt and AES implementations for secure keystore handling.

```dart
import 'package:dart_web3_compat/dart_web3_compat.dart';

void main() {
  final password = 'secure-password';
  final random = Random.secure();

  // 1. Create a new wallet (Scrypt-protected)
  final wallet = Wallet.createNew(EthPrivateKey.createRandom(random), password, random);
  print('New Address: ${wallet.privateKey.address}');

  // 2. Export to Keystore V3 JSON
  final json = wallet.toJson();
  print('Keystore JSON: $json');

  // 3. Import back
  final loadedWallet = Wallet.fromJson(json, password);
  assert(loadedWallet.privateKey.address == wallet.privateKey.address);
}
```

### Migrating from web3dart

Simply change your import:

```diff
- import 'package:web3dart/web3dart.dart';
+ import 'package:dart_web3_compat/dart_web3_compat.dart';
```

Most classes like `Web3Client`, `EthPrivateKey`, `Transaction`, and `Contract` remain compatible.
