# dart_web3_core

The foundational package for the Dart Web3 SDK, providing core primitives and utilities.

## Features

- **Address Handling**: Validation and formatting of Ethereum addresses.
- **RLP Encoding**: Recursive Length Prefix encoding/decoding.
- **Numeric Utilities**: Helpers for BigInt and Hex conversions.
- **Unit Conversion**: Ether unit conversions (Wei, Gwei, Ether).

## Installation

```yaml
dependencies:
  dart_web3_core: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  final address = EthAddress.fromHex('0x...');
  print(address.hex);
  
  final wei = EthUnit.ether('1');
  print(wei); // 1000000000000000000
}
```
