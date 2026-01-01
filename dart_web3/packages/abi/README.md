# dart_web3_abi

Application Binary Interface (ABI) encoding and decoding for Ethereum smart contracts.

## Features

- **Type Support**: Full support for Solidity types (uint, address, bool, fixed-size arrays, dynamic arrays, tuples).
- **Function Dispatch**: Encode function calls and decode return values.
- **Event Decoding**: Parse log data according to event definitions.
- **Human-Readable ABI**: Future support for parsing JSON and human-readable ABI strings.

## Installation

```yaml
dependencies:
  dart_web3_abi: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_abi/dart_web3_abi.dart';

void main() {
  final function = AbiFunction(name: 'transfer', params: [
    AbiParameter('to', 'address'),
    AbiParameter('value', 'uint256'),
  ]);
  
  final data = function.encode(['0x...', BigInt.from(100)]);
}
```
