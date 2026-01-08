import 'dart:typed_data';
import 'aptos_types.dart';

/// Aptos transaction payload types.
sealed class AptosTransactionPayload {
  const AptosTransactionPayload();
}

/// Entry function payload.
class EntryFunctionPayload extends AptosTransactionPayload {
  /// Creates an EntryFunctionPayload.
  const EntryFunctionPayload({
    required this.function,
    required this.typeArguments,
    required this.arguments,
  });

  /// Fully qualified function name (address::module::function).
  final String function;

  /// Type arguments.
  final List<String> typeArguments;

  /// Function arguments (encoded).
  final List<dynamic> arguments;

  /// Converts to JSON for submission.
  Map<String, dynamic> toJson() => {
    'type': 'entry_function_payload',
    'function': function,
    'type_arguments': typeArguments,
    'arguments': arguments,
  };
}

/// Script payload.
class ScriptPayload extends AptosTransactionPayload {
  /// Creates a ScriptPayload.
  const ScriptPayload({
    required this.code,
    required this.typeArguments,
    required this.arguments,
  });

  /// Compiled Move script bytecode.
  final Uint8List code;

  /// Type arguments.
  final List<String> typeArguments;

  /// Script arguments.
  final List<dynamic> arguments;

  /// Converts to JSON for submission.
  Map<String, dynamic> toJson() => {
    'type': 'script_payload',
    'code': {'bytecode': '0x${_bytesToHex(code)}'},
    'type_arguments': typeArguments,
    'arguments': arguments,
  };
}

/// Multisig payload.
class MultisigPayload extends AptosTransactionPayload {
  /// Creates a MultisigPayload.
  const MultisigPayload({
    required this.multisigAddress,
    this.transactionPayload,
  });

  /// Multisig account address.
  final AptosAddress multisigAddress;

  /// Inner transaction payload.
  final EntryFunctionPayload? transactionPayload;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'type': 'multisig_payload',
    'multisig_address': multisigAddress.toHex(),
    if (transactionPayload != null)
      'transaction_payload': transactionPayload!.toJson(),
  };
}

/// Raw transaction (unsigned).
class AptosRawTransaction {
  /// Creates an AptosRawTransaction.
  const AptosRawTransaction({
    required this.sender,
    required this.sequenceNumber,
    required this.payload,
    required this.maxGasAmount,
    required this.gasUnitPrice,
    required this.expirationTimestampSecs,
    required this.chainId,
  });

  /// Sender address.
  final AptosAddress sender;

  /// Sequence number (nonce).
  final BigInt sequenceNumber;

  /// Transaction payload.
  final AptosTransactionPayload payload;

  /// Maximum gas amount.
  final BigInt maxGasAmount;

  /// Gas unit price in octas.
  final BigInt gasUnitPrice;

  /// Expiration timestamp in seconds.
  final BigInt expirationTimestampSecs;

  /// Chain ID.
  final int chainId;

  /// Serializes to BCS bytes.
  Uint8List serialize() {
    // BCS serialization would go here
    return Uint8List(0);
  }
}

/// Signed transaction.
class AptosSignedTransaction {
  /// Creates an AptosSignedTransaction.
  const AptosSignedTransaction({
    required this.rawTransaction,
    required this.authenticator,
  });

  /// The raw transaction.
  final AptosRawTransaction rawTransaction;

  /// Transaction authenticator.
  final AptosTransactionAuthenticator authenticator;

  /// Serializes to BCS bytes.
  Uint8List serialize() {
    // BCS serialization would go here
    return Uint8List(0);
  }
}

/// Transaction authenticator.
sealed class AptosTransactionAuthenticator {
  const AptosTransactionAuthenticator();
}

/// Ed25519 authenticator.
class Ed25519Authenticator extends AptosTransactionAuthenticator {
  /// Creates an Ed25519Authenticator.
  const Ed25519Authenticator({
    required this.publicKey,
    required this.signature,
  });

  /// Ed25519 public key (32 bytes).
  final Uint8List publicKey;

  /// Ed25519 signature (64 bytes).
  final Uint8List signature;
}

/// Multi-Ed25519 authenticator.
class MultiEd25519Authenticator extends AptosTransactionAuthenticator {
  /// Creates a MultiEd25519Authenticator.
  const MultiEd25519Authenticator({
    required this.publicKeys,
    required this.signatures,
    required this.bitmap,
    required this.threshold,
  });

