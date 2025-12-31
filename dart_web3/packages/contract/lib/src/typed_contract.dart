import 'package:dart_web3_client/dart_web3_client.dart';

import 'contract.dart';
import 'event_filter.dart';

/// Base class for type-safe contract implementations.
abstract class TypedContract extends Contract {
  TypedContract({
    required String address,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) : super(
          address: address,
          abi: _getAbiForType(),
          publicClient: publicClient,
          walletClient: walletClient,
        );

  /// Returns the ABI JSON for this contract type.
  /// This method should be overridden by subclasses.
  static String getAbi() {
    throw UnimplementedError('Subclasses must implement getAbi()');
  }

  /// Internal method to get ABI for the specific type.
  static String _getAbiForType() {
    throw UnimplementedError('This should not be called directly');
  }
}