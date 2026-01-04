import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:web3_universal_abi/abi.dart' as dw3_abi;
import 'package:web3_universal_chains/chains.dart' as dw3_chains;
import 'package:web3_universal_client/client.dart';
import 'package:web3_universal_contract/contract.dart' as dw3_contract;
import 'package:web3_universal_core/core.dart' as dw3;
import 'package:web3_universal_crypto/crypto.dart' as crypto;
import 'package:web3_universal_provider/provider.dart';
import 'package:web3_universal_signer/signer.dart' as dw3_signer;

// Umbrella exports for convenience
export 'package:web3_universal_core/core.dart' show EthUnit, Unit, RLP;
export 'package:web3_universal_contract/contract.dart' hide Contract;
export 'package:web3_universal_client/client.dart'
    show PublicClient, WalletClient, CallRequest, Block, TransactionReceipt;
export 'package:web3_universal_provider/provider.dart'
    show RpcProvider, HttpTransport;
export 'package:web3_universal_chains/chains.dart' hide ChainConfig;
export 'package:web3_universal_signer/signer.dart' hide TransactionType;
export 'package:web3_universal_abi/abi.dart'
    show
        AbiParser,
        AbiEncoder,
        AbiDecoder,
        AbiFunction,
        AbiEvent,
        AbiError,
        AbiType,
        AbiString,
        AbiUint,
        AbiAddress,
        AbiTuple,
        AbiArray,
        AbiBytes,
        AbiFixedBytes;
export 'package:web3_universal_crypto/crypto.dart' hide hexToBytes, bytesToHex;

// ============================================================================
// Internal Utilities (no external dependencies)
// ============================================================================

/// Keccak256 hash
Uint8List keccak256(Uint8List input) => crypto.Keccak256.hash(input);

/// Hex encoding/decoding utilities
class HexUtils {
  static String bytesToHex(List<int> bytes, {bool include0x = false}) {
    return dw3.HexUtils.encode(Uint8List.fromList(bytes), prefix: include0x);
  }

  static Uint8List hexToBytes(String hex) {
    return dw3.HexUtils.decode(hex);
  }

  static String addHexPrefix(String hex) {
    return dw3.HexUtils.add0x(hex);
  }

  static String removeHexPrefix(String hex) {
    return dw3.HexUtils.strip0x(hex);
  }

  static bool isValidHex(String hex) {
    return dw3.HexUtils.isValid(hex);
  }

  static String padHex(String hex, int byteLength) {
    return dw3.HexUtils.pad(hex, byteLength);
  }

  static String intToHex(int value, {int? padding}) {
    String hex = value.toRadixString(16);
    if (padding != null) {
      hex = hex.padLeft(padding, '0');
    }
    return hex;
  }

  static int hexToInt(String hex) {
    return int.parse(dw3.HexUtils.strip0x(hex), radix: 16);
  }

  static String bigIntToHex(BigInt value, {int? padding}) {
    String hex = value.toRadixString(16);
    if (padding != null) {
      hex = hex.padLeft(padding, '0');
    }
    return hex;
  }

  static BigInt hexToBigInt(String hex) {
    return BigInt.parse(dw3.HexUtils.strip0x(hex), radix: 16);
  }
}

/// Address validation and normalization
class AddressUtils {
  static bool isValidEthereumAddress(String address) {
    return dw3.EthereumAddress.isValid(address);
  }

  static String normalizeAddress(String address) {
    if (!isValidEthereumAddress(address)) {
      throw ArgumentError('Invalid Ethereum address: $address');
    }
    return dw3.EthereumAddress.fromHex(address).hex;
  }

  static bool addressEquals(String a, String b) {
    try {
      final addrA = dw3.EthereumAddress.fromHex(a);
      final addrB = dw3.EthereumAddress.fromHex(b);
      return addrA == addrB;
    } catch (_) {
      return false;
    }
  }
}

/// Unit conversion utilities
class UnitUtils {
  static BigInt etherToWei(String ether) => dw3.EthUnit.ether(ether);
  static BigInt gweiToWei(String gwei) => dw3.EthUnit.gwei(gwei);
  static String weiToEther(BigInt wei) => dw3.EthUnit.formatEther(wei);
  static String weiToGwei(BigInt wei) => dw3.EthUnit.formatGwei(wei);

