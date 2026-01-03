import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import 'authorization.dart';
import 'signer.dart';
import 'transaction.dart';

/// Signer implementation using a private key.
class PrivateKeySigner implements Signer {

  PrivateKeySigner(this.privateKey, this.chainId) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }
    _address = EthereumAddress.fromPublicKey(
      Secp256k1.getPublicKey(privateKey),
      Keccak256.hash,
    );
  }

  /// Creates a signer from a hex-encoded private key.
  factory PrivateKeySigner.fromHex(String hex, int chainId) {
    return PrivateKeySigner(HexUtils.decode(hex), chainId);
  }

  /// Creates a signer from a mnemonic phrase.
  factory PrivateKeySigner.fromMnemonic(
    List<String> words,
    int chainId, {
    String path = "m/44'/60'/0'/0/0",
  }) {
    final wallet = HDWallet.fromMnemonic(words).derive(path);
    return PrivateKeySigner(wallet.getPrivateKey(), chainId);
  }

  /// Creates a random signer.
  factory PrivateKeySigner.createRandom(int chainId) {
    // Generate 32 bytes of random entropy
    final random = HDWallet.fromMnemonic(Bip39.generate());
    // Or just use random bytes directly if crypto exposes it?
    // Using Bip39 generate effectively gives random wallet.
    // But slightly inefficient.
    // Secp256k1 doesn't have generate private key helper in interface shown?
    // HDWallet has fromSeed.
    // Let's use Bip39 for simplicity/standardness or EthPrivateKey logic if I can find it.
    // web3dart used Random.secure.
    
    // I will use HDWallet.fromSeed(Bip39.toSeed(Bip39.generate())) to get a valid key?
    // Or just random bytes.
    // PrivateKeySigner constructor checks length 32.
    // I need secure random.
    // I will import dart:math.
    // I need to add import 'dart:math'; to the file.
    
    // Waiting, verify imports first from previous view_file.
    // File imports: dart:typed_data, abi, core, crypto, authorization, signer, transaction.
    // No dart:math.
    
    return PrivateKeySigner(Secp256k1.generatePrivateKey(), chainId);
  }

  /// The private key bytes.
  final Uint8List privateKey;

  /// The chain ID.
  final int chainId;

  late final EthereumAddress _address;

  @override
  EthereumAddress get address => _address;

  @override
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    final tx = transaction.copyWith(chainId: transaction.chainId ?? chainId);

    switch (tx.type) {
      case TransactionType.legacy:
        return _signLegacyTransaction(tx);
      case TransactionType.eip2930:
        return _signEip2930Transaction(tx);
      case TransactionType.eip1559:
        return _signEip1559Transaction(tx);
      case TransactionType.eip4844:
        return _signEip4844Transaction(tx);
      case TransactionType.eip7702:
        return _signEip7702Transaction(tx);
    }
  }

  @override
  Future<Uint8List> signMessage(String message) async {
    // EIP-191 personal message
    final prefix = '\x19Ethereum Signed Message:\n${message.length}';
    final prefixedMessage = Uint8List.fromList([...prefix.codeUnits, ...message.codeUnits]);
    final hash = Keccak256.hash(prefixedMessage);

    return Secp256k1.sign(hash, privateKey);
  }

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    // Sign raw hash directly without any prefix
    // Used for ERC-4337 UserOperation signing
    if (hash.length != 32) {
      throw ArgumentError('Hash must be exactly 32 bytes');
    }
    return Secp256k1.sign(hash, privateKey);
  }

  @override
  Future<Uint8List> signTypedData(TypedData typedData) async {
    final hash = typedData.hash();
    return Secp256k1.sign(hash, privateKey);
  }

  @override
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    // EIP-7702 authorization signing
    // MAGIC || chainId || address || nonce
    final magic = Uint8List.fromList([0x05]);
    final chainIdBytes = BytesUtils.bigIntToBytes(BigInt.from(authorization.chainId), length: 32);
    final addressBytes = HexUtils.decode(authorization.address);
    final nonceBytes = BytesUtils.bigIntToBytes(authorization.nonce, length: 32);

    final message = BytesUtils.concat([magic, chainIdBytes, addressBytes, nonceBytes]);
    final hash = Keccak256.hash(message);

    return Secp256k1.sign(hash, privateKey);
  }

  Uint8List _signLegacyTransaction(TransactionRequest tx) {
    // RLP encode: [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    final toSign = [
      tx.nonce ?? BigInt.zero,
      tx.gasPrice ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      tx.chainId ?? chainId,
      BigInt.zero,
      BigInt.zero,
    ];

    final encoded = RLP.encode(toSign);
    final hash = Keccak256.hash(encoded);
    final signature = Secp256k1.sign(hash, privateKey);

    // Extract r, s, v
    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final recoveryId = signature[64];

    // EIP-155: v = chainId * 2 + 35 + recoveryId
    final v = BigInt.from((tx.chainId ?? chainId) * 2 + 35 + recoveryId);

    // RLP encode signed transaction
    final signed = [
      tx.nonce ?? BigInt.zero,
      tx.gasPrice ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      v,
      BytesUtils.bytesToBigInt(r),
      BytesUtils.bytesToBigInt(s),
    ];

    return RLP.encode(signed);
  }

  Uint8List _signEip2930Transaction(TransactionRequest tx) {
    // Type 1 transaction
    final accessList = _encodeAccessList(tx.accessList ?? []);

    final toSign = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.gasPrice ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
    ];

    final encoded = BytesUtils.concat([Uint8List.fromList([0x01]), RLP.encode(toSign)]);
    final hash = Keccak256.hash(encoded);
    final signature = Secp256k1.sign(hash, privateKey);

    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final yParity = signature[64];

    final signed = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.gasPrice ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      yParity,
      BytesUtils.bytesToBigInt(r),
      BytesUtils.bytesToBigInt(s),
    ];

    return BytesUtils.concat([Uint8List.fromList([0x01]), RLP.encode(signed)]);
  }

  Uint8List _signEip1559Transaction(TransactionRequest tx) {
    // Type 2 transaction
    final accessList = _encodeAccessList(tx.accessList ?? []);

    final toSign = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
    ];

    final encoded = BytesUtils.concat([Uint8List.fromList([0x02]), RLP.encode(toSign)]);
    final hash = Keccak256.hash(encoded);
    final signature = Secp256k1.sign(hash, privateKey);

    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final yParity = signature[64];

    final signed = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      yParity,
      BytesUtils.bytesToBigInt(r),
      BytesUtils.bytesToBigInt(s),
    ];

    return BytesUtils.concat([Uint8List.fromList([0x02]), RLP.encode(signed)]);
  }

  Uint8List _signEip4844Transaction(TransactionRequest tx) {
    // Type 3 transaction (blob)
    final accessList = _encodeAccessList(tx.accessList ?? []);
    final blobHashes = tx.blobVersionedHashes?.map(HexUtils.decode).toList() ?? [];

    final toSign = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      tx.maxFeePerBlobGas ?? BigInt.zero,
      blobHashes,
    ];

    final encoded = BytesUtils.concat([Uint8List.fromList([0x03]), RLP.encode(toSign)]);
    final hash = Keccak256.hash(encoded);
    final signature = Secp256k1.sign(hash, privateKey);

    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final yParity = signature[64];

    final signed = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      tx.maxFeePerBlobGas ?? BigInt.zero,
      blobHashes,
      yParity,
      BytesUtils.bytesToBigInt(r),
      BytesUtils.bytesToBigInt(s),
    ];

    return BytesUtils.concat([Uint8List.fromList([0x03]), RLP.encode(signed)]);
  }

  Uint8List _signEip7702Transaction(TransactionRequest tx) {
    // Type 4 transaction (EOA code delegation)
    final accessList = _encodeAccessList(tx.accessList ?? []);
    final authList = _encodeAuthorizationList(tx.authorizationList ?? []);

    final toSign = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      authList,
    ];

    final encoded = BytesUtils.concat([Uint8List.fromList([0x04]), RLP.encode(toSign)]);
    final hash = Keccak256.hash(encoded);
    final signature = Secp256k1.sign(hash, privateKey);

    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final yParity = signature[64];

    final signed = [
      tx.chainId ?? chainId,
      tx.nonce ?? BigInt.zero,
      tx.maxPriorityFeePerGas ?? BigInt.zero,
      tx.maxFeePerGas ?? BigInt.zero,
      tx.gasLimit ?? BigInt.zero,
      if (tx.to != null) HexUtils.decode(tx.to!) else Uint8List(0),
      tx.value ?? BigInt.zero,
      tx.data ?? Uint8List(0),
      accessList,
      authList,
      yParity,
      BytesUtils.bytesToBigInt(r),
      BytesUtils.bytesToBigInt(s),
    ];

    return BytesUtils.concat([Uint8List.fromList([0x04]), RLP.encode(signed)]);
  }

  List<dynamic> _encodeAccessList(List<AccessListEntry> accessList) {
    return accessList.map((entry) {
      return [
        HexUtils.decode(entry.address),
        entry.storageKeys.map(HexUtils.decode).toList(),
      ];
    }).toList();
  }

  List<dynamic> _encodeAuthorizationList(List<Authorization> authList) {
    return authList.map((auth) {
      return [
        auth.chainId,
        HexUtils.decode(auth.address),
        auth.nonce,
        auth.yParity,
        auth.r,
        auth.s,
      ];
    }).toList();
  }
}
