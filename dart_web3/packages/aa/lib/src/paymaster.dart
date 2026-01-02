
import 'package:dart_web3_provider/dart_web3_provider.dart';

import 'user_operation.dart';

/// Abstract base class for Paymaster implementations.
/// 
/// A Paymaster is a contract that can sponsor UserOperations by paying
/// the gas fees on behalf of users. This enables gasless transactions
/// and other advanced payment models.
abstract class Paymaster {
  /// Gets paymaster data for a UserOperation.
  /// 
  /// Returns null if this paymaster cannot or will not sponsor the operation.
  Future<PaymasterData?> getPaymasterData(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  });

  /// Validates that the paymaster can sponsor the given UserOperation.
  Future<bool> canSponsor(UserOperation userOp);

  /// Gets the paymaster address.
  String get address;
}

/// Paymaster data to be included in a UserOperation.
class PaymasterData {

  PaymasterData({
    required this.paymaster,
    required this.paymasterData,
    this.paymasterVerificationGasLimit,
    this.paymasterPostOpGasLimit,
    this.paymasterSignature,
  });

  /// Creates PaymasterData from JSON response.
  factory PaymasterData.fromJson(Map<String, dynamic> json) {
    return PaymasterData(
      paymaster: json['paymaster'] as String,
      paymasterData: json['paymasterData'] as String,
      paymasterVerificationGasLimit: json['paymasterVerificationGasLimit'] != null
          ? BigInt.parse(json['paymasterVerificationGasLimit'] as String)
          : null,
      paymasterPostOpGasLimit: json['paymasterPostOpGasLimit'] != null
          ? BigInt.parse(json['paymasterPostOpGasLimit'] as String)
          : null,
      paymasterSignature: json['paymasterSignature'] as String?,
    );
  }
  /// The paymaster contract address.
  final String paymaster;

  /// Data to be passed to the paymaster contract.
  final String paymasterData;

  /// Gas limit for paymaster verification (EntryPoint v0.7+).
  final BigInt? paymasterVerificationGasLimit;

  /// Gas limit for paymaster post-operation (EntryPoint v0.7+).
  final BigInt? paymasterPostOpGasLimit;

  /// Paymaster signature for parallelizable signing (EntryPoint v0.9+).
  final String? paymasterSignature;

  /// Converts PaymasterData to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'paymaster': paymaster,
      'paymasterData': paymasterData,
    };

    if (paymasterVerificationGasLimit != null) {
      json['paymasterVerificationGasLimit'] = '0x${paymasterVerificationGasLimit!.toRadixString(16)}';
    }
    if (paymasterPostOpGasLimit != null) {
      json['paymasterPostOpGasLimit'] = '0x${paymasterPostOpGasLimit!.toRadixString(16)}';
    }
    if (paymasterSignature != null) {
      json['paymasterSignature'] = paymasterSignature;
    }

    return json;
  }

  /// Applies this paymaster data to a UserOperation.
  UserOperation applyToUserOperation(UserOperation userOp) {
    return userOp.copyWith(
      paymaster: paymaster,
      paymasterData: paymasterData,
      paymasterVerificationGasLimit: paymasterVerificationGasLimit,
      paymasterPostOpGasLimit: paymasterPostOpGasLimit,
      paymasterSignature: paymasterSignature,
    );
  }

  /// For EntryPoint v0.6, combines paymaster fields into paymasterAndData.
  String toPaymasterAndData() {
    if (paymasterData.isEmpty || paymasterData == '0x') {
      return paymaster;
    }
    return paymaster + paymasterData.replaceFirst('0x', '');
  }
}

/// HTTP-based paymaster that communicates with a paymaster service.
class HttpPaymaster implements Paymaster {

  HttpPaymaster({
    required String paymasterUrl,
    required String paymasterAddress,
    Map<String, String> headers = const {},
  }) : _paymasterAddress = paymasterAddress,
       _provider = RpcProvider(HttpTransport(paymasterUrl, headers: headers));
  final String _paymasterAddress;
  final RpcProvider _provider;

  @override
  String get address => _paymasterAddress;