  static BigInt toTokenUnit(Decimal amount, int decimals) {
    final multiplier = Decimal.parse('10').pow(decimals).toDecimal();
    return (amount * multiplier).toBigInt();
  }

  static Decimal fromTokenUnit(BigInt value, int decimals) {
    if (decimals == 0) return Decimal.fromBigInt(value);
    final divisor = Decimal.parse('10').pow(decimals).toDecimal();
    return (Decimal.fromBigInt(value) / divisor).toDecimal();
  }
}

// ============================================================================
// web3dart Compatibility Layer
// ============================================================================

typedef EthereumAddress = dw3.EthereumAddress;
typedef Web3Address = dw3.EthereumAddress;
typedef Web3Contract = dw3_contract.Contract;
typedef Web3ChainConfig = dw3_chains.ChainConfig;
typedef Web3TransactionType = dw3_signer.TransactionType;

/// Legacy bytesToUnsignedInt compatibility
BigInt bytesToUnsignedInt(Uint8List bytes) {
  return dw3.BytesUtils.bytesToBigInt(bytes);
}

/// Legacy ecRecover compatibility
Uint8List ecRecover(Uint8List hash, MsgSignature sig) {
  final v = sig.v >= 27 ? sig.v - 27 : sig.v;
  final signature = Uint8List(64);
  final rBytes = dw3.BytesUtils.bigIntToBytes(sig.r, length: 32);
  final sBytes = dw3.BytesUtils.bigIntToBytes(sig.s, length: 32);
  signature.setRange(0, 32, rBytes);
  signature.setRange(32, 64, sBytes);
  return crypto.Secp256k1.recover(signature, hash, v);
}

/// Legacy publicKeyToAddress compatibility
Uint8List publicKeyToAddress(Uint8List publicKey) {
  final uncompressed = crypto.Secp256k1.decompressPublicKey(publicKey);
  // Use core's EthereumAddress to generate address from public key
  // This ensures consistent logic with the rest of the ecosystem
  return dw3.EthereumAddress.fromPublicKey(uncompressed, keccak256).bytes;
}

/// Legacy bytesToHex compatibility
String bytesToHex(
  List<int> bytes, {
  bool include0x = false,
  int? forcePadLength,
  bool padToEven = false,
}) {
  var encoded = dw3.HexUtils.encode(Uint8List.fromList(bytes));
  if (encoded.startsWith('0x')) encoded = encoded.substring(2);
  if (padToEven && encoded.length % 2 != 0) encoded = '0$encoded';
  if (forcePadLength != null) encoded = encoded.padLeft(forcePadLength, '0');
  return include0x ? '0x$encoded' : encoded;
}

/// Legacy hexToBytes compatibility
Uint8List hexToBytes(String hexString) => dw3.HexUtils.decode(hexString);

/// Legacy intToBytes compatibility
Uint8List intToBytes(BigInt number) => dw3.BytesUtils.bigIntToBytes(number);

/// Compatibility alias for web3dart's MsgSignature
class MsgSignature {
  final BigInt r;
  final BigInt s;
  final int v;
  MsgSignature(this.r, this.s, this.v);
}

/// Legacy compatibility wrapper for PrivateKey (EthPrivateKey).
class Web3PrivateKey {
  final dw3_signer.PrivateKeySigner _signer;
  final Uint8List privateKey;

  Web3PrivateKey(this.privateKey)
      : _signer = dw3_signer.PrivateKeySigner(privateKey, 1);

  factory Web3PrivateKey.fromHex(String hex) {
    return Web3PrivateKey(dw3.HexUtils.decode(hex));
  }

  dw3.EthereumAddress get address => _signer.address;
  Future<dw3.EthereumAddress> extractAddress() async => address;
  dw3_signer.Signer get signer => _signer;
  Uint8List get publicKey =>
      crypto.Secp256k1.getPublicKey(privateKey, compressed: false);
  Uint8List get encodedPublicKey => publicKey;

