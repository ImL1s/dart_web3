/// RPC Provider for Ethereum blockchain communication.
///
/// This library provides:
/// - [Transport] - Abstract transport interface
/// - [HttpTransport] - HTTP JSON-RPC transport
/// - [WebSocketTransport] - WebSocket transport with subscriptions
/// - [ResilientWebSocketTransport] - WebSocket with auto-reconnect
/// - [FallbackTransport] - Multi-transport with automatic failover
/// - [RpcProvider] - High-level RPC provider with middleware support
library;

export 'src/fallback_transport.dart';
export 'src/http_transport.dart';
export 'src/middleware.dart';
export 'src/provider.dart';
export 'src/resilient_websocket_transport.dart';
export 'src/transport.dart';
export 'src/websocket_transport.dart';
