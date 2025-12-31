/// ERC-4337 Account Abstraction support for Dart Web3 SDK.
/// 
/// This library provides comprehensive support for ERC-4337 Account Abstraction,
/// including UserOperation construction, Bundler communication, Paymaster integration,
/// and Smart Account implementations.
library dart_web3_aa;

// Core AA types and interfaces
export 'src/user_operation.dart';
export 'src/bundler_client.dart';
export 'src/paymaster.dart';
export 'src/smart_account.dart';
export 'src/entry_point.dart';

// Smart Account implementations
export 'src/accounts/simple_account.dart';
export 'src/accounts/light_account.dart';
