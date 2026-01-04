import 'package:web3_universal/web3_universal.dart';

void main() async {
  print('--- Wallet Management Overview ---');

  // 1. Generate a new 12-word mnemonic
  final mnemonic = Bip39.generate(strength: 128);
  print('Generated Mnemonic: ${mnemonic.sentence}');

  // 2. Create an HD Wallet from the mnemonic
  final hdWallet = HDWallet.fromMnemonic(mnemonic);

  // 3. Derive multiple accounts (BIP-44)
  // Path: m/44'/60'/0'/0/index
  for (var i = 0; i < 3; i++) {
    final child = hdWallet.derivePath("m/44'/60'/0'/0/$i");
    print('Account #$i:');
    print('  Address: ${child.address}');
    print('  Public Key: ${child.publicKey}');
  }

  // 4. Create a Signer from a private key for a specific chain
  final privateKey = hdWallet.privateKey;
  final signer = PrivateKeySigner(privateKey, Chains.ethereum.chainId);

  // 5. Sign a personal message
  final message =
      "I am signing this message to prove ownership of this wallet.";
  final signature = await signer.signMessage(message);
  print('\nMessage: $message');
  print('Signature: $signature');

  // 6. Verify signature
  final recoveredAddress = CryptoUtils.ecRecover(
    CryptoUtils.hashPersonalMessage(message),
    signature,
  );
  print('Recovered Address: $recoveredAddress');
  print(
      'Verified: ${recoveredAddress.toLowerCase() == signer.address.toLowerCase()}');
}
