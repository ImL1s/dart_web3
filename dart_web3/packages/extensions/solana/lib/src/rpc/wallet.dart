import 'dart:typed_data';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import '../models/keypair.dart';
import 'client.dart';

/// Wallet client for Solana.
class SolanaWalletClient extends SolanaClient implements WalletClientBase {
  SolanaWalletClient(
    super.url, {
    required super.chain,
    required this.keyPair,
    super.httpClient,
  });

  final KeyPair keyPair;

  @override
  String get address => keyPair.publicKey.toBase58();

  @override
  Future<Uint8List> signMessage(String message) async {
    return keyPair.sign(Uint8List.fromList(message.codeUnits));
  }

  @override
  Future<Uint8List> signTransaction(Uint8List tx) async {
    // In Solana, signing a transaction often means signing the message part
    // and prepending signatures. For simplicity in this base interface,
    // we return the signature of the raw bytes.
    return keyPair.sign(tx);
  }
}
