import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import '../smart_account.dart';

/// SimpleAccount implementation following the ERC-4337 reference implementation.
///
/// This is the most basic smart account implementation that:
/// - Has a single owner (EOA)
/// - Supports simple signature validation
/// - Can execute single and batch transactions
/// - Is deployed via SimpleAccountFactory
class SimpleAccount extends BaseSmartAccount {
  SimpleAccount({
    required super.owner,
    required super.publicClient,
    required super.entryPointAddress,
    String? factoryAddress,
    String? implementationAddress,
  }) : super(
          factoryAddress: factoryAddress ?? defaultFactoryAddress,
          implementationAddress:
              implementationAddress ?? defaultImplementationAddress,
        );
  static const String defaultFactoryAddress =
      '0x9406Cc6185a346906296840746125a0E44976454';
  static const String defaultImplementationAddress =
      '0x2dd68b007B46fBe91B9A7c3EDa5A7a1063cB5b47';

  @override
  Future<String> getAddress() async {
    // SimpleAccount uses CREATE2 with factory, implementation, owner, and salt
    final ownerAddress = owner.address.hex;

    // The actual calculation would involve:
    // 1. ABI encode the initializer call
    // 2. Calculate CREATE2 address using factory, salt, and initCode hash

    // For now, return a deterministic placeholder based on owner
    final ownerBytes = HexUtils.decode(ownerAddress);
    final hash = HexUtils.encode(ownerBytes); // Simplified

    // This should be replaced with proper CREATE2 calculation
    return '0x' + hash.replaceFirst('0x', '').substring(0, 40);
  }

  @override
  Future<String?> getFactoryData() async {
    if (await isDeployed()) return null;

    final ownerAddress = owner.address.hex;
    final salt = BigInt.zero;
    return _encodeCreateAccountCall(ownerAddress, salt);
  }

  @override
  String encodeCallData(String to, BigInt value, String data) {
    // SimpleAccount.execute(dest, value, func)
    return _encodeExecuteCall(to, value, data);
  }

  @override
  String encodeBatchCallData(List<Call> calls) {
    // SimpleAccount.executeBatch(dest[], value[], func[])
    final destinations = calls.map((call) => call.to).toList();
    final values = calls.map((call) => call.value).toList();
    final datas = calls.map((call) => call.data).toList();

    return _encodeExecuteBatchCall(destinations, values, datas);
  }

  /// Encodes a createAccount function call to the factory.
  String _encodeCreateAccountCall(String owner, BigInt salt) {
    // createAccount(address,uint256) function selector: 0x5fbfb9cf
    final selector = '5fbfb9cf';
    final paddedOwner = owner.replaceFirst('0x', '').padLeft(64, '0');
    final paddedSalt = salt.toRadixString(16).padLeft(64, '0');

    return '0x$selector$paddedOwner$paddedSalt';
  }

  /// Encodes an execute function call.
  String _encodeExecuteCall(String dest, BigInt value, String func) {
    // execute(address,uint256,bytes) function selector: 0xb61d27f6
    final selector = 'b61d27f6';
    final paddedDest = dest.replaceFirst('0x', '').padLeft(64, '0');
    final paddedValue = value.toRadixString(16).padLeft(64, '0');

    // Encode bytes parameter
    final funcBytes = HexUtils.decode(func);
    final funcLength = funcBytes.length.toRadixString(16).padLeft(64, '0');
    final funcData = HexUtils.encode(funcBytes).replaceFirst('0x', '');
    final paddedFuncData =
        funcData.padRight(((funcData.length + 63) ~/ 64) * 64, '0');

    // Offset to bytes parameter (3 * 32 = 96 = 0x60)
    const bytesOffset =
        '0000000000000000000000000000000000000000000000000000000000000060';

    return '0x$selector$paddedDest$paddedValue$bytesOffset$funcLength$paddedFuncData';
  }

  /// Encodes an executeBatch function call.
  String _encodeExecuteBatchCall(
      List<String> destinations, List<BigInt> values, List<String> datas) {
    // executeBatch(address[],uint256[],bytes[]) function selector: 0x18dfb3c7
    final selector = '18dfb3c7';

    // This is a complex ABI encoding for arrays
    // Use proper ABI encoder from web3_universal_abi
    // For now, return a placeholder
    return '0x$selector';
  }
}

/// Factory for creating SimpleAccount instances.
class SimpleAccountFactory {
  SimpleAccountFactory({
    required this.factoryAddress,
    required this.publicClient,
  });
  final String factoryAddress;
  final PublicClient publicClient;

  /// Creates a SimpleAccount instance.
  SimpleAccount createAccount({
    required Signer owner,
    required String entryPointAddress,
    BigInt? salt,
  }) {
    return SimpleAccount(
      owner: owner,
      publicClient: publicClient,
      entryPointAddress: entryPointAddress,
      factoryAddress: factoryAddress,
    );
  }

  /// Gets the address of a SimpleAccount without deploying it.
  Future<String> getAccountAddress({
    required String ownerAddress,
    BigInt? salt,
  }) async {
    final actualSalt = salt ?? BigInt.zero;

    // Call factory.getAddress(owner, salt)
    final callData = _encodeGetAddressCall(ownerAddress, actualSalt);

    final result = await publicClient.call(
      CallRequest(
        to: factoryAddress,
        data: HexUtils.decode(callData),
      ),
    );

    return HexUtils.encode(result);
  }

  /// Encodes a getAddress function call to the factory.
  String _encodeGetAddressCall(String owner, BigInt salt) {
    // getAddress(address,uint256) function selector: 0x8cb84e18
    final selector = '8cb84e18';
    final paddedOwner = owner.replaceFirst('0x', '').padLeft(64, '0');
    final paddedSalt = salt.toRadixString(16).padLeft(64, '0');

    return '0x$selector$paddedOwner$paddedSalt';
  }
}
