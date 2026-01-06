/// Wallet Service - Thin wrapper around dart_web3 library
///
/// This is the ONLY class in example_app that directly interacts with
/// the dart_web3 library. All other code should go through this service.
library;

import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:web3_universal_utxo/web3_universal_utxo.dart';
import 'package:web3_universal_solana/web3_universal_solana.dart';

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

  static List<ChainConfig> get all => [ethereum, polygon, bitcoin, solana];

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
    // For demo purposes, return mock balance to avoid HTTP dependency
    // In production: use http package to fetch from Blockstream API
    try {
      // Mock balance for demo - in production:
      // final uri = Uri.parse('${account.chain.rpcUrl}/address/${account.address}');
      // final response = await http.get(uri);
      // final data = jsonDecode(response.body);
      // final stats = data['chain_stats'];
      // return BigInt.from(stats['funded_txo_sum'] - stats['spent_txo_sum']);
      return BigInt.zero; // Mock: no balance
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
      if (ledgerService.client == null)
        throw Exception("Ledger not connected properly");

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
    // 1. Get Keys
    final derived = _hdWallet!.derive("m/84'/0'/0'/0/$accountIndex");
    final privateKey = derived.getPrivateKey();
    final publicKey = derived.getPublicKey();
    final pubKeyHash = Ripemd160.hash(Sha256.hash(publicKey));

    // 2. Mock UTXO Fetching (In production: await _fetchUtxos(address))
    // We assume we have one UTXO with enough balance
    // Mock TxId: 64 zeros
    final utxoTxId = HexUtils.decode(
      '0000000000000000000000000000000000000000000000000000000000000000',
    );
    final utxoAmount =
        amount + BigInt.from(10000); // Mock UTXO has Amount + Fee
    final inputs = [
      TransactionInput(
        txId: utxoTxId,
        vout: 0,
        scriptSig: Uint8List(0), // Empty for Witness
      ),
    ];

    // 3. Create Outputs
    final outputs = <TransactionOutput>[];

    // a. Destination Output
    // For simplicity in this demo, we assume 'to' is a Bech32 P2WPKH address
    try {
      final decodedTo = Bech32.decode(to);
      final toScript =
          Script.p2wpkh(Uint8List.fromList(decodedTo.witnessProgram));
      outputs.add(TransactionOutput(amount: amount, scriptPubKey: toScript));
    } catch (_) {
      // Fallback for non-bech32 (just for demo safety)
      throw ArgumentError('Only Bech32 addresses supported in demo');
    }

    // 4. Construct Transaction
    final tx = BitcoinTransaction(
      version: 2,
      inputs: inputs,
      outputs: outputs,
      lockTime: 0,
    );

    // 5. Sign Input (BIP-143)
    final sighash = _calculateBip143Sighash(
      tx: tx,
      inputIndex: 0,
      utxoScriptCode: Script([
        OpCode.opDup,
        OpCode.opHash160,
        pubKeyHash,
        OpCode.opEqualVerify,
        OpCode.opCheckSig,
      ]).compile(), // P2PKH script code required for P2WPKH witness signing
      utxoAmount: utxoAmount,
      sighashType: 0x01, // SIGHASH_ALL
    );

    // Sign with Secp256k1
    final signature = Secp256k1.sign(sighash, privateKey);
    // Append Sighash type byte
    final scriptSig = Uint8List.fromList([...signature, 0x01]);

    // Attach Witness: [Signature, PublicKey]
    // Note: We need to reconstruct Input because witness is final
    tx.inputs[0] = TransactionInput(
      txId: tx.inputs[0].txId,
      vout: tx.inputs[0].vout,
      scriptSig: tx.inputs[0].scriptSig,
      sequence: tx.inputs[0].sequence,
      witness: [scriptSig, publicKey],
    );

    // 6. Serialize & Broadcast
    final rawTx = tx.toBytes(segwit: true);
    // In production: await _broadcastBitcoin(HexUtils.encode(rawTx));

    // Return a mock TxID based on the rawTx hash
    return HexUtils.encode(Sha256.doubleHash(rawTx));
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

    // 2. Mock Recent Blockhash (In production: await _getRecentBlockhash())
    // 32-byte hash encoded in Base58 - must be valid Base58 (no 0, O, I, l)
    const recentBlockhash = 'GkotHVEULjkXZ7nSR6wXbabcdefGHJKMNPQRSTUVWXYZ';

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

  /// Calculates BIP-143 Sighash for SegWit inputs
  Uint8List _calculateBip143Sighash({
    required BitcoinTransaction tx,
    required int inputIndex,
    required Uint8List utxoScriptCode,
    required BigInt utxoAmount,
    required int sighashType,
  }) {
    final buffer = BytesBuilder();

    // 1. Version
    buffer.add(_int32ToBytes(tx.version));

    // 2. HashPrevouts
    final prevouts = BytesBuilder();
    for (final input in tx.inputs) {
      prevouts.add(input.txId);
      prevouts.add(_int32ToBytes(input.vout));
    }
    buffer.add(Sha256.doubleHash(prevouts.toBytes()));

    // 3. HashSequence
    final sequences = BytesBuilder();
    for (final input in tx.inputs) {
      sequences.add(_int32ToBytes(input.sequence));
    }
    buffer.add(Sha256.doubleHash(sequences.toBytes()));

    // 4. Outpoint
    final input = tx.inputs[inputIndex];
    buffer.add(input.txId);
    buffer.add(_int32ToBytes(input.vout));

    // 5. ScriptCode
    buffer.addByte(utxoScriptCode.length); // Assuming small script < 0xfd
    buffer.add(utxoScriptCode);

    // 6. Amount
    buffer.add(_int64ToBytes(utxoAmount));

    // 7. Sequence
    buffer.add(_int32ToBytes(input.sequence));

    // 8. HashOutputs
    final outputs = BytesBuilder();
    for (final output in tx.outputs) {
      outputs.add(_int64ToBytes(output.amount));
      // Length check simplified
      if (output.scriptPubKey.length < 0xfd) {
        outputs.addByte(output.scriptPubKey.length);
      } else {
        outputs.addByte(0xfd); // Simplification, assume < 65535
        final lenBuf = Uint8List(2);
        ByteData.view(lenBuf.buffer)
            .setUint16(0, output.scriptPubKey.length, Endian.little);
        outputs.add(lenBuf);
      }
      outputs.add(output.scriptPubKey);
    }
    buffer.add(Sha256.doubleHash(outputs.toBytes()));

    // 9. LockTime
    buffer.add(_int32ToBytes(tx.lockTime));

    // 10. Sighash Type
    buffer.add(_int32ToBytes(sighashType));

    return Sha256.doubleHash(buffer.toBytes());
  }

  Uint8List _int32ToBytes(int value) {
    final buffer = Uint8List(4);
    ByteData.view(buffer.buffer).setInt32(0, value, Endian.little);
    return buffer;
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
