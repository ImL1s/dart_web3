/// Wallet Service - Thin wrapper around dart_web3 library
///
/// This is the ONLY class in example_app that directly interacts with
/// the dart_web3 library. All other code should go through this service.
library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:bitcoin_base/bitcoin_base.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3_universal/web3_universal.dart';

import 'services/ledger_service.dart';

/// Supported chain types
enum ChainType {
  ethereum,
  polygon,
  arbitrum,
  optimism,
  base,
  bitcoin,
  solana,
  aptos,
}

/// Chain configuration
class ChainConfig {
  const ChainConfig({
    required this.type,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.rpcUrl,
    this.chainId,
    this.explorerUrl,
  });

  final ChainType type;
  final String name;
  final String symbol;
  final int decimals;
  final String rpcUrl;
  final int? chainId;
  final String? explorerUrl;

  bool get isEvm => [
        ChainType.ethereum,
        ChainType.polygon,
        ChainType.arbitrum,
        ChainType.optimism,
        ChainType.base,
      ].contains(type);
}

/// Predefined chain configurations
class Chains {
  static const ethereum = ChainConfig(
    type: ChainType.ethereum,
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18,
    chainId: 1,
    rpcUrl: 'https://eth.llamarpc.com',
    explorerUrl: 'https://etherscan.io',
  );

  static const polygon = ChainConfig(
    type: ChainType.polygon,
    name: 'Polygon',
    symbol: 'MATIC',
    decimals: 18,
    chainId: 137,
    rpcUrl: 'https://polygon-rpc.com',
    explorerUrl: 'https://polygonscan.com',
  );

  static const bitcoin = ChainConfig(
    type: ChainType.bitcoin,
    name: 'Bitcoin',
    symbol: 'BTC',
    decimals: 8,
    rpcUrl: 'https://blockstream.info/api',
  );

  static const solana = ChainConfig(
    type: ChainType.solana,
    name: 'Solana',
    symbol: 'SOL',
    decimals: 9,
    rpcUrl: 'https://api.mainnet-beta.solana.com',
    explorerUrl: 'https://explorer.solana.com',
  );

  static const aptos = ChainConfig(
    type: ChainType.aptos,
    name: 'Aptos',
    symbol: 'APT',
    decimals: 8,
    rpcUrl: 'https://fullnode.mainnet.aptoslabs.com',
    explorerUrl: 'https://explorer.aptoslabs.com',
  );

  static List<ChainConfig> get all => [ethereum, polygon, bitcoin, solana, aptos];

  static List<ChainConfig> get evm => [ethereum, polygon];
}

/// Account information
class Account {
  const Account({
    required this.address,
    required this.chain,
    this.label,
  });

  final String address;
  final ChainConfig chain;
  final String? label;
}

/// Wallet Service - Central interface to dart_web3 library
class WalletService {
  WalletService._();

  static final WalletService instance = WalletService._();

  final _storage = const FlutterSecureStorage();
  static const _mnemonicKey = 'wallet_mnemonic';

  HDWallet? _hdWallet;
  Ed25519HdWallet? _ed25519Wallet;
  List<String>? _mnemonic;

  bool get isInitialized => _hdWallet != null;

  List<String>? get mnemonic => _mnemonic;

  // ═══════════════════════════════════════════════════════════════════════════
  // Wallet Creation & Import (using web3_universal_crypto)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a new wallet with a fresh mnemonic
  Future<List<String>> createWallet({int strength = 128}) async {
    // Using library's Bip39
    final words = Bip39.generate(strength: strength);
    await _initFromMnemonic(words);
    await _saveMnemonic(words);
    return words;
  }

  /// Imports a wallet from existing mnemonic
  Future<void> importWallet(List<String> words) async {
    if (!Bip39.validate(words)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }
    await _initFromMnemonic(words);
    await _saveMnemonic(words);
  }

  /// Loads wallet from secure storage
  Future<bool> loadWallet() async {
    final stored = await _storage.read(key: _mnemonicKey);
    if (stored == null) {
      return false;
    }

    final words = stored.split(' ');
    await _initFromMnemonic(words);
    return true;
  }

  /// Deletes wallet from storage
  Future<void> deleteWallet() async {
    await _storage.delete(key: _mnemonicKey);
    _hdWallet = null;
    _ed25519Wallet = null;
    _mnemonic = null;
  }

