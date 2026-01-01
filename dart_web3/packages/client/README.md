# dart_web3_client

High-level client implementations for interacting with the blockchain.

## Features

- **PublicClient**: Optimized for read-only operations (balance, block info, logs).
- **WalletClient**: Optimized for write operations (transactions, deployments).
- **ClientFactory**: Unified entry point for client creation.
- **Auto-Chain Management**: Automatically handle chain-specific transaction parameters.

## Installation

```yaml
dependencies:
  dart_web3_client: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_client/dart_web3_client.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
  );
  
  final balance = await client.getBalance('0x...');
}
```
