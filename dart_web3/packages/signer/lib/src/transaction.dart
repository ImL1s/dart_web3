import 'dart:typed_data';

import 'authorization.dart';

/// Transaction types supported by Ethereum.
enum TransactionType {
  /// Legacy transaction (pre-EIP-2718).
  legacy(0),

  /// EIP-2930 access list transaction.
  eip2930(1),

  /// EIP-1559 fee market transaction.
  eip1559(2),

  /// EIP-4844 blob transaction.
  eip4844(3),

  /// EIP-7702 EOA code delegation transaction.
  eip7702(4);

  final int value;
  const TransactionType(this.value);
}

/// Represents a transaction request.
class TransactionRequest {
  TransactionRequest({
    this.to,
    this.value,
    this.data,
    this.gasLimit,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.nonce,
    this.chainId,
    this.type = TransactionType.eip1559,
    this.accessList,
    this.blobVersionedHashes,
    this.maxFeePerBlobGas,
    this.authorizationList,
  });

  /// The recipient address (null for contract creation).
  final String? to;

  /// The value to send in wei.
  final BigInt? value;

  /// The transaction data.
  final Uint8List? data;

  /// The gas limit.
  final BigInt? gasLimit;

  /// The gas price (for legacy transactions).
  final BigInt? gasPrice;

  /// The max fee per gas (for EIP-1559+).
  final BigInt? maxFeePerGas;

  /// The max priority fee per gas (for EIP-1559+).
  final BigInt? maxPriorityFeePerGas;

  /// The nonce.
  final BigInt? nonce;

  /// The chain ID.
  final int? chainId;

  /// The transaction type.
  final TransactionType type;

  /// Access list (for EIP-2930+).
  final List<AccessListEntry>? accessList;

  /// Blob versioned hashes (for EIP-4844).
  final List<String>? blobVersionedHashes;

  /// Max fee per blob gas (for EIP-4844).
  final BigInt? maxFeePerBlobGas;

  /// Authorization list (for EIP-7702).
  final List<Authorization>? authorizationList;

  /// Creates a copy with updated fields.
  TransactionRequest copyWith({
    String? to,
    BigInt? value,
    Uint8List? data,
    BigInt? gasLimit,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
    BigInt? nonce,
    int? chainId,
    TransactionType? type,
    List<AccessListEntry>? accessList,
    List<String>? blobVersionedHashes,
    BigInt? maxFeePerBlobGas,
    List<Authorization>? authorizationList,
  }) {
    return TransactionRequest(
      to: to ?? this.to,
      value: value ?? this.value,
      data: data ?? this.data,
      gasLimit: gasLimit ?? this.gasLimit,
      gasPrice: gasPrice ?? this.gasPrice,
      maxFeePerGas: maxFeePerGas ?? this.maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas ?? this.maxPriorityFeePerGas,
      nonce: nonce ?? this.nonce,
      chainId: chainId ?? this.chainId,
      type: type ?? this.type,
      accessList: accessList ?? this.accessList,
      blobVersionedHashes: blobVersionedHashes ?? this.blobVersionedHashes,
      maxFeePerBlobGas: maxFeePerBlobGas ?? this.maxFeePerBlobGas,
      authorizationList: authorizationList ?? this.authorizationList,
    );
  }
}

/// An entry in an access list.
class AccessListEntry {
  AccessListEntry({required this.address, required this.storageKeys});

  /// The address.
  final String address;

  /// The storage keys.
  final List<String> storageKeys;
}
