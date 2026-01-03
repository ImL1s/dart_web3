import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_utxo/web3_universal_utxo.dart';

void main() {
  print('--- Web3 Universal UTXO Example ---');

  // 1. Bitcoin Address Generation (P2WPKH)
  final pk = Uint8List.fromList(List.generate(33, (i) => i + 1)); // Dummy public key
  final address = BitcoinAddress.p2wpkh(pk, network: BitcoinNetwork.mainnet);
  print('Derived SegWit Address: ${address.toAddress()}');

  // 2. Taproot Address (P2TR)
  final trAddress = BitcoinAddress.p2tr(pk, network: BitcoinNetwork.mainnet);
  print('Derived Taproot Address: ${trAddress.toAddress()}');

  // 3. Bitcoin Script Compilation
  final script = Script.build([
    OpCode.OP_DUP,
    OpCode.OP_HASH160,
    pk.sublist(0, 20),
    OpCode.OP_EQUALVERIFY,
    OpCode.OP_CHECKSIG,
  ]);
  print('P2PKH Script: ${HexUtils.encode(script.toBytes())}');

  // 4. Transaction Building (Conceptual)
  final tx = BitcoinTransaction(
    version: 2,
    inputs: [
      TransactionInput(
        prevOut: OutPoint(txId: Uint8List(32), vout: 0),
        scriptSig: Script.empty(),
        sequence: 0xFFFFFFFF,
      ),
    ],
    outputs: [
      TransactionOutput(
        value: BigInt.from(1000000), // 0.01 BTC
        scriptPubKey: script,
      ),
    ],
  );
  print('Serialized TX size: ${tx.toBytes().length} bytes');
}
