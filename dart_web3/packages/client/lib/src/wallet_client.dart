import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'models.dart';
import 'public_client.dart';

/// Wallet client for signing and sending transactions.
class WalletClient extends PublicClient {

  WalletClient({
    required super.provider,
    required super.chain,
    required this.signer,
  });
  /// The signer.
  Signer signer;

  /// The wallet address.
  EthereumAddress get address => signer.address;

  /// Sends a transaction.
  Future<String> sendTransaction(TransactionRequest request) async {
    // Fill in missing fields
    final prepared = await prepareTransaction(request);

    // Sign the transaction
    final signedTx = await signer.signTransaction(prepared);

    // Send the signed transaction
    return sendRawTransaction(HexUtils.encode(signedTx));
  }

  /// Sends a raw signed transaction.
  Future<String> sendRawTransaction(String signedTx) async {
    return provider.sendRawTransaction(signedTx);
  }

  /// Signs a message.
  Future<Uint8List> signMessage(String message) async {
    return signer.signMessage(message);
  }

  /// Signs typed data (EIP-712).
  Future<Uint8List> signTypedData(TypedData typedData) async {
    return signer.signTypedData(typedData);
  }

  /// Signs a transaction without sending.
  Future<Uint8List> signTransaction(TransactionRequest transaction) async {
    final prepared = await prepareTransaction(transaction);
    return signer.signTransaction(prepared);
  }

  /// Signs an EIP-7702 authorization.
  Future<Uint8List> signAuthorization(Authorization authorization) async {
    return signer.signAuthorization(authorization);
  }

  /// Creates and signs an EIP-7702 authorization for contract delegation.
  Future<Authorization> createAuthorization({
    required String contractAddress,
    required BigInt nonce,
  }) async {
    final authorization = Authorization.unsigned(
      chainId: chain.chainId,
      address: contractAddress,
      nonce: nonce,
    );

    final signature = await signAuthorization(authorization);
    
    // Extract signature components
    final r = signature.sublist(0, 32);
    final s = signature.sublist(32, 64);
    final yParity = signature[64];
    
    return authorization.withSignature(
      yParity: yParity,
      r: _bytesToBigInt(r),
      s: _bytesToBigInt(s),
    );
  }

  /// Creates and signs multiple EIP-7702 authorizations for batch delegation.
  Future<List<Authorization>> createAuthorizationBatch({
    required List<String> contractAddresses,
    required BigInt startingNonce,
  }) async {
    final authorizations = <Authorization>[];
    
    for (var i = 0; i < contractAddresses.length; i++) {
      final authorization = await createAuthorization(
        contractAddress: contractAddresses[i],
        nonce: startingNonce + BigInt.from(i),
      );
      authorizations.add(authorization);
    }
    
    return authorizations;
  }

  /// Creates and signs a revocation authorization.
  Future<Authorization> createRevocation({
    required BigInt nonce,
  }) async {
    final revocation = Authorization.revocation(
      chainId: chain.chainId,
      nonce: nonce,
    );

    final signature = await signAuthorization(revocation);
    
    // Extract signature components
    final r = signature.sublist(0, 32);
    final s = signature.sublist(32, 64);
    final yParity = signature[64];
    
    return revocation.withSignature(
      yParity: yParity,
      r: _bytesToBigInt(r),
      s: _bytesToBigInt(s),
    );
  }

  /// Sends an EIP-7702 transaction with authorization list.
  Future<String> sendEip7702Transaction({
    required List<Authorization> authorizationList, String? to,
    BigInt? value,
    Uint8List? data,
    BigInt? gasLimit,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
    BigInt? nonce,
  }) async {
    final request = TransactionRequest(
      type: TransactionType.eip7702,
      to: to,
      value: value,
      data: data,
      authorizationList: authorizationList,
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      nonce: nonce,
    );

    return sendTransaction(request);
  }

