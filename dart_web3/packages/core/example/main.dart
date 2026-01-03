import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() {
  print('--- Web3 Universal Core Example ---');

  // 1. Hex Utilities
  final bytes = Uint8List.fromList([71, 111, 111, 103, 108, 101]);
  final hex = HexUtils.encode(bytes);
  print('Hex encoded: 0x$hex');

  // 2. Ethereum Address Handling
  const addrStr = '0x1234567890123456789012345678901234567890';
  final address = EthereumAddress.fromHex(addrStr);
  print('Checksum address: ${address.hex}');

  // 3. Unit Conversions (Wei/Gwei/Ether)
  final BigInt amountInWei = BigInt.from(10).pow(17); // 0.1 ETH
  final ether = EthUnit.formatEther(amountInWei);
  print('Amount: $ether ETH');

  // 4. RLP Encoding
  final rlpEncoded = RLP.encode(['hello', 100]);
  print('RLP Encoded: ${HexUtils.encode(rlpEncoded)}');
}
