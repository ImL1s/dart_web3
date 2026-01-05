import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

/// Secure storage instance
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Check if wallet exists
final hasWalletProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final mnemonic = await storage.read(key: 'mnemonic');
  return mnemonic != null && mnemonic.isNotEmpty;
});

/// Wallet state model
class WalletState {
  final List<String>? mnemonicWords;
  final List<ChainAccount> accounts;
  final int selectedAccountIndex;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.mnemonicWords,
    this.accounts = const [],
    this.selectedAccountIndex = 0,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    List<String>? mnemonicWords,
    List<ChainAccount>? accounts,
    int? selectedAccountIndex,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      mnemonicWords: mnemonicWords ?? this.mnemonicWords,
      accounts: accounts ?? this.accounts,
      selectedAccountIndex: selectedAccountIndex ?? this.selectedAccountIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  ChainAccount? get selectedAccount =>
      accounts.isNotEmpty ? accounts[selectedAccountIndex] : null;

  /// Get mnemonic as a single string for display
  String? get mnemonicPhrase => mnemonicWords?.join(' ');
}

/// Chain account model
class ChainAccount {
  final String address;
  final String chainName;
  final String chainId;
  final String derivationPath;
  final BigInt balance;

  const ChainAccount({
    required this.address,
    required this.chainName,
    required this.chainId,
    required this.derivationPath,
    this.balance = BigInt.zero,
  });

  ChainAccount copyWith({BigInt? balance}) {
    return ChainAccount(
      address: address,
      chainName: chainName,
      chainId: chainId,
      derivationPath: derivationPath,
      balance: balance ?? this.balance,
    );
  }
}

/// Wallet notifier for state management
class WalletNotifier extends StateNotifier<WalletState> {
  final FlutterSecureStorage _storage;

  WalletNotifier(this._storage) : super(const WalletState());

  /// Create a new wallet with a fresh mnemonic
  Future<String> createWallet() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Generate new mnemonic using dart_web3 crypto (Bip39.generate() returns List<String>)
      final words = Bip39.generate();

      // Save to secure storage as space-separated string
      final mnemonicString = words.join(' ');
      await _storage.write(key: 'mnemonic', value: mnemonicString);

      // Derive accounts for supported chains
      final accounts = _deriveAccounts(words);

      state = state.copyWith(
        mnemonicWords: words,
        accounts: accounts,
        isLoading: false,
      );

      return mnemonicString;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Import wallet from mnemonic phrase string
  Future<void> importWallet(String mnemonicPhrase) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Parse mnemonic string to words list
      final words = mnemonicPhrase.trim().split(RegExp(r'\s+'));

      // Validate mnemonic (Bip39.validate takes List<String>)
      if (!Bip39.validate(words)) {
        throw Exception('Invalid mnemonic phrase');
      }

      // Save to secure storage
      await _storage.write(key: 'mnemonic', value: mnemonicPhrase.trim());

      // Derive accounts for supported chains
      final accounts = _deriveAccounts(words);

      state = state.copyWith(
        mnemonicWords: words,
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Load wallet from storage
  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final mnemonicString = await _storage.read(key: 'mnemonic');
      if (mnemonicString == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final words = mnemonicString.split(' ');
      final accounts = _deriveAccounts(words);

      state = state.copyWith(
        mnemonicWords: words,
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Derive accounts for all supported chains
  List<ChainAccount> _deriveAccounts(List<String> words) {
    final accounts = <ChainAccount>[];

    // Use PrivateKeySigner.fromMnemonic which accepts List<String>
    // Ethereum (chainId: 1)
    final ethSigner = PrivateKeySigner.fromMnemonic(
      words,
      1,
      path: "m/44'/60'/0'/0/0",
    );
    final ethAddress = ethSigner.address.hex;

    accounts.add(ChainAccount(
      address: ethAddress,
      chainName: 'Ethereum',
      chainId: '1',
      derivationPath: "m/44'/60'/0'/0/0",
    ),);

    // Polygon (same address, different chainId)
    accounts.add(ChainAccount(
      address: ethAddress,
      chainName: 'Polygon',
      chainId: '137',
      derivationPath: "m/44'/60'/0'/0/0",
    ),);

    // Arbitrum
    accounts.add(ChainAccount(
      address: ethAddress,
      chainName: 'Arbitrum',
      chainId: '42161',
      derivationPath: "m/44'/60'/0'/0/0",
    ),);

    // BSC
    accounts.add(ChainAccount(
      address: ethAddress,
      chainName: 'BNB Chain',
      chainId: '56',
      derivationPath: "m/44'/60'/0'/0/0",
    ),);

    return accounts;
  }

  /// Select an account
  void selectAccount(int index) {
    if (index >= 0 && index < state.accounts.length) {
      state = state.copyWith(selectedAccountIndex: index);
    }
  }

  /// Clear wallet (for logout)
  Future<void> clearWallet() async {
    await _storage.delete(key: 'mnemonic');
    state = const WalletState();
  }
}

/// Wallet provider
final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return WalletNotifier(storage);
});
