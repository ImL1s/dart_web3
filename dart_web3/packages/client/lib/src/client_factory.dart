import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

import 'public_client.dart';
import 'wallet_client.dart';

/// Factory for creating clients.
class ClientFactory {
  ClientFactory._();

  /// Creates a public client.
  static PublicClient createPublicClient({
    required String rpcUrl,
    required ChainConfig chain,
    List<Middleware>? middlewares,
  }) {
    final transport = HttpTransport(rpcUrl);
    final provider = RpcProvider(transport, middlewares: middlewares ?? []);
    return PublicClient(provider: provider, chain: chain);
  }

  /// Creates a wallet client.
  static WalletClient createWalletClient({
    required String rpcUrl,
    required ChainConfig chain,
    required Signer signer,
    List<Middleware>? middlewares,
  }) {
    final transport = HttpTransport(rpcUrl);
    final provider = RpcProvider(transport, middlewares: middlewares ?? []);
    return WalletClient(provider: provider, chain: chain, signer: signer);
  }

  /// Creates a public client with WebSocket transport.
  static PublicClient createPublicClientWs({
    required String wsUrl,
    required ChainConfig chain,
    List<Middleware>? middlewares,
  }) {
    final transport = WebSocketTransport(wsUrl);
    final provider = RpcProvider(transport, middlewares: middlewares ?? []);
    return PublicClient(provider: provider, chain: chain);
  }

  /// Creates a wallet client with WebSocket transport.
  static WalletClient createWalletClientWs({
    required String wsUrl,
    required ChainConfig chain,
    required Signer signer,
    List<Middleware>? middlewares,
  }) {
    final transport = WebSocketTransport(wsUrl);
    final provider = RpcProvider(transport, middlewares: middlewares ?? []);
    return WalletClient(provider: provider, chain: chain, signer: signer);
  }
}