  /// List of public keys.
  final List<Uint8List> publicKeys;

  /// List of signatures.
  final List<Uint8List> signatures;

  /// Bitmap indicating which keys signed.
  final Uint8List bitmap;

  /// Required threshold.
  final int threshold;
}

/// Single key authenticator.
class SingleKeyAuthenticator extends AptosTransactionAuthenticator {
  /// Creates a SingleKeyAuthenticator.
  const SingleKeyAuthenticator({
    required this.publicKey,
    required this.signature,
  });

  /// Public key with type prefix.
  final AptosAnyPublicKey publicKey;

  /// Signature with type prefix.
  final AptosAnySignature signature;
}

/// Any public key (with type prefix).
class AptosAnyPublicKey {
  /// Creates an AptosAnyPublicKey.
  const AptosAnyPublicKey({required this.type, required this.publicKey});

  /// Key type.
  final AptosPublicKeyType type;

  /// Public key bytes.
  final Uint8List publicKey;
}

/// Public key types.
enum AptosPublicKeyType {
  /// Ed25519 public key.
  ed25519(0),

  /// Secp256k1 ECDSA public key.
  secp256k1Ecdsa(1),

  /// Secp256r1 ECDSA public key.
  secp256r1Ecdsa(2),

  /// Keyless public key.
  keyless(3);

  const AptosPublicKeyType(this.value);
  final int value;
}

/// Any signature (with type prefix).
class AptosAnySignature {
  /// Creates an AptosAnySignature.
  const AptosAnySignature({required this.type, required this.signature});

  /// Signature type.
  final AptosSignatureType type;

  /// Signature bytes.
  final Uint8List signature;
}

/// Signature types.
enum AptosSignatureType {
  /// Ed25519 signature.
  ed25519(0),

  /// Secp256k1 ECDSA signature.
  secp256k1Ecdsa(1),

  /// Secp256r1 ECDSA signature.
  secp256r1Ecdsa(2),

  /// Keyless signature.
  keyless(3);

  const AptosSignatureType(this.value);
  final int value;
}

/// Transaction response from the API.
class AptosTransactionResponse {
  /// Creates an AptosTransactionResponse.
  const AptosTransactionResponse({
    required this.version,
    required this.hash,
    required this.stateChangeHash,
    required this.eventRootHash,
    required this.stateCheckpointHash,
    required this.gasUsed,
    required this.success,
    required this.vmStatus,
    required this.accumulatorRootHash,
    this.changes,
    this.events,
    this.timestamp,
  });

  /// Creates from JSON.
  factory AptosTransactionResponse.fromJson(Map<String, dynamic> json) {
    return AptosTransactionResponse(
      version: BigInt.parse(json['version'] as String),
      hash: json['hash'] as String,
      stateChangeHash: json['state_change_hash'] as String,
      eventRootHash: json['event_root_hash'] as String,
      stateCheckpointHash: json['state_checkpoint_hash'] as String?,
      gasUsed: BigInt.parse(json['gas_used'] as String),
      success: json['success'] as bool,
      vmStatus: json['vm_status'] as String,
      accumulatorRootHash: json['accumulator_root_hash'] as String,
      changes: json['changes'] as List?,
      events: json['events'] as List?,
      timestamp: json['timestamp'] != null
          ? BigInt.parse(json['timestamp'] as String)
          : null,
    );
  }

  final BigInt version;
  final String hash;
  final String stateChangeHash;
  final String eventRootHash;
  final String? stateCheckpointHash;
  final BigInt gasUsed;
  final bool success;
  final String vmStatus;
  final String accumulatorRootHash;
  final List? changes;
  final List? events;
  final BigInt? timestamp;
}

/// Pending transaction response.
class AptosPendingTransactionResponse {
  /// Creates an AptosPendingTransactionResponse.
  const AptosPendingTransactionResponse({
    required this.hash,
    required this.sender,
    required this.sequenceNumber,
    required this.maxGasAmount,
    required this.gasUnitPrice,
    required this.expirationTimestampSecs,
    required this.payload,
  });

