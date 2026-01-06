# Web3 Wallet App

A comprehensive multi-chain wallet demonstrating the **dart_web3 SDK** capabilities, featuring native support for **EVM**, **Bitcoin**, and **Solana** chains without external native dependencies.

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-blue.svg)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-purple.svg)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

### 🔑 Wallet Management
- **Universal Key Derivation**:
  - BIP-39 mnemonic generation (12/24 words).
  - **EVM**: BIP-44 standard (`m/44'/60'/0'/0/0`).
  - **Bitcoin**: BIP-84 Native SegWit (`m/84'/0'/0'/0/0`).
  - **Solana**: SLIP-0010 Ed25519 (`m/44'/501'/0'/0'`).
- Secure encrypted storage (Keychain/Keystore).

### ⛓️ Multi-Chain Support
- **EVM Chains**: Ethereum, Polygon, Arbitrum, Optimism, Base.
- **Bitcoin**: Mainnet Native SegWit (Bech32 `bc1q...`).
- **Solana**: Mainnet System Program.

### 💰 Core Functionality
- **Cross-Chain Usage**: Unified interface for all chains.
- **Real-Time Data**: 
  - Balances (RPC/API fetching).
  - Transaction history.
- **Transactions**: 
  - Standard transfers (ETH, MATIC, BTC, SOL).
  - EIP-1559 support for EVM.
  - Native SegWit (P2WPKH) for Bitcoin.

### 🔄 DEX & NFT (EVM Only)
- Token swaps (powered by `web3_universal_swap`).
- NFT Gallery (ERC-721/1155).

## dart_web3 SDK Packages Used

The app showcases the modular architecture of the SDK:

| Package | Purpose |
|---------|---------|
| `web3_universal_core` | Core utilities and primitives |
| `web3_universal_crypto` | Cryptography (Secp256k1, Ed25519, SHA, BIP-39/32) |
| `web3_universal_signer` | Transaction signing (EVM) |
| `web3_universal_utxo` | **Bitcoin** transaction building & signing |
| `web3_universal_solana` | **Solana** transaction building & signing |
| `web3_universal_provider` | RPC providers (HTTP/WebSocket) |
| `web3_universal_chains` | Chain configurations |
| `web3_universal_swap` | DEX aggregation |
| `web3_universal_nft` | NFT services |

## Getting Started

### Prerequisites
- Flutter SDK 3.27+
- Dart SDK 3.6+

### Installation

```bash
# From the monorepo root
cd example_app

# Get dependencies
flutter pub get

# Run on desired platform
flutter run -d chrome  # Web
flutter run -d windows # Windows
flutter run -d macos   # macOS
flutter run            # Default device
```

### Running Tests

We have added comprehensive tests for the multi-chain functionality:

```bash
# Unit tests for Wallet Service (Derivation, Signing)
flutter test test/core/wallet_service_test.dart

# Unit tests for History Provider (Logic, State)
flutter test test/shared/providers/transaction_history_provider_test.dart
```

## Architecture

The app follows a Clean Architecture approach with Riverpod:

```
lib/
├── main.dart              # Entry point
├── core/
│   ├── wallet_service.dart # SINGLETON: Unified facade for all chains
│   └── config/            # Chain configurations
├── features/
│   ├── onboarding/        # Create/Import wallet
│   ├── home/              # Dashboard & Asset list
│   ├── history/           # Transaction history
│   ├── send/              # Cross-chain send screen
│   └── ...
└── shared/
    └── providers/         # State Management (NotifierProviders)
        ├── wallet_provider.dart
        ├── balance_provider.dart
        └── transaction_history_provider.dart
```

## Implementation Highlights

### Unified Transaction Signing

The `WalletService` abstracts away the complexity of different signing algorithms:

```dart
// EVM (Secp256k1 + Keccak256)
final signature = privateKey.signToSignature(digest);

// Bitcoin (Secp256k1 + Double SHA256 + BIP-143)
final signature = Secp256k1.sign(sighash, privateKey);

// Solana (Ed25519)
final signature = Ed25519KeyPair.sign(message, privateKey);
```

### No Native Dependencies

All cryptographic operations are implemented in pure Dart or via the `web3_universal_crypto` package, ensuring:
- **Zero FFI**: No complex native build steps.
- **Cross-Platform**: Works exactly the same on Web, Mobile, and Desktop.

## License

MIT License - See [LICENSE](LICENSE)

---

Built with ❤️ using [dart_web3 SDK](https://github.com/ImL1s/dart_web3)
