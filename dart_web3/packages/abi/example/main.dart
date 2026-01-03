import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'dart:typed_data';

void main() {
  // Define a simple function signature
  final abi = 'transfer(address,uint256)';
  
  // Encode parameters
  final address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
  final amount = BigInt.from(1000000000000000000); // 1 ETH
  
  final encoded = ContractAbi.encode(abi, [address, amount]);
  print('Encoded data: 0x${encoded.toHex()}');

  // Decode data
  final decoded = ContractAbi.decode(abi, encoded);
  print('Decoded Address: ${decoded[0]}');
  print('Decoded Amount: ${decoded[1]}');
}

extension on Uint8List {
  String toHex() => map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
}
