import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'dart:typed_data';

void main() async {
  // Create a random private key
  final credentials = EthPrivateKey.createRandom();
  print('Address: ${credentials.address}');

  // Sign a message
  final message = Uint8List.fromList('Hello Web3!'.codeUnits);
  final signature = await credentials.signPersonalMessage(message);
  
  print('Signature: 0x${signature.toHex()}');

  // Recover address from signature
  final recovered = EthPrivateKey.recoverPersonalMessageAddress(message, signature);
  print('Recovered: $recovered');
}

extension on Uint8List {
  String toHex() => map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
}
