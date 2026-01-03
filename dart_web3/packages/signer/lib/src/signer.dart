import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

import 'authorization.dart';
import 'transaction.dart';

/// Abstract signer interface for signing transactions and messages.
abstract class Signer {
  /// The signer's Ethereum address.
  EthereumAddress get address;

  /// Signs a transaction and returns the signed transaction bytes.
  Future<Uint8List> signTransaction(TransactionRequest transaction);

  /// Signs a personal message (EIP-191).
  ///
  /// This method adds the EIP-191 prefix before signing:
  /// `\x19Ethereum Signed Message:\n{length}{message}`
  Future<Uint8List> signMessage(String message);

  /// Signs a raw hash directly without any prefix.
  ///
  /// Use this for:
  /// - ERC-4337 UserOperation signing (userOpHash is already a 32-byte hash)
  /// - Any case where you need to sign a pre-computed hash
  ///
  /// WARNING: The hash should be exactly 32 bytes. This method does NOT add
  /// any prefix (unlike signMessage which adds EIP-191 prefix).
  Future<Uint8List> signHash(Uint8List hash);

  /// Signs typed data (EIP-712).
  Future<Uint8List> signTypedData(TypedData typedData);

  /// Signs an EIP-7702 authorization.
  Future<Uint8List> signAuthorization(Authorization authorization);
}

/// Abstract hardware wallet signer interface.
abstract class HardwareWalletSigner implements Signer {
  /// Checks if the hardware wallet is connected.
  Future<bool> isConnected();

  /// Connects to the hardware wallet.
  Future<void> connect();

  /// Disconnects from the hardware wallet.
  Future<void> disconnect();

  /// Gets available addresses from the hardware wallet.
  Future<List<EthereumAddress>> getAddresses({int count = 5, int offset = 0});
}

/// Abstract MPC signer interface.
abstract class MpcSigner implements Signer {
  /// The party ID in the MPC protocol.
  String get partyId;

  /// The threshold for signing (t-of-n).
  int get threshold;

  /// The total number of parties.
  int get totalParties;

  /// Starts a key generation ceremony.
  Future<void> startKeyGeneration();

  /// Refreshes key shares.
  Future<void> refreshKeys();

  /// Starts a signing session.
  Future<SigningSession> startSigning(Uint8List messageHash);
}

/// Represents an MPC signing session.
class SigningSession {

  SigningSession({required this.sessionId, required this.requiredParties});
  /// The session ID.
  final String sessionId;

  /// The parties required to complete signing.
  final List<String> requiredParties;

  /// Waits for the signing to complete.
  Future<Uint8List> waitForCompletion() async {
    throw UnimplementedError();
  }

  /// Cancels the signing session.
  Future<void> cancel() async {
    throw UnimplementedError();
  }
}
