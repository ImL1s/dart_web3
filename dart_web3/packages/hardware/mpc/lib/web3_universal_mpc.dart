/// MPC (Multi-Party Computation) wallet support for distributed key management.
///
/// This library provides:
/// - [MpcSignerImpl] - MPC-based signer implementation
/// - [MpcProvider] - Integration with MPC service providers
/// - [KeyGeneration] - Key generation ceremony management
/// - [KeyRefresh] - Key share rotation utilities
/// - [SigningCoordinator] - Multi-party signing coordination
/// - [ThresholdSignature] - Threshold signature schemes
library;

export 'src/key_generation.dart';
export 'src/key_refresh.dart';
export 'src/mpc_provider.dart';
export 'src/mpc_signer.dart';
export 'src/mpc_types.dart';
export 'src/signing_coordinator.dart';
export 'src/threshold_signature.dart';