  Future<Uint8List> signTransaction(Transaction transaction, {int? chainId}) {
    final dw3Tx = dw3_signer.TransactionRequest(
      to: transaction.to?.hex,
      value: transaction.value?.getInWei,
      gasLimit: transaction.maxGas,
      gasPrice: transaction.gasPrice?.getInWei,
      data: transaction.data,
      nonce: transaction.nonce != null ? BigInt.from(transaction.nonce!) : null,
      maxFeePerGas: transaction.maxFeePerGas?.getInWei,
      maxPriorityFeePerGas: transaction.maxPriorityFeePerGas?.getInWei,
      chainId: chainId,
    );
    return _signer.signTransaction(dw3Tx);
  }

  Future<Uint8List> signPersonalMessage(Uint8List message) async {
    final prefix = '\x19Ethereum Signed Message:\n${message.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);
    final prefixedMessage = Uint8List.fromList(prefixBytes + message);
    final hash = crypto.Keccak256.hash(prefixedMessage);
    return crypto.Secp256k1.sign(hash, privateKey);
  }

  MsgSignature signToEcSignature(Uint8List hash) {
    final sig = crypto.Secp256k1.sign(hash, privateKey);
    final r = BigInt.parse(dw3.HexUtils.encode(sig.sublist(0, 32)), radix: 16);
    final s = BigInt.parse(dw3.HexUtils.encode(sig.sublist(32, 64)), radix: 16);
    final v = sig[64];
    return MsgSignature(r, s, v);
  }
}

typedef EthPrivateKey = Web3PrivateKey;
typedef Credentials = Web3PrivateKey;

/// Compatibility alias for web3dart's EtherAmount
class EtherAmount {
  final BigInt inWei;
  EtherAmount._({required this.inWei});
  factory EtherAmount.inWei(BigInt wei) => EtherAmount._(inWei: wei);
  factory EtherAmount.fromBigInt(EtherUnit unit, BigInt value) =>
      EtherAmount._(inWei: value * unit.weiValue);
  factory EtherAmount.fromUnitAndValue(EtherUnit unit, BigInt value) =>
      EtherAmount._(inWei: value * unit.weiValue);

  Decimal getValueInUnit(EtherUnit unit) {
    final weiDecimal = Decimal.parse(inWei.toString());
    final unitDecimal = Decimal.parse(unit.weiValue.toString());
    return (weiDecimal / unitDecimal).toDecimal();
  }

  BigInt getValueInUnitBI(EtherUnit unit) => inWei ~/ unit.weiValue;
  BigInt get getInWei => inWei;
  static EtherAmount zero() => EtherAmount._(inWei: BigInt.zero);
}

/// Compatibility alias for web3dart's EtherUnit
enum EtherUnit {
  wei,
  kwei,
  mwei,
  gwei,
  szabo,
  finney,
  ether;

  BigInt get weiValue {
    switch (this) {
      case EtherUnit.wei:
        return BigInt.one;
      case EtherUnit.kwei:
        return BigInt.from(1000);
      case EtherUnit.mwei:
        return BigInt.from(1000000);
      case EtherUnit.gwei:
        return BigInt.from(1000000000);
      case EtherUnit.szabo:
        return BigInt.parse('1000000000000');
      case EtherUnit.finney:
        return BigInt.parse('1000000000000000');
      case EtherUnit.ether:
        return BigInt.parse('1000000000000000000');
    }
  }
}

/// Compatibility wrapper for web3dart's Web3Client
class Web3Client {
  final PublicClient _client;
  final String rpcUrl;

  Web3Client(
    this.rpcUrl,
    dynamic httpClient, {
    dw3_chains.ChainConfig? chain,
  }) : _client = PublicClient(
          provider: RpcProvider(HttpTransport(rpcUrl)),
          chain: chain ?? dw3_chains.Chains.ethereum,
        );

  Future<EtherAmount> getBalance(EthereumAddress address) async {
    final wei = await _client.getBalance(address.hex);
    return EtherAmount.inWei(wei);
  }

  Future<int> getBlockNumber() async {
    final blockNum = await _client.getBlockNumber();
    return blockNum.toInt();
  }

