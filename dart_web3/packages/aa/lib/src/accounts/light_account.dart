import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import '../smart_account.dart';

/// LightAccount implementation optimized for gas efficiency.
/// 
/// LightAccount is a more gas-efficient alternative to SimpleAccount with:
/// - Optimized bytecode for lower deployment and execution costs
/// - Support for EIP-1271 signature validation
/// - Batch execution capabilities
/// - Upgradeable implementation
class LightAccount extends BaseSmartAccount {

  LightAccount({
    required super.owner,
    required super.publicClient,
    required super.entryPointAddress,
    String? factoryAddress,
    String? implementationAddress,
  }) : super(
          factoryAddress: factoryAddress ?? defaultFactoryAddress,
          implementationAddress: implementationAddress ?? defaultImplementationAddress,
        );
  static const String defaultFactoryAddress = '0x00004EC70002a32400f8ae005A26081065620D20';
  static const String defaultImplementationAddress = '0xae8c656ad28F2B59a196AB61815C16A0AE1c3cba';

  @override
  Future<String> getAddress() async {
    // LightAccount uses CREATE2 with factory, implementation, owner, and salt
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
    // LightAccount.execute(dest, value, func)
    return _encodeExecuteCall(to, value, data);
  }

  @override
  String encodeBatchCallData(List<Call> calls) {
    // LightAccount.executeBatch(calls)
    return _encodeExecuteBatchCall(calls);
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
    final paddedFuncData = funcData.padRight(((funcData.length + 63) ~/ 64) * 64, '0');
    
    // Offset to bytes parameter (3 * 32 = 96 = 0x60)
    const bytesOffset = '0000000000000000000000000000000000000000000000000000000000000060';
    
    return '0x$selector$paddedDest$paddedValue$bytesOffset$funcLength$paddedFuncData';
  }

  /// Encodes an executeBatch function call for LightAccount.
  String _encodeExecuteBatchCall(List<Call> calls) {
    // executeBatch((address,uint256,bytes)[]) function selector: 0x47e1da2a
    final selector = '47e1da2a';
    
    // LightAccount uses a different batch format with Call structs
    // Use proper ABI encoder from web3_universal_abi
    // For now, return a placeholder
    return '0x$selector';
  }


  /// Checks if the account supports EIP-1271 signature validation.
  Future<bool> supportsEIP1271() async {
    try {
      final address = await getAddress();
      
      // Check if contract implements EIP-1271 by calling supportsInterface
      final callData = _encodeSupportsInterfaceCall('0x1626ba7e'); // EIP-1271 interface ID
      
      final result = await publicClient.call(CallRequest(
        to: address,
        data: HexUtils.decode(callData),
      ),);
      
      // Decode boolean result
      return result.isNotEmpty && result[31] == 1;
    } catch (_) {
      // Return false if contract is not deployed
      return false;
    }
  }

  /// Validates a signature using EIP-1271.
  Future<bool> isValidSignature(String hash, String signature) async {
    try {
      final address = await getAddress();
      
      // Call isValidSignature(bytes32,bytes)
      final callData = _encodeIsValidSignatureCall(hash, signature);
      
      final result = await publicClient.call(CallRequest(
        to: address,
        data: HexUtils.decode(callData),
      ),);
      
      // Check if result equals EIP-1271 magic value (0x1626ba7e)
      final magicValue = HexUtils.encode(result);
      return magicValue == '0x1626ba7e';
    } catch (_) {
      return false;
    }
  }

  /// Encodes a supportsInterface function call.
  String _encodeSupportsInterfaceCall(String interfaceId) {
    // supportsInterface(bytes4) function selector: 0x01ffc9a7
    final selector = '01ffc9a7';
    final paddedInterfaceId = interfaceId.replaceFirst('0x', '').padLeft(64, '0');
    
    return '0x$selector$paddedInterfaceId';
  }

  /// Encodes an isValidSignature function call.
  String _encodeIsValidSignatureCall(String hash, String signature) {
    // isValidSignature(bytes32,bytes) function selector: 0x1626ba7e
    final selector = '1626ba7e';
    final paddedHash = hash.replaceFirst('0x', '').padLeft(64, '0');
    
    // Encode bytes parameter
    final sigBytes = HexUtils.decode(signature);
    final sigLength = sigBytes.length.toRadixString(16).padLeft(64, '0');
    final sigData = HexUtils.encode(sigBytes).replaceFirst('0x', '');
    final paddedSigData = sigData.padRight(((sigData.length + 63) ~/ 64) * 64, '0');
    
    // Offset to bytes parameter (2 * 32 = 64 = 0x40)
    const bytesOffset = '0000000000000000000000000000000000000000000000000000000000000040';
    
    return '0x$selector$paddedHash$bytesOffset$sigLength$paddedSigData';
  }
}

/// Factory for creating LightAccount instances.
class LightAccountFactory {

  LightAccountFactory({
    required this.factoryAddress,
    required this.publicClient,
  });
  final String factoryAddress;
  final PublicClient publicClient;

  /// Creates a LightAccount instance.
  LightAccount createAccount({
    required Signer owner,
    required String entryPointAddress,
    BigInt? salt,
  }) {
    return LightAccount(
      owner: owner,
      publicClient: publicClient,
      entryPointAddress: entryPointAddress,
      factoryAddress: factoryAddress,
    );
  }

  /// Gets the address of a LightAccount without deploying it.
  Future<String> getAccountAddress({
    required String ownerAddress,
    BigInt? salt,
  }) async {
    final actualSalt = salt ?? BigInt.zero;
    
    // Call factory.getAddress(owner, salt)
    final callData = _encodeGetAddressCall(ownerAddress, actualSalt);
    
    final result = await publicClient.call(CallRequest(
      to: factoryAddress,
      data: HexUtils.decode(callData),
    ),);
    
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