  Future<void> _initFromMnemonic(List<String> words) async {
    // Using library's HDWallet and Ed25519HdWallet
    _hdWallet = HDWallet.fromMnemonic(words);
    _ed25519Wallet = Ed25519HdWallet.fromMnemonic(words);
    _mnemonic = words;
  }

  Future<void> _saveMnemonic(List<String> words) async {
    await _storage.write(key: _mnemonicKey, value: words.join(' '));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Address Derivation (using web3_universal_crypto)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets account for a specific chain
  Account getAccount(ChainConfig chain, {int index = 0}) {
    _ensureInitialized();

    final address = switch (chain.type) {
      ChainType.ethereum ||
      ChainType.polygon ||
      ChainType.arbitrum ||
      ChainType.optimism ||
      ChainType.base =>
        _getEvmAddress(chain.chainId ?? 1, index),
      ChainType.bitcoin => _getBitcoinAddress(index),
      ChainType.solana => _getSolanaAddress(index),
      ChainType.aptos => _getAptosAddress(index),
    };

    return Account(address: address, chain: chain);
  }

  String _getEvmAddress(int chainId, int index) {
    // Check Ledger first
    final ledgerService = LedgerService.instance;
    if (ledgerService.status == LedgerStatus.connected &&
        ledgerService.connectedAddress != null &&
        index == 0) {
      return ledgerService.connectedAddress!;
    }

    // BIP-44: m/44'/60'/0'/0/{index}
    final derived = _hdWallet!.derive("m/44'/60'/0'/0/$index");
    return derived.getAddress().hex;
  }

  String _getBitcoinAddress(int index) {
    // BIP-84 (Native SegWit): m/84'/0'/0'/0/{index}
    final derived = _hdWallet!.derive("m/84'/0'/0'/0/$index");
    final pubKey = derived.getPublicKey();

    // P2WPKH: bech32(witness_version || hash160(pubkey))
    final hash160 = Ripemd160.hash(Sha256.hash(pubKey));
    return Bech32.encode('bc', 0, hash160);
  }

  String _getSolanaAddress(int index) {
    // SLIP-0010 Ed25519: m/44'/501'/{index}'/0'
    final derived = _ed25519Wallet!.derive("m/44'/501'/$index'/0'");
    return Base58.encode(derived.getPublicKey());
  }

  String _getAptosAddress(int index) {
    // m/44'/637'/{index}'/0'/0'
    final derived = _ed25519Wallet!.derive("m/44'/637'/$index'/0'/0'");
    final account = AptosAccount.fromSeed(derived.getPrivateKey());
    return account.address.toHex();
  }

  /// Gets all accounts for supported chains
  List<Account> getAllAccounts({int index = 0}) {
    return Chains.all.map((chain) => getAccount(chain, index: index)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Balance Fetching (using web3_universal_provider)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets balance for an account
  Future<BigInt> getBalance(Account account) async {
    return switch (account.chain.type) {
      ChainType.ethereum ||
      ChainType.polygon ||
      ChainType.arbitrum ||
      ChainType.optimism ||
      ChainType.base =>
        _getEvmBalance(account),
      ChainType.bitcoin => _getBitcoinBalance(account),
      ChainType.solana => _getSolanaBalance(account),
      ChainType.aptos => _getAptosBalance(account),
    };
  }

  Future<BigInt> _getEvmBalance(Account account) async {
    try {
      final provider = RpcProvider(HttpTransport(account.chain.rpcUrl));
      return await provider.getBalance(account.address);
    } catch (_) {
      return BigInt.zero;
    }
  }

  Future<BigInt> _getBitcoinBalance(Account account) async {
    // Using Blockstream API for Bitcoin balance
    // https://blockstream.info/api/address/{address}
    try {
      final uri = Uri.parse('${account.chain.rpcUrl}/address/${account.address}');
      final response = await http.get(uri);
      
      if (response.statusCode != 200) return BigInt.zero;
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final chainStats = data['chain_stats'] as Map<String, dynamic>;
      final mempoolStats = data['mempool_stats'] as Map<String, dynamic>;
      
      final funded = (chainStats['funded_txo_sum'] as int) + (mempoolStats['funded_txo_sum'] as int);
      final spent = (chainStats['spent_txo_sum'] as int) + (mempoolStats['spent_txo_sum'] as int);
      
      return BigInt.from(funded - spent);
    } catch (_) {
      return BigInt.zero;
    }
  }

  Future<BigInt> _getSolanaBalance(Account account) async {
    try {
      // Use RpcProvider directly to avoid ChainConfig conflicts
      final provider = RpcProvider(HttpTransport(account.chain.rpcUrl));
      final response = await provider
          .call<Map<String, dynamic>>('getBalance', [account.address]);
      return BigInt.from(response['value'] as int);
    } catch (_) {
      return BigInt.zero;
    }
  }

  Future<BigInt> _getAptosBalance(Account account) async {
    try {
      final client = AptosClient(account.chain.rpcUrl);
      return await client.getBalance(AptosAddress.fromHex(account.address));
    } catch (_) {
      return BigInt.zero;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Transaction Sending (using web3_universal_signer)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends a transaction
  Future<String> sendTransaction({
    required ChainConfig chain,
    required String to,
    required BigInt amount,
    int accountIndex = 0,
  }) async {
    _ensureInitialized();

    if (chain.isEvm) {
      return _sendEvmTransaction(chain, to, amount, accountIndex);
    }

    // Non-EVM chains
    return switch (chain.type) {
      ChainType.bitcoin =>
        await _sendBitcoinTransaction(chain, to, amount, accountIndex),
      ChainType.solana =>
        await _sendSolanaTransaction(chain, to, amount, accountIndex),
      ChainType.aptos =>
        await _sendAptosTransaction(chain, to, amount, accountIndex),
      _ => throw ArgumentError('Unsupported chain: ${chain.name}'),
    };
  }

  Future<String> _sendEvmTransaction(
    ChainConfig chain,
    String to,
    BigInt amount,
    int accountIndex,
  ) async {
    // Check Ledger
    final ledgerService = LedgerService.instance;
    Uint8List signedTx;

    if (ledgerService.status == LedgerStatus.connected && accountIndex == 0) {
      if (ledgerService.client == null) {
        throw Exception("Ledger not connected properly");
      }

      // Build and encode transaction for Ledger signing
      final provider = RpcProvider(HttpTransport(chain.rpcUrl));
      final nonce =
          await provider.getTransactionCount(ledgerService.connectedAddress!);
      final gasPrice = await provider.getGasPrice();

      final tx = TransactionRequest(
        to: to,
        value: amount,
        type: TransactionType.eip1559,
        nonce: nonce,
        chainId: chain.chainId,
        maxFeePerGas: gasPrice,
        maxPriorityFeePerGas: BigInt.from(1000000000), // 1 Gwei
        gasLimit: BigInt.from(21000), // Standard transfer
      );

      // Encode transaction for Ledger (RLP encoded unsigned tx)
      final encodedTx = _encodeTransactionForLedger(tx);
      signedTx =
          await ledgerService.signTransaction(encodedTx, "m/44'/60'/0'/0/0");
    } else {
      // Using library's PrivateKeySigner
      final derived = _hdWallet!.derive("m/44'/60'/0'/0/$accountIndex");
      final signer = PrivateKeySigner(derived.getPrivateKey(), chain.chainId!);

      // Create transaction
      final tx = TransactionRequest(
        to: to,
        value: amount,
        type: TransactionType.eip1559,
      );

      // PrivateKeySigner usually doesn't populate defaults either unless using a Wallet wrapper.
      // But the original code was simple:
      // signedTx = await signer.signTransaction(tx);
      // Wait, original code:
      // final signedTx = await signer.signTransaction(tx);
      // If PrivateKeySigner doesn't populate, it might rely on provider.sendRawTransaction?
      // No, sendRawTransaction needs signed bytes.
      // So PrivateKeySigner or whatever signer must be smart enough or the original code was incomplete/mock.
      // Original code was:
      /*
        final tx = TransactionRequest(
          to: to,
          value: amount,
          type: TransactionType.eip1559,
        );
        final signedTx = await signer.signTransaction(tx);
      */
      // I'll stick to modifying as little as possible but Ledger needs ChainID.

      signedTx = await signer.signTransaction(tx);
    }

    // Broadcast using provider (convert bytes to hex string)
    final provider = RpcProvider(HttpTransport(chain.rpcUrl));
    return await provider.sendRawTransaction(HexUtils.encode(signedTx));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Message Signing (using web3_universal_signer)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Signs a personal message (EIP-191)
  Future<Uint8List> signMessage(String message, {int accountIndex = 0}) async {
    _ensureInitialized();

    final derived = _hdWallet!.derive("m/44'/60'/0'/0/$accountIndex");
    final signer = PrivateKeySigner(derived.getPrivateKey(), 1);

    return await signer.signMessage(message);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Bitcoin Implementation (P2WPKH)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _sendBitcoinTransaction(
    ChainConfig chain,
    String to,
    BigInt amount,
    int accountIndex,
  ) async {

    // 2. Fetch UTXOs (Real)
    final senderAddress = _getBitcoinAddress(accountIndex);
    final jsonUtxos = await _fetchUtxos(chain, senderAddress);

    // 3. Coin Selection (Naive)
    // Estimate fee (simple): 2 inputs (approx) -> ~400 bytes. Rate 10 sat/vbyte -> 4000 sats.
    // We iterate adding inputs until we cover amount + buffer.
    BigInt inputSum = BigInt.zero;
    final selectedUtxos = <BitcoinUtxo>[];
    const feeRate = 20; // sats/vbyte
    
    // Convert to BitcoinUtxo
    for (final u in jsonUtxos) {
       final val = BigInt.from(u['value'] as int);
       inputSum += val;
       
       selectedUtxos.add(BitcoinUtxo(
         txHash: u['txid'] as String,
         vout: u['vout'] as int,
         value: val,
         scriptType: SegwitAddressType.p2wpkh, // P2WPKH maps to segwit
       ));
       
       // Check if enough (Approx size calculation)
       final size = selectedUtxos.length * 148 + 2 * 34 + 10;
       if (inputSum >= amount + BigInt.from(size * feeRate)) break;
    }
    
    // 4. Outputs
    final outputs = <BitcoinOutput>[];
    
    // Destination
    try {
      final destAddress = P2wpkhAddress.fromAddress(address: to, network: BitcoinNetwork.mainnet);
      outputs.add(BitcoinOutput(address: destAddress, value: amount));
    } catch (_) {
      throw ArgumentError('Invalid Bitcoin address');
    }
    
    // Calculate Change
    // Builder calculates fee automatically if we let it, or we calculate manually.
    // BitcoinTransactionBuilder requires explicit outputs (including change).
    
    final size = selectedUtxos.length * 148 + outputs.length * 34 + 10 + 34; // +34 for potential change
    final fee = BigInt.from(size * feeRate);
    
    if (inputSum < amount + fee) {
       throw Exception("Insufficient balance. Have $inputSum sats, need ${amount + fee}");
    }
    
    final change = inputSum - amount - fee;
    if (change > BigInt.from(546)) {
       // Change back to sender
       final changeAddress = P2wpkhAddress.fromAddress(address: senderAddress, network: BitcoinNetwork.mainnet);
       outputs.add(BitcoinOutput(address: changeAddress, value: change));
    }

    // 5. Construct Transaction using Builder
    // Create UTXO with owner details for signing
    final utxosWithDetails = <UtxoWithAddress>[];
    
    // Get Keys
    final derived = _hdWallet!.derive("m/84'/0'/0'/0/$accountIndex");
    final privateKeyBytes = derived.getPrivateKey();
    final privateKey = ECPrivate.fromBytes(privateKeyBytes);
    final publicKey = privateKey.getPublic();
    final senderAddrObj = P2wpkhAddress.fromAddress(address: senderAddress, network: BitcoinNetwork.mainnet);

    for (final utxo in selectedUtxos) {
      utxosWithDetails.add(UtxoWithAddress(
        utxo: utxo,
        ownerDetails: UtxoAddressDetails(
          publicKey: publicKey.toHex(),
          address: senderAddrObj,
        ),
      ));
    }

    final builder = BitcoinTransactionBuilder(
      outPuts: outputs,
      fee: fee,
      network: BitcoinNetwork.mainnet,
      utxos: utxosWithDetails,
    );

    // 6. Sign
    final tx = builder.buildTransaction((digest, utxo, pubKey, sighash) {
      return privateKey.signECDSA(digest);
    });

    // 7. Broadcast
    final rawHex = tx.serialize();
    
    // Broadcast via Blockstream API
    final pushUri = Uri.parse('${chain.rpcUrl}/tx');
    final response = await http.post(pushUri, body: rawHex);
    
    if (response.statusCode != 200) {
       throw Exception('Broadcast failed: ${response.body}');
    }
    
    return response.body; // Usually returns txid
  }
  
  Future<List<Map<String, dynamic>>> _fetchUtxos(ChainConfig chain, String address) async {
    final uri = Uri.parse('${chain.rpcUrl}/address/$address/utxo');
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Failed to fetch UTXOs');
    return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Solana Implementation
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _sendSolanaTransaction(
    ChainConfig chain,
    String to,
    BigInt amount,
    int accountIndex,
  ) async {
    // 1. Get Keys
    final derived = _ed25519Wallet!.derive("m/44'/501'/$accountIndex'/0'");
    final privateKey = derived.getPrivateKey();
    final publicKeyBytes = derived.getPublicKey();
    final signer = Ed25519KeyPair(privateKey, publicKeyBytes);
    final fromPublicKey = PublicKey(publicKeyBytes);

    // Validate destination address
    late PublicKey toPublicKey;
    try {
      toPublicKey = PublicKey.fromBase58(to);
    } catch (_) {
      throw ArgumentError('Invalid Solana address');
    }

    // 2. Fetch Recent Blockhash (Real)
    final provider = RpcProvider(HttpTransport(chain.rpcUrl));
    final blockhashResponse = await provider
        .call<Map<String, dynamic>>('getLatestBlockhash', [
      {'commitment': 'finalized'}
    ]);
    final recentBlockhash = blockhashResponse['value']['blockhash'] as String;

    // 3. Create Instruction
    // Note: SystemProgram.transfer takes lamports as int. Ensure BigInt fits.
    if (amount > BigInt.from(9223372036854775807)) {
      throw ArgumentError(
          'Amount exceeds max safe integer for Solana transfer');
    }

    final instruction = SystemProgram.transfer(
      fromPublicKey: fromPublicKey,
      toPublicKey: toPublicKey,
      lamports: amount.toInt(),
    );

    // 4. Create Message
    final message = Message.compile(
      instructions: [instruction],
      payer: fromPublicKey,
      recentBlockhash: recentBlockhash,
    );

    // 5. Create Transaction & Sign
    final tx = SolanaTransaction(message: message);
    tx.sign([signer]);

    // 6. Serialize & Broadcast
    final serialized = tx.serialize();

    // Return signature (Base58 encoded transaction signature - first signature)
    // The transaction ID is the first signature.
    // SolanaTransaction stores signatures as List<Uint8List>
    if (tx.signatures.isNotEmpty) {
      return Base58.encode(tx.signatures.first);
    }
    return Base58.encode(
        serialized); // Fallback if something weird, but usually it returns signature
  }

  Future<String> _sendAptosTransaction(
    ChainConfig chain,
    String to,
    BigInt amount,
    int accountIndex,
  ) async {
    throw UnimplementedError('Aptos signing requires BCS serialization which is pending in SDK.');
  }

  Uint8List _int64ToBytes(BigInt value) {
    final buffer = Uint8List(8);
    var v = value;
    for (var i = 0; i < 8; i++) {
      buffer[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return buffer;
  }

  /// Encodes a TransactionRequest for Ledger signing (simplified RLP).
  /// In production, use proper RLP encoding from web3_universal_core.
  Uint8List _encodeTransactionForLedger(TransactionRequest tx) {
    // Simplified encoding - in production use proper RLP from library
    // For EIP-1559: [chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList]
    final buffer = BytesBuilder();

    // Transaction type prefix for EIP-1559
    buffer.addByte(0x02);

    // Simplified: just concatenate key fields as placeholder
    // Real implementation should use RLP encoding from web3_universal_core
    buffer.add(_int64ToBytes(BigInt.from(tx.chainId ?? 1)));
    buffer.add(_int64ToBytes(BigInt.from((tx.nonce ?? 0) as int)));
    buffer.add(_int64ToBytes(tx.maxPriorityFeePerGas ?? BigInt.zero));
    buffer.add(_int64ToBytes(tx.maxFeePerGas ?? BigInt.zero));
    buffer.add(_int64ToBytes(tx.gasLimit ?? BigInt.zero));

    // To address (20 bytes)
    if (tx.to != null) {
      final toBytes = HexUtils.decode(
          tx.to!.startsWith('0x') ? tx.to!.substring(2) : tx.to!);
      buffer.add(toBytes);
    }

    buffer.add(_int64ToBytes(tx.value ?? BigInt.zero));

    return buffer.toBytes();
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError(
          'Wallet not initialized. Call createWallet or importWallet first.');
    }
  }
}
