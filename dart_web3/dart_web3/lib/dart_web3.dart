/// Dart Web3 SDK - A comprehensive pure Dart Web3 SDK.
///
/// This is the meta-package that re-exports all core modules.
/// For minimal dependencies, import individual packages instead.
library dart_web3;

// Level 0 - Core
export 'package:dart_web3_core/dart_web3_core.dart';

// Level 1 - Primitives
export 'package:dart_web3_crypto/dart_web3_crypto.dart';
export 'package:dart_web3_abi/dart_web3_abi.dart';

// Level 2 - Transport
export 'package:dart_web3_provider/dart_web3_provider.dart';
export 'package:dart_web3_signer/dart_web3_signer.dart';
export 'package:dart_web3_chains/dart_web3_chains.dart';

// Level 3 - Clients
export 'package:dart_web3_client/dart_web3_client.dart';
export 'package:dart_web3_contract/dart_web3_contract.dart';
export 'package:dart_web3_events/dart_web3_events.dart';

// Level 4 - Services
export 'package:dart_web3_multicall/dart_web3_multicall.dart';
export 'package:dart_web3_ens/dart_web3_ens.dart';
