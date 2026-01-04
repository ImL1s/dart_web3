import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'dart:typed_data';

void main() async {
  // Create a random private key
  final credentials = PrivateKeySigner.createRandom(1);
  print('Address: ${credentials.address}');

  // Sign a message
  final message = 'Hello Web3!';
  final signature = await credentials.signMessage(message);
  
  print('Signature: 0x${signature.toHex()}');

  // Recovery is not directly exposed in PrivateKeySigner API in this version
}

extension on Uint8List {
  String toHex() => map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
}