  Future<EtherAmount> getGasPrice() async {
    final gasPrice = await _client.getGasPrice();
    return EtherAmount.inWei(gasPrice);
  }

  Future<int> getTransactionCount(
    EthereumAddress address, {
    BlockNum? atBlock,
  }) async {
    final count = await _client.getTransactionCount(
      address.hex,
      atBlock?.toBlockParam() ?? 'latest',
    );
    return count.toInt();
  }

  Future<int> getChainId() async => _client.getChainId();

  Future<List<dynamic>> call({
    EthereumAddress? sender,
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> params,
    BlockNum? atBlock,
  }) async {
    final data = function.encodeCall(params);
    final result = await _client.call(
      CallRequest(to: contract.address.hex, data: data, from: sender?.hex),
      atBlock?.toBlockParam() ?? 'latest',
    );
    return function.decodeReturnValues(result);
  }

  Future<BigInt> estimateGas({
    EthereumAddress? sender,
    EthereumAddress? to,
    EtherAmount? value,
    EtherAmount? gasPrice,
    EtherAmount? maxPriorityFeePerGas,
    EtherAmount? maxFeePerGas,
    Uint8List? data,
  }) async {
    return _client.estimateGas(
      CallRequest(
        from: sender?.hex,
        to: to?.hex,
        value: value?.inWei,
        gasPrice: gasPrice?.inWei,
        maxPriorityFeePerGas: maxPriorityFeePerGas?.inWei,
        maxFeePerGas: maxFeePerGas?.inWei,
        data: data,
      ),
    );
  }

  void dispose() => _client.dispose();

  Future<String> sendTransaction(
    Credentials credentials,
    Transaction transaction, {
    int? chainId,
    bool fetchChainIdFromNetworkId = false,
  }) async {
    final signed = await signTransaction(
      credentials,
      transaction,
      chainId: chainId,
    );
    return sendRawTransaction(signed);
  }

  Future<Uint8List> signTransaction(
    Credentials credentials,
    Transaction transaction, {
    int? chainId,
    bool fetchChainIdFromNetworkId = false,
  }) async {
    return credentials.signTransaction(transaction, chainId: chainId);
  }

  Future<String> sendRawTransaction(Uint8List signedTransaction) async {
    final hexTx = dw3.HexUtils.encode(signedTransaction);
    return await _client.provider.sendRawTransaction(hexTx);
  }

  Future<TransactionReceipt?> getTransactionReceipt(String hash) async {
    try {
      return await _client.getTransactionReceipt(hash);
    } catch (_) {
      return null;
    }
  }

  Future<List<FilterEvent>> getLogs(FilterOptions options) async {
    final logs = await _client.getLogs(options);
    return logs.map((l) => Web3Log(l)).toList();
  }

  Future<Block> getBlockInformation({
    String blockNumber = 'latest',
    bool isFull = false,
  }) async {
    final block = await _client.getBlockByNumber(blockNumber);
    if (block == null) throw Exception('Block not found: $blockNumber');
    return block;
  }
}

typedef FilterOptions = LogFilter;

class Web3Log {
  final Log _log;
  Web3Log(this._log);
  EthereumAddress get address => EthereumAddress.fromHex(_log.address);
  List<String>? get topics => _log.topics;
  String? get data => dw3.HexUtils.encode(_log.data);
  String? get transactionHash => _log.transactionHash;
  BigInt? get blockNum => _log.blockNumber;
  int? get transactionIndex => _log.transactionIndex;
  int? get logIndex => _log.logIndex;
}

typedef FilterEvent = Web3Log;

class ContractAbi {
  final String name;
  final List<ContractFunction> functions;
  final List<ContractEvent> events;

  ContractAbi(this.name, this.functions, this.events);

  factory ContractAbi.fromJson(String json, String name) {
    return ContractAbi(
      name,
      AbiParser.parseFunctions(
        json,
      ).map((f) => ContractFunction.fromAbi(f)).toList(),
      AbiParser.parseEvents(json).map((e) => ContractEvent(e)).toList(),
    );
  }
}

class DeployedContract {
  final ContractAbi abi;
  final EthereumAddress address;
  DeployedContract(this.abi, this.address);
  List<ContractFunction> get functions => abi.functions;
  List<ContractEvent> get events => abi.events;

