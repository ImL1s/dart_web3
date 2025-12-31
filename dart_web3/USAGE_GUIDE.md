# Dart Web3 SDK Usage Guide

A comprehensive, pure Dart Web3 SDK for EVM-compatible blockchains and multi-chain support.

## Getting Started

Add the meta-package to your `pubspec.yaml`:

```yaml
dependencies:
  dart_web3: ^0.1.0
```

## Basic Usage

### Working with Wallets

```dart
import 'package:dart_web3/dart_web3.dart';

// Generate a random mnemonic
final mnemonic = Bip39.generate();

// Create an HD wallet
final wallet = HDWallet.fromMnemonic(mnemonic);
final address = wallet.getAddress();

// Sign a message
final signer = PrivateKeySigner(wallet.getPrivateKey(), 1);
final signature = await signer.signMessage("Hello Web3!");
```

### interacting with Smart Contracts

```dart
final publicClient = ClientFactory.createPublicClient(
  rpcUrl: 'https://eth.llamarpc.com',
  chain: Chains.ethereum,
);

final erc20 = ERC20Contract(
  address: '0x...',
  publicClient: publicClient,
);

final balance = await erc20.balanceOf('0x...');
```

### Account Abstraction (ERC-4337)

```dart
final smartAccount = SimpleAccount(
  owner: signer,
  factoryAddress: '0x...',
);

print('Smart Account: ${smartAccount.address}');
```

## Module Structure

The SDK is highly modular (Levels 0-7). You can import specific packages to reduce bundle size:

- `dart_web3_core`: Basic utilities.
- `dart_web3_crypto`: Cryptography.
- `dart_web3_client`: RPC clients.
- `dart_web3_nft`: NFT services.
- `dart_web3_extensions_solana`: Solana support.
