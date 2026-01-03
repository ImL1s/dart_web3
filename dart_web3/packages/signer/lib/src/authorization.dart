import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// EIP-7702 authorization for EOA code delegation.
class Authorization {

  Authorization({
    required this.chainId,
    required this.address,
    required this.nonce,
    int? yParity,
    BigInt? r,
    BigInt? s,
  }) : yParity = yParity ?? 0,
       r = r ?? BigInt.zero,
       s = s ?? BigInt.zero;

  /// Creates an unsigned authorization.
  factory Authorization.unsigned({
    required int chainId,
    required String address,
    required BigInt nonce,
  }) {
    return Authorization(
      chainId: chainId,
      address: address,
      nonce: nonce,
    );
  }

  /// Creates an authorization from JSON.
  factory Authorization.fromJson(Map<String, dynamic> json) {
    return Authorization(
      chainId: json['chainId'] as int,
      address: json['address'] as String,
      nonce: BigInt.parse(json['nonce'] as String),
      yParity: json['yParity'] as int? ?? 0,
      r: json['r'] != null ? BigInt.parse(json['r'] as String) : BigInt.zero,
      s: json['s'] != null ? BigInt.parse(json['s'] as String) : BigInt.zero,
    );
  }

  /// Creates a revocation authorization.
  factory Authorization.revocation({
    required int chainId,
    required BigInt nonce,
  }) {
    return Authorization(
      chainId: chainId,
      address: '0x${'0' * 40}',
      nonce: nonce,
    );
  }

  /// Creates an authorization from RLP list.
  factory Authorization.fromRlpList(List<dynamic> rlpList) {
    if (rlpList.length != 6) {
      throw ArgumentError('Authorization RLP list must have 6 elements');
    }

    return Authorization(
      chainId: rlpList[0] as int,
      address: HexUtils.encode(rlpList[1] as Uint8List),
      nonce: rlpList[2] as BigInt,
      yParity: rlpList[3] as int,
      r: rlpList[4] as BigInt,
      s: rlpList[5] as BigInt,
    );
  }
  /// The chain ID.
  final int chainId;

  /// The contract address to delegate to.
  final String address;

  /// The nonce.
  final BigInt nonce;

  /// The signature y-parity (0 or 1).
  final int yParity;

  /// The signature r value.
  final BigInt r;

  /// The signature s value.
  final BigInt s;

  /// Converts this authorization to JSON.
  Map<String, dynamic> toJson() {
    return {
      'chainId': chainId,
      'address': address,
      'nonce': '0x${nonce.toRadixString(16)}',
      'yParity': yParity,
      'r': '0x${r.toRadixString(16)}',
      's': '0x${s.toRadixString(16)}',
    };
  }

  /// Creates a signed authorization.
  Authorization withSignature({
    required int yParity,
    required BigInt r,
    required BigInt s,
  }) {
    return Authorization(
      chainId: chainId,
      address: address,
      nonce: nonce,
      yParity: yParity,
      r: r,
      s: s,
    );
  }

  /// Whether this authorization is signed.
  bool get isSigned => r != BigInt.zero || s != BigInt.zero;

  /// Whether this authorization is a revocation (address is zero).
  bool get isRevocation => address == '0x${'0' * 40}';

  /// Gets the message hash for signing this authorization.
  /// 
  /// According to EIP-7702, the message to sign is:
  /// keccak256(MAGIC || chainId || address || nonce)
  /// where MAGIC = 0x05
  Uint8List getMessageHash() {
    final magic = Uint8List.fromList([0x05]);
    final chainIdBytes = BytesUtils.bigIntToBytes(BigInt.from(chainId), length: 32);
    final addressBytes = HexUtils.decode(address);
    final nonceBytes = BytesUtils.bigIntToBytes(nonce, length: 32);

    final message = BytesUtils.concat([magic, chainIdBytes, addressBytes, nonceBytes]);
    return Keccak256.hash(message);
  }

  /// Signs this authorization with the given private key.
  Authorization sign(Uint8List privateKey) {
    final messageHash = getMessageHash();
    final signature = Secp256k1.sign(messageHash, privateKey);

    final r = BytesUtils.slice(signature, 0, 32);
    final s = BytesUtils.slice(signature, 32, 64);
    final recoveryId = signature[64];

    return withSignature(
      yParity: recoveryId,
      r: BytesUtils.bytesToBigInt(r),
      s: BytesUtils.bytesToBigInt(s),
    );
  }

  /// Verifies the signature of this authorization.
  bool verifySignature(String expectedSigner) {
    if (!isSigned) return false;

    try {
      final messageHash = getMessageHash();
      
      // Reconstruct signature
      final rBytes = BytesUtils.bigIntToBytes(r, length: 32);
      final sBytes = BytesUtils.bigIntToBytes(s, length: 32);
      final signature = BytesUtils.concat([rBytes, sBytes]);

      // Recover public key using the yParity as recovery parameter
      final recoveredPublicKey = Secp256k1.recover(signature, messageHash, yParity);
      
      // Derive address from public key
      final recoveredAddress = EthereumAddress.fromPublicKey(recoveredPublicKey, Keccak256.hash);
      
      return recoveredAddress.toString().toLowerCase() == expectedSigner.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  /// Encodes this authorization for RLP encoding in transactions.
  List<dynamic> toRlpList() {
    return [
      chainId,
      HexUtils.decode(address),
      nonce,
      yParity,
      r,
      s,
    ];
  }
}
