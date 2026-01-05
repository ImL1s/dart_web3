# Web3 Wallet App

A comprehensive multi-chain wallet demonstrating the **dart_web3 SDK** capabilities.

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-blue.svg)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-purple.svg)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

🔑 **Wallet Management**
- BIP-39 mnemonic generation (12/24 words)
- BIP-32/44 HD wallet derivation
- Secure encrypted storage

⛓️ **Multi-Chain Support**
- Ethereum Mainnet
- Polygon
- Arbitrum
- BNB Chain
- (Extensible to Solana, TRON, TON, Bitcoin)

💰 **Core Functionality**
- Real-time balance display
- Send & receive transactions
- QR code generation
- Address copying

🔄 **DEX Integration**
- Token swaps (powered by `web3_universal_swap`)
- 1inch & Paraswap aggregation
- Slippage configuration

🖼️ **NFT Gallery**
- ERC-721 & ERC-1155 support
- Collection display

## dart_web3 SDK Packages Used

| Package | Purpose |
|---------|---------|
| `web3_universal_core` | Core utilities and types |
| `web3_universal_crypto` | BIP-39/44 HD wallet, cryptography |
| `web3_universal_signer` | Transaction signing (ECDSA/EdDSA) |
| `web3_universal_chains` | Chain configurations |
| `web3_universal_client` | Blockchain RPC interaction |
| `web3_universal_provider` | HTTP/WebSocket providers |
| `web3_universal_ens` | ENS name resolution |
| `web3_universal_swap` | DEX aggregation |
| `web3_universal_nft` | NFT services |
| `web3_universal_price` | Price feeds |

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

### Platforms Supported

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## Architecture

```
lib/
├── main.dart              # Entry point
├── app.dart               # MaterialApp with theming
├── core/
│   └── router/            # GoRouter navigation
├── features/
│   ├── onboarding/        # Wallet creation/import
│   ├── home/              # Dashboard
│   ├── send/              # Send transactions
│   ├── receive/           # QR code display
│   ├── swap/              # Token swaps
│   ├── nft/               # NFT gallery
│   └── settings/          # App settings
└── shared/
    └── providers/         # Riverpod providers
```

## State Management

Uses **Riverpod 2.x** with:
- `StateNotifier` for wallet state
- `FutureProvider` for async operations
- `Provider` for dependencies

## Security

- Mnemonic stored in `flutter_secure_storage`
- Android: EncryptedSharedPreferences
- iOS: Keychain Services
- No private keys transmitted over network

## License

MIT License - See [LICENSE](LICENSE)

---

Built with ❤️ using [dart_web3 SDK](https://github.com/ImL1s/dart_web3)