  /// Calls a method on a delegated contract.
  /// 
  /// This allows calling contract methods as if the EOA has the contract's code.
  Future<String> callDelegatedContract({
    required String contractAddress,
    required String functionSignature,
    required List<dynamic> args,
    BigInt? value,
    BigInt? gasLimit,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    // Encode the function call
    final data = _encodeFunctionCall(functionSignature, args);

    // Create authorization for the contract
    final currentNonce = await getTransactionCount(address.hex, 'pending');
    final authorization = await createAuthorization(
      contractAddress: contractAddress,
      nonce: currentNonce,
    );

    // Send EIP-7702 transaction
    return sendEip7702Transaction(
      to: address.hex, // Call to self with delegated code
      value: value,
      data: data,
      authorizationList: [authorization],
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Revokes a previous delegation.
  Future<String> revokeDelegation({
    required BigInt nonce,
    BigInt? gasLimit,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final revocation = await createRevocation(nonce: nonce);

    return sendEip7702Transaction(
      authorizationList: [revocation],
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Revokes multiple delegations in a single transaction.
  Future<String> revokeMultipleDelegations({
    required List<BigInt> nonces,
    BigInt? gasLimit,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final revocations = <Authorization>[];
    
    for (final nonce in nonces) {
      final revocation = await createRevocation(nonce: nonce);
      revocations.add(revocation);
    }

    return sendEip7702Transaction(
      authorizationList: revocations,
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Estimates gas for an EIP-7702 transaction.
  Future<BigInt> estimateEip7702Gas({
    required List<Authorization> authorizationList, String? to,
    BigInt? value,
    Uint8List? data,
  }) async {
    final request = CallRequest(
      from: address.hex,
      to: to,
      data: data,
      value: value,
    );

    final baseGas = await estimateGas(request);
    
    // Add gas cost for each authorization (approximately 2,300 gas each)
    final authGas = BigInt.from(authorizationList.length * 2300);
    
    return baseGas + authGas;
  }

  /// Transfers native currency.
  Future<String> transfer(String to, BigInt amount) async {
    return sendTransaction(TransactionRequest(
      to: to,
      value: amount,
    ),);
  }

  /// Prepares a transaction by filling in missing fields.
  Future<TransactionRequest> prepareTransaction(TransactionRequest request) async {
    var tx = request;

    // Set chain ID
    if (tx.chainId == null) {
      tx = tx.copyWith(chainId: chain.chainId);
    }

    // Set nonce
    if (tx.nonce == null) {
      final nonce = await getTransactionCount(address.hex, 'pending');
      tx = tx.copyWith(nonce: nonce);
    }

    // Set gas limit
    if (tx.gasLimit == null) {
      final gasLimit = await estimateGas(_toCallRequest(tx));
      // Add 20% buffer
      tx = tx.copyWith(gasLimit: gasLimit * BigInt.from(120) ~/ BigInt.from(100));
    }

    // Set gas price / fee
    if (tx.type == TransactionType.legacy) {
      if (tx.gasPrice == null) {
        tx = tx.copyWith(gasPrice: await getGasPrice());
      }
    } else {
      if (tx.maxFeePerGas == null || tx.maxPriorityFeePerGas == null) {
        final feeData = await getFeeData();
        tx = tx.copyWith(
          maxFeePerGas: tx.maxFeePerGas ?? feeData.maxFeePerGas,
          maxPriorityFeePerGas: tx.maxPriorityFeePerGas ?? feeData.maxPriorityFeePerGas,
        );
      }
    }

    return tx;
  }

  /// Switches the signer.
  void switchAccount(Signer newSigner) {
    signer = newSigner;
  }

  CallRequest _toCallRequest(TransactionRequest tx) {
    return CallRequest(
      from: address.hex,
      to: tx.to,
      data: tx.data,
      value: tx.value,
      gasLimit: tx.gasLimit,
      gasPrice: tx.gasPrice,
      maxFeePerGas: tx.maxFeePerGas,
      maxPriorityFeePerGas: tx.maxPriorityFeePerGas,
    );
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  Uint8List _encodeFunctionCall(String signature, List<dynamic> args) {
    // Simple function encoding - in a real implementation, this would use ABI encoding
    // For now, we'll create a basic implementation
    final selector = Keccak256.hash(Uint8List.fromList(signature.codeUnits)).sublist(0, 4);
    
    if (args.isEmpty) {
      return selector;
    }
    
    // This is a simplified encoding - real implementation would use proper ABI encoding
    final encoded = BytesUtils.concat([
      selector,
      Uint8List(32 * args.length), // Placeholder for encoded args
    ]);
    
    return encoded;
  }
}
