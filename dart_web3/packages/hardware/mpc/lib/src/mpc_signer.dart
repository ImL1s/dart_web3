import 'dart:typed_data';

import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

import 'key_generation.dart';
import 'key_refresh.dart';
import 'mpc_types.dart';
import 'signing_coordinator.dart';

/// MPC (Multi-Party Computation) signer implementation.
/// 
/// Supports threshold signature schemes (t-of-n) where t parties out of n total
/// parties must collaborate to create a signature.
class MpcSignerImpl extends MpcSigner {

  MpcSignerImpl({
    required this.keyShare,
    required this.coordinator,
    required this.keyGeneration,
    required this.keyRefresh,
  });
  /// The key share for this party.
  final KeyShare keyShare;
  
  /// The signing coordinator for managing multi-party operations.
  final SigningCoordinator coordinator;
  
  /// The key generation manager.
  final KeyGeneration keyGeneration;
  
  /// The key refresh manager.
  final KeyRefresh keyRefresh;

  @override
  String get partyId => keyShare.partyId;

  @override
  int get threshold => keyShare.threshold;

  @override
  int get totalParties => keyShare.totalParties;

  @override
  EthereumAddress get address {
    // Derive Ethereum address from the public key
    switch (keyShare.curveType) {
      case CurveType.secp256k1:
        // For secp256k1, derive address from public key
        final publicKeyHash = Keccak256.hash(keyShare.publicKey.sublist(1)); // Remove 0x04 prefix
        final addressBytes = publicKeyHash.sublist(12); // Take last 20 bytes
        return EthereumAddress(addressBytes);
      case CurveType.ed25519:
        // For ed25519, use the public key directly as address (Solana style)
        return EthereumAddress(keyShare.publicKey.length >= 20 
            ? keyShare.publicKey.sublist(0, 20) 
            : keyShare.publicKey,);
    }
  }

  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    // Encode the transaction for signing
    final encodedTx = _encodeTransaction(transaction);
    final messageHash = Keccak256.hash(encodedTx);
    
    // Start MPC signing session
    final session = await startSigning(messageHash);
    
    try {
      // Wait for signature completion
      final signature = await session.waitForCompletion();
      
      // For transactions, we need to encode the signature with the transaction
      return _encodeSignedTransaction(transaction, signature);
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<Uint8List> signMessage(String message) async {
    // Create Ethereum personal message hash
    final messageBytes = Uint8List.fromList(message.codeUnits);
    final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);
    final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);
    final messageHash = Keccak256.hash(fullMessage);
    
    // Start MPC signing session
    final session = await startSigning(messageHash);
    
