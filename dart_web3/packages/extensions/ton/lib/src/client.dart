import 'dart:typed_data';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_provider/web3_universal_provider.dart';

/// TON JSON-RPC Client.
class TonClient implements PublicClientBase {
  TonClient(String url, {required this.chain})
      : provider = RpcProvider(HttpTransport(url));

  final RpcProvider provider;

  @override
  final ChainConfig chain;

  @override
  Future<BigInt> getBalance(String address) async {
    // Placeholder for TON getAddressInformation
    return BigInt.zero;
  }

  @override
  Future<String> sendTransaction(Uint8List tx) async {
    // Placeholder for TON sendMessage
    return '';
  }

  @override
  Future<BigInt> getBlockNumber() async {
    // Placeholder for TON getMasterchainInfo
    return BigInt.zero;
  }

  @override
  void dispose() {
    provider.dispose();
  }
}
