# dart_web3_chains

Chain configurations and network metadata for EVM-compatible blockchains.

## Features

- **Predefined Chains**: Quick access to Ethereum, Polygon, Arbitrum, Optimism, etc.
- **Dynamic Chains**: Define custom chain configurations.
- **Explorer Links**: Built-in block explorer URL generation.
- **Multicall Addresses**: Registry for popular multicall contracts.

## Installation

```yaml
dependencies:
  dart_web3_chains: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_chains/dart_web3_chains.dart';

void main() {
  final ethereum = Chains.ethereum;
  print('Chain ID: ${ethereum.chainId}');
  print('Native Currency: ${ethereum.nativeCurrency.symbol}');
}
```