    try {
      return await session.waitForCompletion();
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<Uint8List> signTypedData(TypedData typedData) async {
    // Get the EIP-712 hash
    final messageHash = typedData.hash();
    
    // Start MPC signing session
    final session = await startSigning(messageHash);
    
    try {
      return await session.waitForCompletion();
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    // Start MPC signing session
    final session = await startSigning(hash);
    
    try {
      return await session.waitForCompletion();
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    // Encode authorization for EIP-7702
    final encoded = _encodeAuthorization(authorization);
    final messageHash = Keccak256.hash(encoded);
    
    // Start MPC signing session
    final session = await startSigning(messageHash);
    
    try {
      return await session.waitForCompletion();
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<void> startKeyGeneration() async {
    await keyGeneration.startCeremony(
      threshold: threshold,
      totalParties: totalParties,
      curveType: keyShare.curveType,
    );
  }

  @override
  Future<void> refreshKeys() async {
    await keyRefresh.refreshKeyShares(keyShare);
  }

  @override
  Future<SigningSession> startSigning(Uint8List messageHash) async {
    final request = MpcSigningRequest(
      messageHash: messageHash,
      curveType: keyShare.curveType,
      keyShareId: '${keyShare.partyId}_${keyShare.createdAt.millisecondsSinceEpoch}',
    );
    
    return coordinator.startSigningSession(request, keyShare);
  }

  /// Encodes a transaction for signing.
  Uint8List _encodeTransaction(TransactionRequest transaction) {
    final List<dynamic> txData;
    
    switch (transaction.type) {
      case TransactionType.legacy:
        txData = [
          transaction.nonce ?? BigInt.zero,
          transaction.gasPrice ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
        ];
        break;
        
      case TransactionType.eip1559:
        txData = [
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.maxPriorityFeePerGas ?? BigInt.zero,
          transaction.maxFeePerGas ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList?.map((entry) => [
            entry.address,
            entry.storageKeys,
          ],).toList() ?? [],
        ];
        break;
        
      case TransactionType.eip2930:
        txData = [
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.gasPrice ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList?.map((entry) => [
            entry.address,
            entry.storageKeys,
          ],).toList() ?? [],
        ];
        break;
        
      case TransactionType.eip4844:
        txData = [
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.maxPriorityFeePerGas ?? BigInt.zero,
          transaction.maxFeePerGas ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList?.map((entry) => [
            entry.address,
            entry.storageKeys,
          ],).toList() ?? [],
          transaction.maxFeePerBlobGas ?? BigInt.zero,
          transaction.blobVersionedHashes ?? [],
        ];
        break;
        
      case TransactionType.eip7702:
        txData = [
          transaction.chainId ?? 1,
          transaction.nonce ?? BigInt.zero,
          transaction.maxPriorityFeePerGas ?? BigInt.zero,
          transaction.maxFeePerGas ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          transaction.accessList?.map((entry) => [
            entry.address,
            entry.storageKeys,
          ],).toList() ?? [],
          transaction.authorizationList?.map((auth) => [
            auth.chainId,
            auth.address,
            auth.nonce,
            auth.yParity,
            auth.r,
            auth.s,
          ],).toList() ?? [],
        ];
        break;
    }
    
    return RLP.encode(txData);
  }

  /// Encodes a signed transaction with the signature.
  Uint8List _encodeSignedTransaction(TransactionRequest transaction, Uint8List signature) {
    // Parse signature (assuming 65-byte ECDSA signature: r(32) + s(32) + v(1))
    if (signature.length != 65) {
      throw ArgumentError('Invalid signature length: ${signature.length}');
    }
    
    final r = signature.sublist(0, 32);
    final s = signature.sublist(32, 64);
    final v = signature[64];
    
    final List<dynamic> txData;
    
    switch (transaction.type) {
      case TransactionType.legacy:
        // For legacy transactions, v includes chain ID
        final chainId = transaction.chainId ?? 1;
        final vWithChainId = v + (chainId * 2) + 35;
        
        txData = [
          transaction.nonce ?? BigInt.zero,
          transaction.gasPrice ?? BigInt.zero,
          transaction.gasLimit ?? BigInt.zero,
          transaction.to ?? '0x',
          transaction.value ?? BigInt.zero,
          transaction.data ?? Uint8List(0),
          vWithChainId,
          BigInt.parse(HexUtils.strip0x(HexUtils.encode(r)), radix: 16),
          BigInt.parse(HexUtils.strip0x(HexUtils.encode(s)), radix: 16),
        ];
        break;
        
      default:
        // For typed transactions, prepend the type byte
        final encodedTx = _encodeTransaction(transaction);
        txData = [
          ...RLP.decode(encodedTx) as List,
          v,
          BigInt.parse(HexUtils.strip0x(HexUtils.encode(r)), radix: 16),
          BigInt.parse(HexUtils.strip0x(HexUtils.encode(s)), radix: 16),
        ];
        
        final encoded = RLP.encode(txData);
        return Uint8List.fromList([transaction.type.index, ...encoded]);
    }
    
    return RLP.encode(txData);
  }

  /// Encodes an authorization for EIP-7702 signing.
  Uint8List _encodeAuthorization(Authorization authorization) {
    final encoded = AbiEncoder.encode([
      AbiUint(256), // chainId
      AbiAddress(), // address
      AbiUint(256), // nonce
    ], [
      BigInt.from(authorization.chainId),
      authorization.address,
      authorization.nonce,
    ]);
    
    return encoded;
  }
}

/// Factory for creating MPC signers with different configurations.
class MpcSignerFactory {
  /// Creates an MPC signer from a key share and coordinator.
  static MpcSignerImpl create({
    required KeyShare keyShare,
    required SigningCoordinator coordinator,
    required KeyGeneration keyGeneration,
    required KeyRefresh keyRefresh,
  }) {
    return MpcSignerImpl(
      keyShare: keyShare,
      coordinator: coordinator,
      keyGeneration: keyGeneration,
      keyRefresh: keyRefresh,
    );
  }

  /// Creates an MPC signer for secp256k1 curve (Ethereum/Bitcoin).
  static Future<MpcSignerImpl> createSecp256k1({
    required String partyId,
    required int threshold,
    required int totalParties,
    required SigningCoordinator coordinator,
    required KeyGeneration keyGeneration,
    required KeyRefresh keyRefresh,
  }) async {
    // Generate or load key share for secp256k1
    final keyShare = await keyGeneration.generateKeyShare(
      partyId: partyId,
      threshold: threshold,
      totalParties: totalParties,
      curveType: CurveType.secp256k1,
    );
    
    return create(
      keyShare: keyShare,
      coordinator: coordinator,
      keyGeneration: keyGeneration,
      keyRefresh: keyRefresh,
    );
  }

  /// Creates an MPC signer for ed25519 curve (Solana/Polkadot).
  static Future<MpcSignerImpl> createEd25519({
    required String partyId,
    required int threshold,
    required int totalParties,
    required SigningCoordinator coordinator,
    required KeyGeneration keyGeneration,
    required KeyRefresh keyRefresh,
  }) async {
    // Generate or load key share for ed25519
    final keyShare = await keyGeneration.generateKeyShare(
      partyId: partyId,
      threshold: threshold,
      totalParties: totalParties,
      curveType: CurveType.ed25519,
    );
    
    return create(
      keyShare: keyShare,
      coordinator: coordinator,
      keyGeneration: keyGeneration,
      keyRefresh: keyRefresh,
    );
  }
}
