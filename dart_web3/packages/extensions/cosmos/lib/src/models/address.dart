import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';

class CosmosAddress {
  CosmosAddress(this.hash, {this.hrp = 'cosmos'});

  factory CosmosAddress.fromString(String address) {
    if (address.isEmpty) throw Exception('Address is empty');
    try {
      final decoded = Bech32.decodeGeneric(address);
      return CosmosAddress(decoded.data, hrp: decoded.hrp);
    } catch (e) {
      throw Exception('Invalid Bech32 address: $e');
    }
  }

  final Uint8List hash;
  final String hrp;

  String get address => Bech32.encodeGeneric(hrp, hash);
  // Bech32.encode usually handles the variant logic based on generic/Bech32 spec.
  // Standard Cosmos addresses are Bech32.

  @override
  String toString() => address;
}
