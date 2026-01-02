import 'dart:typed_data';

import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

import 'user_operation.dart';

/// Abstract base class for smart contract accounts.
/// 
/// A SmartAccount represents an account that is controlled by smart contract code
/// rather than a private key. This enables advanced features like:
/// - Multi-signature wallets
/// - Social recovery
/// - Spending limits
/// - Gasless transactions via paymasters
abstract class SmartAccount {
  /// Gets the address of this smart account.
  Future<String> getAddress();

  /// Gets the nonce for the next UserOperation.
  Future<BigInt> getNonce({String? key});

  /// Signs a UserOperation with this account.
  Future<String> signUserOperation(UserOperation userOp);

  /// Gets the init code for deploying this account (if not deployed).
  Future<String> getInitCode();

  /// Checks if this account is deployed on-chain.
  Future<bool> isDeployed();

  /// Encodes a function call for this account.
  String encodeCallData(String to, BigInt value, String data);

  /// Encodes multiple function calls for batch execution.
  String encodeBatchCallData(List<Call> calls);

  /// Gets the factory address used to deploy this account.
  String? get factoryAddress;

  /// Gets the account implementation address.
  String get implementationAddress;

  /// Gets the owner/signer of this account.
  Signer get owner;

  /// Gets the EntryPoint address this account is compatible with.
  String get entryPointAddress;
}

/// Represents a function call to be executed by a smart account.
class Call {

  Call({
    required this.to,
    required this.data,
    BigInt? value,
  }) : value = value ?? BigInt.zero;

  /// Creates a call from a contract method.
  factory Call.fromContract({
    required String contractAddress,
    BigInt? value,
  }) {
    // Use ABI encoder to encode the function call
    // For now, this is a placeholder
    final data = '0x'; // Encoded function call
    
    return Call(
      to: contractAddress,
      value: value ?? BigInt.zero,
      data: data,
    );
  }
  /// The target contract address.
  final String to;

  /// The value to send (in wei).
  final BigInt value;

  /// The encoded function call data.
  final String data;

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'value': '0x${value.toRadixString(16)}',
      'data': data,
    };
  }
}

/// Base implementation of SmartAccount with common functionality.
abstract class BaseSmartAccount implements SmartAccount {

  BaseSmartAccount({
    required Signer owner,
    required PublicClient publicClient,
    required String entryPointAddress,
    required String implementationAddress, String? factoryAddress,
  }) : _owner = owner,
       _publicClient = publicClient,
       _entryPointAddress = entryPointAddress,
       _factoryAddress = factoryAddress,
       _implementationAddress = implementationAddress;
  final Signer _owner;
  final PublicClient _publicClient;
  final String _entryPointAddress;
  final String? _factoryAddress;
  final String _implementationAddress;

  @override
  Signer get owner => _owner;

  @override
  String get entryPointAddress => _entryPointAddress;

  @override
  String? get factoryAddress => _factoryAddress;

  @override
  String get implementationAddress => _implementationAddress;

  /// Protected access to the public client for subclasses.
  PublicClient get publicClient => _publicClient;

  @override
  Future<BigInt> getNonce({String? key}) async {
    final address = await getAddress();
    
    // Call EntryPoint.getNonce(sender, key)
    final nonceKey = key != null ? BigInt.parse(key) : BigInt.zero;
    final callData = _encodeGetNonceCall(address, nonceKey);
    
    final result = await _publicClient.call(CallRequest(
      to: _entryPointAddress,
      data: HexUtils.decode(callData),
    ),);
    
    return BigInt.parse(HexUtils.encode(result));
  }

  @override
  Future<bool> isDeployed() async {
    final address = await getAddress();
    final code = await _publicClient.call(CallRequest(
      to: address,
      data: Uint8List(0),
    ),);
    
    return code.isNotEmpty;
  }

  @override
  Future<String> signUserOperation(UserOperation userOp) async {
    final userOpHash = userOp.getUserOpHash(
      chainId: await _publicClient.getChainId(),
      entryPointAddress: _entryPointAddress,
      entryPointVersion: EntryPointVersion.v07, // Default to v0.7
    );

    // Use signHash instead of signMessage to avoid EIP-191 prefix.
    // ERC-4337 requires signing the raw userOpHash directly.
    final hashBytes = HexUtils.decode(userOpHash);
    final signature = await _owner.signHash(hashBytes);
    return HexUtils.encode(signature);
  }

  /// Encodes a getNonce function call to the EntryPoint.
  String _encodeGetNonceCall(String sender, BigInt key) {
    // getNonce(address,uint192) function selector: 0x35567e1a
    final selector = '35567e1a';
    final paddedSender = sender.replaceFirst('0x', '').padLeft(64, '0');
    final paddedKey = key.toRadixString(16).padLeft(64, '0');
    
    return '0x$selector$paddedSender$paddedKey';
  }

  @override
  Future<String> getAddress() async {
    if (_factoryAddress == null) {
      throw StateError('Factory address is required to calculate account address');
    }

    final initCode = await getInitCode();
    final salt = await getSalt();
    
    // Use CREATE2 to calculate the address
    return _calculateCreate2Address(_factoryAddress, salt, initCode);
  }

  /// Gets the salt used for CREATE2 deployment.
  Future<String> getSalt() async {
    // Default implementation uses owner address as salt
    return _owner.address.hex;
  }

  /// Calculates CREATE2 address according to EIP-1014.
  ///
  /// address = keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
  ///
  /// Reference: https://eips.ethereum.org/EIPS/eip-1014
  String _calculateCreate2Address(String factory, String salt, String initCode) {
    // 1. Prepare factory address (20 bytes)
    final factoryBytes = HexUtils.decode(factory.replaceFirst('0x', ''));
    if (factoryBytes.length != 20) {
      throw ArgumentError('Factory address must be 20 bytes');
    }

    // 2. Prepare salt (32 bytes)
    final saltBytes = HexUtils.decode(salt.replaceFirst('0x', '').padLeft(64, '0'));
    if (saltBytes.length != 32) {
      throw ArgumentError('Salt must be 32 bytes');
    }

    // 3. Calculate initCode hash
    final initCodeBytes = HexUtils.decode(initCode.replaceFirst('0x', ''));
    final initCodeHash = Keccak256.hash(initCodeBytes);

    // 4. Concatenate: 0xff + factory (20) + salt (32) + initCodeHash (32)
    final data = Uint8List(1 + 20 + 32 + 32);
    data[0] = 0xff;
    data.setRange(1, 21, factoryBytes);
    data.setRange(21, 53, saltBytes);
    data.setRange(53, 85, initCodeHash);

    // 5. Hash and take last 20 bytes
    final hash = Keccak256.hash(data);
    final addressBytes = hash.sublist(12, 32);

    return HexUtils.encode(addressBytes);
  }
}
