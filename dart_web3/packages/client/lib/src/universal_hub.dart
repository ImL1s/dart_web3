import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:web3_universal_solana/web3_universal_solana.dart';

import 'public_client.dart';

/// A universal entry point for creating blockchain clients across all supported architectures.
mixin UniversalClient {
  /// Creates a [PublicClientBase] for the specified [chain].
  ///
  /// If a [provider] is not provided, a default [HttpTransport] will be created
  /// using the first RPC URL in the [chain] configuration.
  static PublicClientBase create(ChainConfig chain, {RpcProvider? provider}) {
    final rpcProvider = provider ??
        RpcProvider(
          HttpTransport(
            chain.rpcUrls.first,
          ),
        );

    switch (chain.type) {
      case ChainType.evm:
        return PublicClient(provider: rpcProvider, chain: chain);
      case ChainType.svm:
        return SolanaClient(chain.rpcUrls.first, chain: chain);

      default:
        throw UnimplementedError(
          'Client for chain type ${chain.type} is not yet implemented',
        );
    }
  }
}
