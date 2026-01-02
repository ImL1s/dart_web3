
import 'contract.dart';

/// Base class for type-safe contract implementations.
abstract class TypedContract extends Contract {
  TypedContract({
    required super.address,
    required super.publicClient,
    super.walletClient,
  }) : super(
          abi: _getAbiForType(),
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
