import 'dart:typed_data';
import 'chain_config.dart';

/// Base interface for all blockchain clients.
abstract class PublicClientBase {
  /// The chain configuration for this client.
  ChainConfig get chain;

  /// Gets the balance of an address in the native currency's smallest unit.
  /// Standardized to [BigInt] to support diverse precisions.
  Future<BigInt> getBalance(String address);

  /// Sends a raw signed transaction to the network.
  Future<String> sendTransaction(Uint8List tx);

  /// Gets the current block (or slot, for SVM) number.
  Future<BigInt> getBlockNumber();

  /// Disposes of the client and its underlying resources.
  void dispose();
}

/// Base interface for all wallet clients.
abstract class WalletClientBase extends PublicClientBase {
  /// The wallet address.
  String get address;

  /// Signs a message.
  Future<Uint8List> signMessage(String message);

  /// Signs a raw transaction.
  Future<Uint8List> signTransaction(Uint8List tx);
}