  ContractFunction function(String name) => abi.functions.firstWhere(
        (f) => f.name == name,
        orElse: () => throw ArgumentError('Function $name not found'),
      );

  ContractEvent event(String name) => abi.events.firstWhere(
        (e) => e.name == name,
        orElse: () => throw ArgumentError('Event $name not found'),
      );
}

class ContractFunction {
  final String name;
  final List<AbiType> parameters;
  final List<AbiType> outputs;
  final String stateMutability;

  const ContractFunction(
    this.name,
    this.parameters, {
    this.outputs = const [],
    this.stateMutability = 'nonpayable',
  });

  ContractFunction.fromAbi(AbiFunction abi)
      : name = abi.name,
        parameters = abi.inputs,
        outputs = abi.outputs,
        stateMutability = abi.stateMutability;

  String get signature {
    final inputTypes = parameters.map((i) => i.name).join(',');
    return '$name($inputTypes)';
  }

  Uint8List encodeCall(List<dynamic> params) =>
      AbiEncoder.encodeFunction(signature, params);

  List<dynamic> decodeReturnValues(Uint8List data) =>
      AbiDecoder.decodeFunction(outputs, data);
}

class ContractEvent {
  final AbiEvent _abiEvent;
  ContractEvent(this._abiEvent);
  String get name => _abiEvent.name;
  String get signature => _abiEvent.signature;

  List<dynamic> decodeResults(List<String?> topics, String data) {
    final nonNullTopics = topics.whereType<String>().toList();
    final dataBytes = dw3.HexUtils.decode(data);

    final decodedMap = AbiDecoder.decodeEvent(
      types: _abiEvent.inputs,
      indexed: _abiEvent.indexed,
      names: _abiEvent.inputNames,
      topics: nonNullTopics,
      data: dataBytes,
    );

    return _abiEvent.inputNames.map((name) => decodedMap[name]).toList();
  }
}

class BlockNum {
  final String? _str;
  final int? _blockNum;

  const BlockNum.pending()
      : _str = 'pending',
        _blockNum = null;
  const BlockNum.exact(this._blockNum) : _str = null;
  const BlockNum.current()
      : _str = 'latest',
        _blockNum = null;
  const BlockNum.earliest()
      : _str = 'earliest',
        _blockNum = null;

  String toBlockParam() {
    if (_blockNum != null) return '0x${_blockNum!.toRadixString(16)}';
    return _str ?? 'latest';
  }
}

class Transaction {
  final EthereumAddress? from;
  final EthereumAddress? to;
  final BigInt? maxGas;
  final EtherAmount? gasPrice;
  final EtherAmount? value;
  final Uint8List? data;
  final int? nonce;
  final EtherAmount? maxFeePerGas;
  final EtherAmount? maxPriorityFeePerGas;

  const Transaction({
    this.from,
    this.to,
    this.maxGas,
    this.gasPrice,
    this.value,
    this.data,
    this.nonce,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  factory Transaction.callContract({
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> parameters,
    EthereumAddress? from,
    BigInt? maxGas,
    EtherAmount? gasPrice,
    EtherAmount? value,
    int? nonce,
    EtherAmount? maxFeePerGas,
    EtherAmount? maxPriorityFeePerGas,
  }) {
    return Transaction(
      from: from,
      to: contract.address,
      data: function.encodeCall(parameters),
      maxGas: maxGas,
      gasPrice: gasPrice,
      value: value,
      nonce: nonce,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }
}

class Wallet {
  final Web3PrivateKey _credentials;
  Wallet._(this._credentials);
  Credentials get privateKey => _credentials;

  /// Creates a dummy wallet for compatibility (V3 Keystore TODO)
  static Future<Wallet> createNew(
    Credentials credentials,
    String password,
    Random random,
  ) async {
    return Wallet._(credentials as Web3PrivateKey);
  }

  static Future<Wallet> fromJson(String json, String password) async {
    throw UnimplementedError(
      'Wallet.fromJson is not implemented yet in dart_web3_compat. See Keystore V3 spec.',
    );
  }
}
