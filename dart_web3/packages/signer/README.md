# dart_web3_signer

Signer abstractions and implementations for authorizing transactions.

## Features

- **PrivateKeySigner**: Local signing using a private key.
- **Hardware Signer Interface**: Extensible base for Ledger, Trezor, etc.
- **EIP-712**: Structured data signing support.
- **Message Signing**: Standard `eth_sign` and `personal_sign`.

## Installation

```yaml
dependencies:
  dart_web3_signer: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_signer/dart_web3_signer.dart';

void main() async {
  final signer = PrivateKeySigner.fromHex('0x...');
  final signature = await signer.signMessage('Hello Web3');
  print('Signature: $signature');
}
```