  /// Creates from JSON.
  factory AptosPendingTransactionResponse.fromJson(Map<String, dynamic> json) {
    return AptosPendingTransactionResponse(
      hash: json['hash'] as String,
      sender: json['sender'] as String,
      sequenceNumber: BigInt.parse(json['sequence_number'] as String),
      maxGasAmount: BigInt.parse(json['max_gas_amount'] as String),
      gasUnitPrice: BigInt.parse(json['gas_unit_price'] as String),
      expirationTimestampSecs: BigInt.parse(
        json['expiration_timestamp_secs'] as String,
      ),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  final String hash;
  final String sender;
  final BigInt sequenceNumber;
  final BigInt maxGasAmount;
  final BigInt gasUnitPrice;
  final BigInt expirationTimestampSecs;
  final Map<String, dynamic> payload;
}

/// Transaction builder for constructing transactions.
class AptosTransactionBuilder {
  /// Creates a new AptosTransactionBuilder.
  AptosTransactionBuilder({required this.sender, required this.chainId});

  /// Sender address.
  final AptosAddress sender;

  /// Chain ID.
  final int chainId;

  BigInt? _sequenceNumber;
  BigInt _maxGasAmount = BigInt.from(200000);
  BigInt _gasUnitPrice = BigInt.from(100);
  BigInt? _expirationTimestampSecs;
  AptosTransactionPayload? _payload;

  /// Sets the sequence number.
  AptosTransactionBuilder sequenceNumber(BigInt sequenceNumber) {
    _sequenceNumber = sequenceNumber;
    return this;
  }

  /// Sets the max gas amount.
  AptosTransactionBuilder maxGasAmount(BigInt maxGasAmount) {
    _maxGasAmount = maxGasAmount;
    return this;
  }

  /// Sets the gas unit price.
  AptosTransactionBuilder gasUnitPrice(BigInt gasUnitPrice) {
    _gasUnitPrice = gasUnitPrice;
    return this;
  }

  /// Sets the expiration timestamp.
  AptosTransactionBuilder expirationTimestampSecs(BigInt timestamp) {
    _expirationTimestampSecs = timestamp;
    return this;
  }

  /// Sets expiration relative to current time.
  AptosTransactionBuilder expiresIn(Duration duration) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _expirationTimestampSecs = BigInt.from(now + duration.inSeconds);
    return this;
  }

  /// Sets the payload.
  AptosTransactionBuilder payload(AptosTransactionPayload payload) {
    _payload = payload;
    return this;
  }

  /// Sets an entry function payload.
  AptosTransactionBuilder entryFunction({
    required String function,
    List<String> typeArguments = const [],
    List<dynamic> arguments = const [],
  }) {
    _payload = EntryFunctionPayload(
      function: function,
      typeArguments: typeArguments,
      arguments: arguments,
    );
    return this;
  }

  /// Builds the raw transaction.
  AptosRawTransaction build() {
    if (_sequenceNumber == null) {
      throw StateError('Sequence number not set');
    }
    if (_payload == null) {
      throw StateError('Payload not set');
    }
    if (_expirationTimestampSecs == null) {
      // Default to 30 seconds from now
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _expirationTimestampSecs = BigInt.from(now + 30);
    }

    return AptosRawTransaction(
      sender: sender,
      sequenceNumber: _sequenceNumber!,
      payload: _payload!,
      maxGasAmount: _maxGasAmount,
      gasUnitPrice: _gasUnitPrice,
      expirationTimestampSecs: _expirationTimestampSecs!,
      chainId: chainId,
    );
  }
}

/// Helper to convert bytes to hex.
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Common transaction payloads.
class AptosPayloads {
  AptosPayloads._();

  /// Creates an APT transfer payload.
  static EntryFunctionPayload transferApt({
    required AptosAddress to,
    required BigInt amount,
  }) {
    return EntryFunctionPayload(
      function: '0x1::aptos_account::transfer',
      typeArguments: [],
      arguments: [to.toHex(), amount.toString()],
    );
  }

  /// Creates a coin transfer payload.
  static EntryFunctionPayload transferCoin({
    required String coinType,
    required AptosAddress to,
    required BigInt amount,
  }) {
    return EntryFunctionPayload(
      function: '0x1::aptos_account::transfer_coins',
      typeArguments: [coinType],
      arguments: [to.toHex(), amount.toString()],
    );
  }

  /// Creates a coin register payload.
  static EntryFunctionPayload registerCoin({required String coinType}) {
    return EntryFunctionPayload(
      function: '0x1::managed_coin::register',
      typeArguments: [coinType],
      arguments: [],
    );
  }
}