  @override
  Future<PaymasterData?> getPaymasterData(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  }) async {
    try {
      final result = await _provider.call<Map<String, dynamic>>(
        'pm_sponsorUserOperation',
        [
          userOp.toJson(),
          entryPointAddress,
          chainId,
        ],
      );

      return PaymasterData.fromJson(result);
    } catch (e) {
      // Paymaster declined to sponsor
      return null;
    }
  }

  @override
  Future<bool> canSponsor(UserOperation userOp) async {
    try {
      final result = await _provider.call<bool>(
        'pm_canSponsor',
        [userOp.toJson()],
      );
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Gets paymaster metadata such as supported tokens, policies, etc.
  Future<Map<String, dynamic>?> getPaymasterMetadata() async {
    try {
      final result = await _provider.call<Map<String, dynamic>>(
        'pm_getPaymasterMetadata',
        [],
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Disposes of the paymaster client.
  void dispose() {
    _provider.dispose();
  }
}

/// Verifying paymaster that requires users to deposit tokens.
class VerifyingPaymaster implements Paymaster {

  VerifyingPaymaster({
    required String paymasterAddress,
    required RpcProvider provider,
  }) : _paymasterAddress = paymasterAddress,
       _provider = provider;
  final String _paymasterAddress;
  final RpcProvider _provider;

  @override
  String get address => _paymasterAddress;

  @override
  Future<PaymasterData?> getPaymasterData(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  }) async {
    // Check if user has sufficient deposit
    final hasDeposit = await _checkUserDeposit(userOp.sender);
    if (!hasDeposit) return null;

    // Generate paymaster data
    final paymasterData = await _generatePaymasterData(userOp);
    
    return PaymasterData(
      paymaster: _paymasterAddress,
      paymasterData: paymasterData,
      paymasterVerificationGasLimit: BigInt.from(100000),
      paymasterPostOpGasLimit: BigInt.from(50000),
    );
  }

  @override
  Future<bool> canSponsor(UserOperation userOp) async {
    return _checkUserDeposit(userOp.sender);
  }

  /// Checks if the user has sufficient deposit in the paymaster.
  Future<bool> _checkUserDeposit(String userAddress) async {
    try {
      // Call paymaster contract to check deposit
      final result = await _provider.call<String>(
        'eth_call',
        [
          {
            'to': _paymasterAddress,
            'data': _encodeBalanceOfCall(userAddress),
          },
          'latest',
        ],
      );

      final balance = BigInt.parse(result);
      return balance > BigInt.zero;
    } catch (e) {
      return false;
    }
  }

  /// Generates paymaster-specific data for the UserOperation.
  Future<String> _generatePaymasterData(UserOperation userOp) async {
    // This would typically include:
    // - Validation timestamp
    // - Signature from paymaster
    // - Any additional data required by the paymaster contract
    
    // For now, return empty data
    return '0x';
  }

  /// Encodes a balanceOf function call.
  String _encodeBalanceOfCall(String userAddress) {
    // balanceOf(address) function selector: 0x70a08231
    final selector = '70a08231';
    final paddedAddress = userAddress.replaceFirst('0x', '').padLeft(64, '0');
    return '0x$selector$paddedAddress';
  }
}

/// ERC-20 token paymaster that accepts specific tokens as payment.
class TokenPaymaster implements Paymaster { // Token units per gas unit

  TokenPaymaster({
    required String paymasterAddress,
    required String tokenAddress,
    required RpcProvider provider,
    required BigInt exchangeRate,
  }) : _paymasterAddress = paymasterAddress,
       _tokenAddress = tokenAddress,
       _provider = provider,
       _exchangeRate = exchangeRate;
  final String _paymasterAddress;
  final String _tokenAddress;
  final RpcProvider _provider;
  final BigInt _exchangeRate;

  @override
  String get address => _paymasterAddress;

  @override
  Future<PaymasterData?> getPaymasterData(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  }) async {
    // Check if user has sufficient token balance
    final hasTokens = await _checkTokenBalance(userOp.sender, userOp);
    if (!hasTokens) return null;

    // Calculate required token amount
    final tokenAmount = _calculateTokenAmount(userOp);
    
    // Encode paymaster data with token information
    final paymasterData = _encodeTokenPaymasterData(tokenAmount);

    return PaymasterData(
      paymaster: _paymasterAddress,
      paymasterData: paymasterData,
      paymasterVerificationGasLimit: BigInt.from(150000),
      paymasterPostOpGasLimit: BigInt.from(100000),
    );
  }

  @override
  Future<bool> canSponsor(UserOperation userOp) async {
    return _checkTokenBalance(userOp.sender, userOp);
  }

  /// Checks if the user has sufficient token balance.
  Future<bool> _checkTokenBalance(String userAddress, UserOperation userOp) async {
    try {
      // Get user's token balance
      final result = await _provider.call<String>(
        'eth_call',
        [
          {
            'to': _tokenAddress,
            'data': _encodeBalanceOfCall(userAddress),
          },
          'latest',
        ],
      );

      final balance = BigInt.parse(result);
      final requiredAmount = _calculateTokenAmount(userOp);
      
      return balance >= requiredAmount;
    } catch (e) {
      return false;
    }
  }

  /// Calculates the required token amount for the UserOperation.
  BigInt _calculateTokenAmount(UserOperation userOp) {
    final totalGas = userOp.callGasLimit + 
                    userOp.verificationGasLimit + 
                    userOp.preVerificationGas;
    
    return totalGas * userOp.maxFeePerGas * _exchangeRate ~/ BigInt.from(10).pow(18);
  }

  /// Encodes paymaster data with token amount.
  String _encodeTokenPaymasterData(BigInt tokenAmount) {
    // Encode token address and amount
    final tokenAddressHex = _tokenAddress.replaceFirst('0x', '').padLeft(64, '0');
    final tokenAmountHex = tokenAmount.toRadixString(16).padLeft(64, '0');
    
    return '0x$tokenAddressHex$tokenAmountHex';
  }

  /// Encodes a balanceOf function call.
  String _encodeBalanceOfCall(String userAddress) {
    // balanceOf(address) function selector: 0x70a08231
    final selector = '70a08231';
    final paddedAddress = userAddress.replaceFirst('0x', '').padLeft(64, '0');
    return '0x$selector$paddedAddress';
  }
}

/// Paymaster manager that handles multiple paymaster options.
class PaymasterManager {

  PaymasterManager(this._paymasters);
  final List<Paymaster> _paymasters;

  /// Finds the best paymaster for a UserOperation.
  /// 
  /// Returns null if no paymaster can sponsor the operation.
  Future<PaymasterData?> getBestPaymaster(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  }) async {
    for (final paymaster in _paymasters) {
      final canSponsor = await paymaster.canSponsor(userOp);
      if (canSponsor) {
        final paymasterData = await paymaster.getPaymasterData(
          userOp,
          entryPointAddress: entryPointAddress,
          chainId: chainId,
        );
        if (paymasterData != null) {
          return paymasterData;
        }
      }
    }
    return null;
  }

  /// Gets all available paymasters that can sponsor the operation.
  Future<List<PaymasterData>> getAllAvailablePaymasters(
    UserOperation userOp, {
    required String entryPointAddress,
    required int chainId,
  }) async {
    final availablePaymasters = <PaymasterData>[];

    for (final paymaster in _paymasters) {
      final canSponsor = await paymaster.canSponsor(userOp);
      if (canSponsor) {
        final paymasterData = await paymaster.getPaymasterData(
          userOp,
          entryPointAddress: entryPointAddress,
          chainId: chainId,
        );
        if (paymasterData != null) {
          availablePaymasters.add(paymasterData);
        }
      }
    }

    return availablePaymasters;
  }

  /// Adds a paymaster to the manager.
  void addPaymaster(Paymaster paymaster) {
    _paymasters.add(paymaster);
  }

  /// Removes a paymaster from the manager.
  void removePaymaster(Paymaster paymaster) {
    _paymasters.remove(paymaster);
  }

  /// Gets all registered paymasters.
  List<Paymaster> get paymasters => List.unmodifiable(_paymasters);
}
