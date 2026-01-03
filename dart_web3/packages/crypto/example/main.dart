import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  print('--- Web3 Universal Crypto Example ---');

  // 1. Mnemonic Generation (BIP-39)
  final mnemonic = Bip39.generateMnemonic();
  print('Generated Mnemonic: $mnemonic');

  // 2. HD Wallet Derivation (BIP-32/BIP-44)
  final seed = Bip39.mnemonicToSeed(mnemonic);
  final rootNode = HDWallet.fromSeed(seed);
  final childNode = rootNode.derivePath("m/44'/60'/0'/0/0");
  print('Derived Ethereum Address: ${childNode.address}');

  // 3. Ed25519 Signing (Solana/Cosmos)
  final edKeyPair = Ed25519KeyPair.generate();
  final message = Uint8List.fromList([71, 111, 111, 103, 108, 101]);
  final edSignature = edKeyPair.sign(message);
  print('Ed25519 Signature: ${HexUtils.encode(edSignature)}');

  // 4. Schnorr Signatures (BIP-340 / Bitcoin Taproot)
  final schnorrKeyPair = SchnorrKeyPair.generate();
  final schnorrSignature = schnorrKeyPair.sign(message);
  print('Schnorr Signature: ${HexUtils.encode(schnorrSignature)}');
}
