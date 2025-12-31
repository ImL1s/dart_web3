import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_contract/dart_web3_contract.dart';

import 'swap_types.dart';

/// Token approval manager for swap operations
class TokenApprovalManager {
  final WalletClient walletClient;
  final Map<String, ERC20Contract> _contractCache = {};

  TokenApprovalManager(this.walletClient);

  /// Check if token approval is needed for a swap
  Future<bool> isApprovalNeeded({
    required SwapToken token,
    required String spender,
    required BigInt amount,
    String? owner,
  }) async {
    if (_isNativeToken(token)) {
      return false; // Native tokens don't need approval
    }

    final ownerAddress = owner ?? walletClient.address.address;
    final currentAllowance = await getCurrentAllowance(
      token: token,
      owner: ownerAddress,
      spender: spender,
    );

    return currentAllowance < amount;
  }

  /// Get current allowance for a token
  Future<BigInt> getCurrentAllowance({
    required SwapToken token,
    required String owner,
    required String spender,
  }) async {
    if (_isNativeToken(token)) {
      return BigInt.from(double.maxFinite.toInt()); // Native tokens have unlimited allowance
    }

    try {
      final contract = await _getERC20Contract(token);
      final allowance = await contract.allowance(owner, spender);
      return allowance;
    } catch (e) {
      // If we can't get allowance, assume 0
      return BigInt.zero;
    }
  }

  /// Approve token spending
  Future<String> approveToken({
    required SwapToken token,
    required String spender,
    required BigInt amount,
    bool useMaxApproval = false,
  }) async {
    if (_isNativeToken(token)) {
      throw TokenApprovalException(
        'Native token ${token.symbol} does not require approval',
      );
    }

    try {
      final contract = await _getERC20Contract(token);
      final approvalAmount = useMaxApproval 
          ? _getMaxUint256() 
          : amount;

      final txHash = await contract.approve(spender, approvalAmount);
      return txHash;
    } catch (e) {
      throw TokenApprovalException(
        'Failed to approve ${token.symbol}: $e',
        originalError: e,
      );
    }
  }

  /// Approve token with permit (EIP-2612)
  Future<ApprovalSignature?> approveWithPermit({
    required SwapToken token,
    required String spender,
    required BigInt amount,
    required Duration deadline,
  }) async {
    if (_isNativeToken(token)) {
      return null; // Native tokens don't support permit
    }

    try {
      final contract = await _getERC20Contract(token);
      
      // Check if token supports permit
      final supportsPermit = await _supportsPermit(contract);
      if (!supportsPermit) {
        return null;
      }

      // Get nonce for permit
      final nonce = await _getPermitNonce(contract, walletClient.address.address);
      
      // Create permit signature
      final signature = await _createPermitSignature(
        token: token,
        spender: spender,
        amount: amount,
        nonce: nonce,
        deadline: deadline,
      );

      return signature;
    } catch (e) {
      // If permit fails, return null to fall back to regular approval
      return null;
    }
  }

  /// Get approval transaction data without sending
  Future<ApprovalTransaction> getApprovalTransaction({
    required SwapToken token,
    required String spender,
    required BigInt amount,
    bool useMaxApproval = false,
  }) async {
    if (_isNativeToken(token)) {
      throw TokenApprovalException(
        'Native token ${token.symbol} does not require approval',
      );
    }

    final contract = await _getERC20Contract(token);
    final approvalAmount = useMaxApproval 
        ? _getMaxUint256() 
        : amount;

    // Encode approval function call
    final data = contract.encodeFunction('approve', [spender, approvalAmount]);
    
    // Estimate gas
    final gasEstimate = await walletClient.estimateGas(CallRequest(
      to: token.address,
      data: data,
    ));

    return ApprovalTransaction(
      to: token.address,
      data: data,
      gasEstimate: gasEstimate,
      token: token,
      spender: spender,
      amount: approvalAmount,
    );
  }

