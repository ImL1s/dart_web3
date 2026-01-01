# dart_web3_crypto

Cryptographic primitives for the Dart Web3 SDK.

## Features

- **Elliptic Curve**: secp256k1 support.
- **Hash Functions**: Keccak-256 and other essential hashes.
- **Key Management**: BIP-32 (Hierarchical Deterministic Wallets), BIP-39 (Mnemonic phrases), and BIP-44.
- **Pure Dart**: No dependency on native libraries.

## Installation

```yaml
dependencies:
  dart_web3_crypto: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

void main() {
  final mnemonic = Mnemonic.generate();
  final seed = mnemonic.toSeed();
  final masterKey = HDWallet.fromSeed(seed);
  
  print('Mnemonic: ${mnemonic.sentence}');
}
```
