# web3_universal_crypto

![Web3 Universal Banner](https://raw.githubusercontent.com/ImL1s/dart_web3/master/art/web3_universal_banner.png)

<!-- Package not yet published to pub.dev -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Cryptographic primitives for the **Web3 Universal SDK**. This package provides security-first implementations of Ed25519, Schnorr (BIP-340), and Secp256k1 for cross-chain signing.

## Features

- 🔐 **Ethereum Keystore V3**: Full Scrypt (RFC 7914) & PBKDF2 support for encrypted JSON wallets.
- 🛡️ **Zero Dependency**: Pure Dart implementation of Scrypt, AES-128-CTR, and Keccak-256.
- 🧪 **Strict Verification**: Verified against official test vectors from **NIST** (AES/SHA), **RFC** (Scrypt/PBKDF2), and **Ethereum Core**.
- 🐚 **Ed25519**: High-performance implementation for Solana and Cosmos.
- 🔑 **HD Wallet**: Full BIP-32 and BIP-44 hierarchical deterministic derivation.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  web3_universal_crypto: ^0.1.0
```

## Quick Start

```dart
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  // Generate a Schnorr signature
  final keyPair = SchnorrKeyPair.generate();
  final message = Uint8List.fromList([0x01, 0x02]);
  final signature = keyPair.sign(message);
  print('Signature: ${signature.toHex()}');
}
```

## Platform Support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Usage Flow
```mermaid
sequenceDiagram
    participant M as Mnemonic
    participant S as Seed
    participant K as PrivateKey
    participant P as PublicKey
    M->>S: generateSeed(pass)
    S->>K: derive(path)
    K->>P: compute()
    P-->>U: Wallet Address
```

## 🏗️ Architecture

```mermaid
graph LR
    Entropy[Entropy Source] --> BIP39[BIP-39 Mnemonic]
    BIP39 --> Seed[PBKDF2 Seed]
    Seed --> HDMaster[BIP-32 Master Node]
    HDMaster --> Derived[BIP-44 Child Node]
    Derived --> ECDSA[secp256k1 KeyPair]
    
    style ECDSA fill:#bfb,stroke:#2d2,stroke-width:2px;
```

## 📚 Technical Reference

### Core Classes
| Class | Responsibility |
|-------|----------------|
| `Scrypt` | RFC 7914 compliant KDF (N, r, p configurable). |
| `KeystoreV3` | Encrypts/Decrypts Ethereum JSON wallets (AES-128-CTR + MAC). |
| `AES` | AES-128 Block Cipher and CTR Stream Mode. |
| `Bip39` | Generates and validates mnemonic phrases and seeds. |
| `HDWallet` | Manages node trees and path-based key derivation. |
| `EthKeyPair` | Represents a raw private/public key pair and performs ECDSA. |
| `Keccak` | Provides Ethereum-standard Keccak-256 hashing. |

## 🛡️ Security Considerations

- **Memory Erasure**: Use `privateKey.fill(0)` (if available in buffer context) after deriving keys to minimize resident memory risk.
- **Entropy Source**: `Bip39.generate()` uses `Random.secure()`. On some platforms, ensure the underlying system RNG is properly initialized.
- **Do Not Log Keys**: Never log or print private keys or mnemonics in production. Use obfuscated logging if necessary.

## 💻 Usage

### Secure Multi-Account Derivation
```dart
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  final mnemonic = "asset adjust total... (12 words)";
  final hdRoot = HDWallet.fromMnemonic(Mnemonic.fromSentence(mnemonic, WordList.english));

  // Derive Account #0 and Account #1
  final acc0 = hdRoot.derivePath("m/44'/60'/0'/0/0");
  final acc1 = hdRoot.derivePath("m/44'/60'/0'/0/1");

  print('Acc 0 Address: ${acc0.address}');
}
```

### Keystore V3 (Encrypted Wallet)
```dart
import 'dart:convert';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  final password = "strong-password";
  final privateKey = Uint8List.fromList(List.generate(32, (i) => i));

  // Encrypt (produces standard V3 JSON)
  final keystore = KeystoreV3.encrypt(privateKey, password);
  print(jsonEncode(keystore));

  // Decrypt
  final recoveredKey = KeystoreV3.decrypt(keystore, password);
}
```

### Performance Hashing
```dart
final hash = Keccak.hash(Uint8List.fromList([0x01, 0x02]));
```

## 📦 Installation

```yaml
dependencies:
  web3_universal_crypto: ^0.2.0
```
