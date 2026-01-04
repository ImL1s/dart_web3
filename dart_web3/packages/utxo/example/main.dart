import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_utxo/web3_universal_utxo.dart';

void main() {
  print('--- Web3 Universal UTXO Example ---');

  // 1. Bitcoin Address Generation (P2WPKH)
  final pk = Uint8List.fromList(List.generate(33, (i) => i + 1)); // Dummy public key
  final pkHash = Ripemd160.hash(Sha256.hash(pk));
  
  final address = P2WPKHAddress(pkHash, NetworkType.bitcoinMainnet);
  print('Derived SegWit Address: ${address.address}');

  // 2. Taproot Address (P2TR)
  // Taproot uses Schnorr pubkey (32 bytes), x-only.
  final trAddress = P2TRAddress(pk.sublist(1), NetworkType.bitcoinMainnet);
  print('Derived Taproot Address: ${trAddress.address}');

  // 3. Bitcoin Script Compilation
  final script = Script([
    OpCode.opDup,
    OpCode.opHash160,
    pkHash,
    OpCode.opEqualVerify,
    OpCode.opCheckSig,
  ]);
  print('P2PKH Script: ${HexUtils.encode(script.compile())}');
}
