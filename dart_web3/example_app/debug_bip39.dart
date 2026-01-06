import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:bip39/bip39.dart' as bip39_lib;

void main() {
  try {
    print('Generating with bip39 package...');
    final mnemonicStr = bip39_lib.generateMnemonic(strength: 128);
    final mnemonicList = mnemonicStr.split(' ');
    print('Value: $mnemonicStr');
    
    print('Validating with web3_universal_crypto...');
    final isValid = Bip39.validate(mnemonicList);
    print('Valid: $isValid');
  } catch (e) {
    print('Error: $e');
  }
}
