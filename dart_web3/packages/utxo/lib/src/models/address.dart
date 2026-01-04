import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'networks.dart';

enum AddressType {
  p2pkh,
  p2sh,
  p2wpkh,
  p2wsh,
  p2tr,
}

abstract class BitcoinAddress {
  String get address;
  AddressType get type;
  Uint8List get scriptPubKey;

  static BitcoinAddress fromString(String address, {NetworkType network = NetworkType.bitcoinMainnet}) {
    // TODO: Implement decoding logic
    throw UnimplementedError();
  }
}

class P2PKHAddress extends BitcoinAddress {
  P2PKHAddress(this.hash, this.network);

  final Uint8List hash;
  final NetworkType network;

  @override
  late final String address = Base58.encodeCheck(
    Uint8List.fromList([network.pubKeyHashPrefix, ...hash]),
  );

  @override
  AddressType get type => AddressType.p2pkh;

  @override
  late final Uint8List scriptPubKey = Uint8List.fromList([
    0x76, // OP_DUP
    0xa9, // OP_HASH160
    0x14, // Push 20 bytes
    ...hash,
    0x88, // OP_EQUALVERIFY
    0xac, // OP_CHECKSIG
  ]);
}

class P2WPKHAddress extends BitcoinAddress {
  P2WPKHAddress(this.hash, this.network);

  final Uint8List hash;
  final NetworkType network;

  @override
  late final String address = Bech32.encode(
    network.bech32Hrp,
    0,
    hash,
  );

  @override
  AddressType get type => AddressType.p2wpkh;

  @override
  late final Uint8List scriptPubKey = Uint8List.fromList([
    0x00, // Version 0
    0x14, // Push 20 bytes
    ...hash,
  ]);
}

class P2TRAddress extends BitcoinAddress {
  P2TRAddress(this.hash, this.network);

  final Uint8List hash; // 32 bytes x-only pubkey
  final NetworkType network;

  @override
  late final String address = Bech32.encode(
    network.bech32Hrp,
    1,
    hash,
  );

  @override
  AddressType get type => AddressType.p2tr;

  @override
  late final Uint8List scriptPubKey = Uint8List.fromList([
    0x51, // Version 1 (OP_1)
    0x20, // Push 32 bytes
    ...hash,
  ]);
}

