import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() {
  // Define a simple function signature
  final abi = 'transfer(address,uint256)';
  // Define types
  final types = [AbiUint(256), AbiString()];

  // Define values
  final values = [BigInt.from(123), 'Hello World'];

  // Encode
  final encoded = AbiEncoder.encode(types, values);
  print('Encoded: ${HexUtils.encode(encoded)}');

  // Decode
  final decoded = AbiDecoder.decode(types, encoded);
  print('Decoded: $decoded');

  // Decode data
  // Parse parameter types from signature
  final paramsStr = abi.substring(abi.indexOf('(') + 1, abi.lastIndexOf(')'));
  final tuple = AbiParser.parseType('($paramsStr)') as AbiTuple;

  // Skip 4-byte selector when decoding arguments
  final decodedParams = AbiDecoder.decode(tuple.components, encoded.sublist(4));
  print('Decoded Address: ${decodedParams[0]}');
  print('Decoded Amount: ${decodedParams[1]}');
}
