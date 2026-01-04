# web3_universal_cosmos

![Web3 Universal Banner](https://raw.githubusercontent.com/ImL1s/dart_web3/master/art/web3_universal_banner.png)

[![Pub Version](https://img.shields.io/pub/v/web3_universal_cosmos)](https://pub.dev/packages/web3_universal_cosmos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Cosmos blockchain extension for the **Web3 Universal SDK**. Build on the Interchain using pure Dart.

## Features

- ⚛️ **Cosmos SDK**: Support for Bech32 addresses and Protobuf serialization.
- 🌉 **IBC**: Native support for `MsgTransfer` cross-chain token transfers.
- 🥩 **Staking**: Built-in support for `MsgDelegate` and `MsgUndelegate` operations.
- 📡 **LCD Client**: High-level client for interacting with Cosmos REST/LCD APIs.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  web3_universal_cosmos: ^0.1.0
```

## Quick Start

```dart
import 'package:web3_universal_cosmos/web3_universal_cosmos.dart';

void main() async {
  final client = CosmosClient('https://rest.cosmos.directory/cosmoshub');
  final account = await client.getAccount('cosmos1...');
  print('Account: $account');
}
```

## Platform Support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