  /// Revoke token approval (set allowance to 0)
  Future<String> revokeApproval({
    required SwapToken token,
    required String spender,
  }) async {
    return approveToken(
      token: token,
      spender: spender,
      amount: BigInt.zero,
    );
  }

  /// Check multiple token approvals at once
  Future<Map<SwapToken, bool>> checkMultipleApprovals({
    required List<SwapToken> tokens,
    required String spender,
    required List<BigInt> amounts,
    String? owner,
  }) async {
    if (tokens.length != amounts.length) {
      throw ArgumentError('Tokens and amounts lists must have the same length');
    }

    final results = <SwapToken, bool>{};
    final ownerAddress = owner ?? walletClient.address.address;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final amount = amounts[i];
      
      try {
        final needsApproval = await isApprovalNeeded(
          token: token,
          spender: spender,
          amount: amount,
          owner: ownerAddress,
        );
        results[token] = needsApproval;
      } catch (e) {
        // If check fails, assume approval is needed
        results[token] = true;
      }
    }

    return results;
  }

  Future<ERC20Contract> _getERC20Contract(SwapToken token) async {
    final cacheKey = '${token.chainId}_${token.address}';
    
    if (_contractCache.containsKey(cacheKey)) {
      return _contractCache[cacheKey]!;
    }

    final contract = ERC20Contract(
      address: token.address,
      publicClient: walletClient,
      walletClient: walletClient,
    );

    _contractCache[cacheKey] = contract;
    return contract;
  }

  bool _isNativeToken(SwapToken token) {
    final nativeAddresses = [
      '0x0000000000000000000000000000000000000000',
      '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    ];
    return nativeAddresses.contains(token.address.toLowerCase());
  }

  BigInt _getMaxUint256() {
    return BigInt.parse('115792089237316195423570985008687907853269984665640564039457584007913129639935');
  }

  Future<bool> _supportsPermit(ERC20Contract contract) async {
    try {
      // Try to call DOMAIN_SEPARATOR() to check if permit is supported
      await contract.read('DOMAIN_SEPARATOR', []);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<BigInt> _getPermitNonce(ERC20Contract contract, String owner) async {
    try {
      final result = await contract.read('nonces', [owner]);
      return result[0] as BigInt;
    } catch (e) {
      return BigInt.zero;
    }
  }

  Future<ApprovalSignature> _createPermitSignature({
    required SwapToken token,
    required String spender,
    required BigInt amount,
    required BigInt nonce,
    required Duration deadline,
  }) async {
    // This is a simplified implementation
    // In a real implementation, you would create the EIP-712 typed data
    // and sign it using the wallet client
    
    final deadlineTimestamp = DateTime.now().add(deadline).millisecondsSinceEpoch ~/ 1000;
    
    // For now, return a placeholder signature
    // In practice, this would involve creating EIP-712 typed data and signing
    return ApprovalSignature(
      v: 27,
      r: BigInt.zero,
      s: BigInt.zero,
      deadline: BigInt.from(deadlineTimestamp),
      nonce: nonce,
    );
  }

  void dispose() {
    _contractCache.clear();
  }
}

/// Token approval transaction data
class ApprovalTransaction {
  final String to;
  final Uint8List data;
  final BigInt gasEstimate;
  final SwapToken token;
  final String spender;
  final BigInt amount;

  const ApprovalTransaction({
    required this.to,
    required this.data,
    required this.gasEstimate,
    required this.token,
    required this.spender,
    required this.amount,
  });
}

/// EIP-2612 permit signature
class ApprovalSignature {
  final int v;
  final BigInt r;
  final BigInt s;
  final BigInt deadline;
  final BigInt nonce;

  const ApprovalSignature({
    required this.v,
    required this.r,
    required this.s,
    required this.deadline,
    required this.nonce,
  });
}

/// Exception thrown when token approval operations fail
class TokenApprovalException implements Exception {
  final String message;
  final dynamic originalError;

  const TokenApprovalException(this.message, {this.originalError});

  @override
  String toString() => 'TokenApprovalException: $message';
}