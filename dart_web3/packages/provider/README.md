# dart_web3_provider

RPC Provider implementations for communicating with blockchain nodes.

## Features

- **HTTP Provider**: Standard JSON-RPC over HTTP.
- **Websocket Provider**: (Planned) Persistent connection for subscriptions.
- **Middleware Support**: Intercept and modify requests/responses.
- **Error Handling**: Standardized RPC error types.

## Installation

```yaml
dependencies:
  dart_web3_provider: ^0.1.0
```

## Usage

```dart
import 'package:dart_web3_provider/dart_web3_provider.dart';

void main() async {
  final provider = HttpProvider('https://eth.llamarpc.com');
  final response = await provider.request('eth_blockNumber', []);
  print('Current block: ${response.result}');
}
```
