# dart_web3_contract

Contract-oriented abstractions for easy smart contract interaction.

## Features

- **Type-Safe Calls**: Call contract functions with Dart types.
- **Event Filtering**: Subscribe to specific contract events.
- **Deployment**: Tools for deploying new contracts.
- **Proxy Support**: Handle upgradeable contracts (UUPS, Transparent).

## Installation

```yaml
dependencies:
  dart_web3_contract: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_contract/dart_web3_contract.dart';

void main() async {
  final contract = DeployedContract(
    abi: ...,
    address: '0x...',
  );
  
  final result = await contract.call('balanceOf', ['0x...']);
}
```
