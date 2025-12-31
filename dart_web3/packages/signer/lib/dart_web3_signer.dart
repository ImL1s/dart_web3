/// Signer abstraction for Ethereum transaction and message signing.
///
/// This library provides:
/// - [Signer] - Abstract signer interface
/// - [PrivateKeySigner] - Sign with a private key
/// - [TransactionRequest] - Transaction data structure
/// - [Authorization] - EIP-7702 authorization
/// - [AuthorizationVerifier] - EIP-7702 authorization verification utilities
/// - [AuthorizationBatch] - Batch authorization management
/// - [AuthorizationRevocation] - Authorization revocation utilities
library dart_web3_signer;

export 'src/signer.dart';
export 'src/private_key_signer.dart';
export 'src/transaction.dart';
export 'src/authorization.dart';
export 'src/authorization_verifier.dart';
export 'src/authorization_batch.dart';
export 'src/authorization_revocation.dart';
