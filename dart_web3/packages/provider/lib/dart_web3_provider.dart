/// RPC Provider for Ethereum blockchain communication.
///
/// This library provides:
/// - [Transport] - Abstract transport interface
/// - [HttpTransport] - HTTP JSON-RPC transport
/// - [WebSocketTransport] - WebSocket transport with subscriptions
/// - [RpcProvider] - High-level RPC provider with middleware support
library dart_web3_provider;

export 'src/transport.dart';
export 'src/http_transport.dart';
export 'src/websocket_transport.dart';
export 'src/provider.dart';
export 'src/middleware.dart';
