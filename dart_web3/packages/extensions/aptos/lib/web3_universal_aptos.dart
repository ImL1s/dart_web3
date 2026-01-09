/// Aptos blockchain extension for Web3 Universal SDK.
///
/// This library provides Aptos blockchain support including:
/// - Ed25519 keypair and address generation
/// - BCS (Binary Canonical Serialization) encoding
/// - Transaction building and signing
/// - RPC client for Aptos REST API
library;

export 'src/models/account.dart';
export 'src/models/address.dart';
export 'src/models/transaction.dart';
export 'src/rpc/client.dart';

export 'package:web3_universal_chains/web3_universal_chains.dart';
