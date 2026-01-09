import 'dart:typed_data';
import 'address.dart';

/// Represents an Aptos transaction payload.
abstract class TransactionPayload {
  Map<String, dynamic> toJson();
}

/// Entry function payload for calling Move modules.
class EntryFunctionPayload implements TransactionPayload {
  EntryFunctionPayload({
    required this.function,
    required this.typeArguments,
    required this.arguments,
  });

  /// Full function identifier: address::module::function
  final String function;

  /// Type arguments for generic functions
  final List<String> typeArguments;

  /// Function arguments
  final List<dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'entry_function_payload',
    'function': function,
    'type_arguments': typeArguments,
    'arguments': arguments,
  };
}

/// Script payload for executing Move scripts.
class ScriptPayload implements TransactionPayload {
  ScriptPayload({
    required this.code,
    required this.typeArguments,
    required this.arguments,
  });

  final Uint8List code;
  final List<String> typeArguments;
  final List<dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'script_payload',
    'code': {'bytecode': '0x${_hexEncode(code)}'},
    'type_arguments': typeArguments,
    'arguments': arguments,
  };

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Represents a raw Aptos transaction.
class RawTransaction {
  RawTransaction({
    required this.sender,
    required this.sequenceNumber,
    required this.payload,
    required this.maxGasAmount,
    required this.gasUnitPrice,
    required this.expirationTimestampSecs,
    required this.chainId,
  });

  final AptosAddress sender;
  final BigInt sequenceNumber;
  final TransactionPayload payload;
  final BigInt maxGasAmount;
  final BigInt gasUnitPrice;
  final BigInt expirationTimestampSecs;
  final int chainId;

  Map<String, dynamic> toJson() => {
    'sender': sender.toHex(),
    'sequence_number': sequenceNumber.toString(),
    'payload': payload.toJson(),
    'max_gas_amount': maxGasAmount.toString(),
    'gas_unit_price': gasUnitPrice.toString(),
    'expiration_timestamp_secs': expirationTimestampSecs.toString(),
    'chain_id': chainId,
  };
}

/// Represents a signed Aptos transaction.
class SignedTransaction {
  SignedTransaction({
    required this.rawTransaction,
    required this.signature,
    required this.publicKey,
  });

  final RawTransaction rawTransaction;
  final Uint8List signature;
  final Uint8List publicKey;

  Map<String, dynamic> toJson() => {
    ...rawTransaction.toJson(),
    'signature': {
      'type': 'ed25519_signature',
      'public_key': '0x${_hexEncode(publicKey)}',
      'signature': '0x${_hexEncode(signature)}',
    },
  };

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
