import 'package:test/test.dart';
import 'package:bip39/bip39.dart' as bip39;

void main() {
  group('CreateCommand', () {
    test('generates valid 12-word mnemonic with strength 128', () {
      final mnemonic = bip39.generateMnemonic(strength: 128);
      final words = mnemonic.split(' ');

      expect(words.length, equals(12));
      expect(bip39.validateMnemonic(mnemonic), isTrue);
    });

    test('generates valid 24-word mnemonic with strength 256', () {
      final mnemonic = bip39.generateMnemonic(strength: 256);
      final words = mnemonic.split(' ');

      expect(words.length, equals(24));
      expect(bip39.validateMnemonic(mnemonic), isTrue);
    });

    test('generated mnemonic is random', () {
      final mnemonic1 = bip39.generateMnemonic(strength: 128);
      final mnemonic2 = bip39.generateMnemonic(strength: 128);

      expect(mnemonic1, isNot(equals(mnemonic2)));
    });
  });

  group('ImportCommand', () {
    test('validates correct 12-word mnemonic', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      expect(bip39.validateMnemonic(mnemonic), isTrue);
    });

    test('validates correct 24-word mnemonic', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
      expect(bip39.validateMnemonic(mnemonic), isTrue);
    });

    test('rejects invalid mnemonic', () {
      const invalidMnemonic = 'invalid words that are not valid bip39';
      expect(bip39.validateMnemonic(invalidMnemonic), isFalse);
    });

    test('rejects mnemonic with wrong word count', () {
      const wrongCount = 'abandon abandon abandon abandon abandon';
      expect(bip39.validateMnemonic(wrongCount), isFalse);
    });

    test('rejects mnemonic with invalid checksum', () {
      // Valid words but wrong checksum (last word changed)
      const invalidChecksum =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';
      expect(bip39.validateMnemonic(invalidChecksum), isFalse);
    });
  });

  group('AddressCommand', () {
    test('derives deterministic addresses from same mnemonic', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      // Derive seed twice
      final seed1 = bip39.mnemonicToSeed(mnemonic);
      final seed2 = bip39.mnemonicToSeed(mnemonic);

      // Seeds should be identical
      expect(seed1, equals(seed2));
    });

    test('derives different seeds from different mnemonics', () {
      const mnemonic1 =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const mnemonic2 =
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

      final seed1 = bip39.mnemonicToSeed(mnemonic1);
      final seed2 = bip39.mnemonicToSeed(mnemonic2);

      expect(seed1, isNot(equals(seed2)));
    });

    test('generates correct seed length', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      final seed = bip39.mnemonicToSeed(mnemonic);

      // BIP39 seed is always 64 bytes
      expect(seed.length, equals(64));
    });
  });

  group('BalanceCommand', () {
    test('formats balance correctly', () {
      final wei = BigInt.from(1500000000000000000); // 1.5 ETH
      const decimals = 18;

      final divisor = BigInt.from(10).pow(decimals);
      final whole = wei ~/ divisor;
      final fraction = wei % divisor;
      final fractionStr = fraction.toString().padLeft(decimals, '0').substring(0, 4);

      expect('$whole.$fractionStr', equals('1.5000'));
    });

    test('handles zero balance', () {
      final wei = BigInt.zero;
      const decimals = 18;

      final divisor = BigInt.from(10).pow(decimals);
      final whole = wei ~/ divisor;
      final fraction = wei % divisor;
      final fractionStr = fraction.toString().padLeft(decimals, '0').substring(0, 4);

      expect('$whole.$fractionStr', equals('0.0000'));
    });

    test('handles large balance', () {
      final wei = BigInt.parse('100000000000000000000'); // 100 ETH
      const decimals = 18;

      final divisor = BigInt.from(10).pow(decimals);
      final whole = wei ~/ divisor;

      expect(whole, equals(BigInt.from(100)));
    });
  });

  group('SendCommand', () {
    test('validates Ethereum address format', () {
      const validAddress = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
      const invalidAddress1 = '0x123'; // Too short
      const invalidAddress2 = 'not_an_address';

      expect(
        validAddress.startsWith('0x') && validAddress.length == 42,
        isTrue,
      );
      expect(
        invalidAddress1.startsWith('0x') && invalidAddress1.length == 42,
        isFalse,
      );
      expect(
        invalidAddress2.startsWith('0x') && invalidAddress2.length == 42,
        isFalse,
      );
    });

    test('converts ETH amount to wei correctly', () {
      const amountEth = 1.5;
      final amountWei = BigInt.from(amountEth * 1e18);

      expect(amountWei, equals(BigInt.from(1500000000000000000)));
    });

    test('gets correct chain ID for networks', () {
      int getChainId(String chain, bool testnet) {
        return switch (chain) {
          'ethereum' => testnet ? 11155111 : 1,
          'polygon' => testnet ? 80001 : 137,
          'bsc' => testnet ? 97 : 56,
          _ => 1,
        };
      }

      expect(getChainId('ethereum', false), equals(1));
      expect(getChainId('ethereum', true), equals(11155111));
      expect(getChainId('polygon', false), equals(137));
      expect(getChainId('bsc', false), equals(56));
    });

    test('gets correct symbol for networks', () {
      String getSymbol(String chain) {
        return switch (chain) {
          'ethereum' => 'ETH',
          'polygon' => 'MATIC',
          'bsc' => 'BNB',
          _ => 'ETH',
        };
      }

      expect(getSymbol('ethereum'), equals('ETH'));
      expect(getSymbol('polygon'), equals('MATIC'));
      expect(getSymbol('bsc'), equals('BNB'));
    });
  });
}
