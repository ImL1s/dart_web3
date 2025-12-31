import 'dart:convert';
import 'package:http/http.dart' as http;

import '../bridge_quote.dart';
import '../bridge_types.dart';
import 'bridge_protocol.dart';

/// Native L2 bridge protocol implementation (for Arbitrum, Optimism, Base, etc.)
class NativeBridge implements BridgeProtocol {
  final BridgeProtocolConfig config;
  final http.Client _httpClient;

  NativeBridge({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  String get name => 'Native Bridge';

  @override
  List<int> get supportedSourceChains => [
    1,     // Ethereum (to L2s)
    42161, // Arbitrum (to Ethereum)
    10,    // Optimism (to Ethereum)
    8453,  // Base (to Ethereum)
    137,   // Polygon (to Ethereum)
  ];

  @override
  List<int> get supportedDestinationChains => [
    1,     // Ethereum (from L2s)
    42161, // Arbitrum (from Ethereum)
    10,    // Optimism (from Ethereum)
    8453,  // Base (from Ethereum)
    137,   // Polygon (from Ethereum)
  ];

  @override
  bool supportsChainPair(int sourceChainId, int destinationChainId) {
    // Native bridges only work between Ethereum and specific L2s
    final l2Chains = [42161, 10, 8453, 137]; // Arbitrum, Optimism, Base, Polygon
    
    return (sourceChainId == 1 && l2Chains.contains(destinationChainId)) ||
           (l2Chains.contains(sourceChainId) && destinationChainId == 1);
  }

  @override
  Future<BridgeQuote?> getQuote(BridgeParams params) async {
    if (!validateParams(params)) {
      throw BridgeException(
        protocol: name,
        message: 'Invalid bridge parameters',
      );
    }

    try {
      // Native bridges typically only support ETH and some specific tokens
      if (!_isSupportedToken(params.fromToken)) {
        return null;
      }

      final isDeposit = params.sourceChainId == 1; // Ethereum to L2
      final bridgeInfo = _getBridgeInfo(params.sourceChainId, params.destinationChainId);
      
      // Calculate output amount (1:1 for native bridges, minus fees)
      final feeBreakdown = await getFeeBreakdown(params);
      final outputAmount = params.amount - feeBreakdown.totalFee;
      final minimumOutputAmount = calculateMinimumOutput(outputAmount, params.slippage);

      // Create route
      final estimatedTime = await getEstimatedTime(
        params.sourceChainId,
        params.destinationChainId,
        params.amount,
      );

      final route = BridgeRoute(
        protocol: name,
        steps: [
          BridgeStep(
            fromChainId: params.sourceChainId,
            toChainId: params.destinationChainId,
            protocol: name,
            fromToken: params.fromToken,
            toToken: params.toToken,
            inputAmount: params.amount,
            outputAmount: outputAmount,
            fee: feeBreakdown.totalFee,
            estimatedTime: estimatedTime,
          ),
        ],
        estimatedTime: estimatedTime,
        totalFee: feeBreakdown.totalFee,
        confidence: isDeposit ? 0.99 : 0.95, // Deposits are more reliable than withdrawals
      );

      // Get limits
      final limits = await getBridgeLimits(
        params.fromToken,
        params.sourceChainId,
        params.destinationChainId,
      );

      return BridgeQuote(
        protocol: '${bridgeInfo.name} Native Bridge',
        params: params,
        outputAmount: outputAmount,
        minimumOutputAmount: minimumOutputAmount,
        route: route,
        feeBreakdown: feeBreakdown,
        limits: limits,
        estimatedTime: estimatedTime,
        confidence: route.confidence,
        validUntil: const Duration(hours: 1), // Native bridge quotes are stable
        metadata: {
          'bridgeType': isDeposit ? 'deposit' : 'withdrawal',
          'challengePeriod': bridgeInfo.challengePeriod.inDays,
          'bridgeContract': bridgeInfo.contractAddress,
        },
      );
    } catch (e) {
      if (e is BridgeException) rethrow;
      throw BridgeException(
        protocol: name,
        message: 'Failed to get quote: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<BridgeToken>> getSupportedTokens(
    int sourceChainId,
    int destinationChainId,
  ) async {
    if (!supportsChainPair(sourceChainId, destinationChainId)) {
      throw BridgeException(
        protocol: name,
        message: 'Chain pair not supported: $sourceChainId -> $destinationChainId',
      );
    }

    // Native bridges typically support ETH and a few whitelisted tokens
    final tokens = <BridgeToken>[];
    
    // ETH is always supported
    tokens.add(BridgeToken(
      address: '0x0000000000000000000000000000000000000000',
      symbol: 'ETH',
      name: 'Ethereum',
      decimals: 18,
      chainId: sourceChainId,
    ));

    // Add some common ERC-20 tokens that are typically supported
    final commonTokens = _getCommonTokensForChain(sourceChainId);
    tokens.addAll(commonTokens);

    return tokens;
  }

  @override
  Future<bool> isTokenPairSupported(
    BridgeToken sourceToken,
    BridgeToken destinationToken,
    int sourceChainId,
    int destinationChainId,
  ) async {
    if (!supportsChainPair(sourceChainId, destinationChainId)) return false;
    
    // For native bridges, tokens must be the same (ETH <-> ETH, USDC <-> USDC)
    return sourceToken.symbol.toUpperCase() == destinationToken.symbol.toUpperCase() &&
           _isSupportedToken(sourceToken);
  }

  @override
  Future<BridgeLimits> getBridgeLimits(
    BridgeToken token,
    int sourceChainId,
    int destinationChainId,
  ) async {
    final isDeposit = sourceChainId == 1;
    
    if (isDeposit) {
      // Deposits typically have higher limits
      return BridgeLimits(
        minAmount: BigInt.from(1000000000000000), // 0.001 ETH
        maxAmount: BigInt.parse('1000000000000000000000'), // 1000 ETH
        dailyLimit: BigInt.parse('10000000000000000000000'), // 10000 ETH
        remainingDailyLimit: BigInt.parse('10000000000000000000000'),
      );
    } else {
      // Withdrawals may have lower limits due to liquidity constraints
      return BridgeLimits(
        minAmount: BigInt.from(1000000000000000), // 0.001 ETH
        maxAmount: BigInt.parse('100000000000000000000'), // 100 ETH
        dailyLimit: BigInt.parse('1000000000000000000000'), // 1000 ETH
        remainingDailyLimit: BigInt.parse('1000000000000000000000'),
      );
    }
  }

  @override
  Future<Duration> getEstimatedTime(
    int sourceChainId,
    int destinationChainId,
    BigInt amount,
  ) async {
    final isDeposit = sourceChainId == 1;
    final bridgeInfo = _getBridgeInfo(sourceChainId, destinationChainId);
    
    if (isDeposit) {
      // Deposits are typically fast (5-15 minutes)
      return const Duration(minutes: 10);
    } else {
      // Withdrawals require challenge period
      return bridgeInfo.challengePeriod + const Duration(hours: 1);
    }
  }

  @override
  Future<BridgeFeeBreakdown> getFeeBreakdown(BridgeParams params) async {
    final isDeposit = params.sourceChainId == 1;
    
    if (isDeposit) {
      // Deposit fees are typically just gas costs
      final gasFee = BigInt.from(50000000000000000); // ~0.05 ETH
      
      return BridgeFeeBreakdown(
        protocolFee: BigInt.zero,
        gasFee: gasFee,
        relayerFee: BigInt.zero,
        liquidityFee: BigInt.zero,
        totalFee: gasFee,
        feeToken: 'ETH',
      );
    } else {
      // Withdrawal fees include gas on both chains
      final l2GasFee = BigInt.from(5000000000000000); // ~0.005 ETH on L2
      final l1GasFee = BigInt.from(30000000000000000); // ~0.03 ETH on L1
      final totalFee = l2GasFee + l1GasFee;
      
      return BridgeFeeBreakdown(
        protocolFee: BigInt.zero,
        gasFee: totalFee,
        relayerFee: BigInt.zero,
        liquidityFee: BigInt.zero,
        totalFee: totalFee,
        feeToken: 'ETH',
      );
    }
  }

  bool _isSupportedToken(BridgeToken token) {
    final supportedSymbols = ['ETH', 'WETH', 'USDC', 'USDT', 'DAI'];
    return supportedSymbols.contains(token.symbol.toUpperCase());
  }

  List<BridgeToken> _getCommonTokensForChain(int chainId) {
    // Return common tokens that are typically supported by native bridges
    return [
      BridgeToken(
        address: _getUSDCAddress(chainId),
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        chainId: chainId,
      ),
      BridgeToken(
        address: _getUSDTAddress(chainId),
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        chainId: chainId,
      ),
    ];
  }

  String _getUSDCAddress(int chainId) {
    switch (chainId) {
      case 1: return '0xA0b86a33E6441c8C06DD2b7c94b7E6E8E8b8b8b8'; // Ethereum USDC
      case 42161: return '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8'; // Arbitrum USDC
      case 10: return '0x7F5c764cBc14f9669B88837ca1490cCa17c31607'; // Optimism USDC
      case 8453: return '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'; // Base USDC
      default: return '0x0000000000000000000000000000000000000000';
    }
  }

  String _getUSDTAddress(int chainId) {
    switch (chainId) {
      case 1: return '0xdAC17F958D2ee523a2206206994597C13D831ec7'; // Ethereum USDT
      case 42161: return '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9'; // Arbitrum USDT
      case 10: return '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'; // Optimism USDT
      case 137: return '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'; // Polygon USDT
      default: return '0x0000000000000000000000000000000000000000';
    }
  }

  _NativeBridgeInfo _getBridgeInfo(int sourceChainId, int destinationChainId) {
    final l2ChainId = sourceChainId == 1 ? destinationChainId : sourceChainId;
    
    switch (l2ChainId) {
      case 42161: // Arbitrum
        return _NativeBridgeInfo(
          name: 'Arbitrum',
          contractAddress: '0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a',
          challengePeriod: const Duration(days: 7),
        );
      case 10: // Optimism
        return _NativeBridgeInfo(
          name: 'Optimism',
          contractAddress: '0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1',
          challengePeriod: const Duration(days: 7),
        );
      case 8453: // Base
        return _NativeBridgeInfo(
          name: 'Base',
          contractAddress: '0x3154Cf16ccdb4C6d922629664174b904d80F2C35',
          challengePeriod: const Duration(days: 7),
        );
      case 137: // Polygon
        return _NativeBridgeInfo(
          name: 'Polygon',
          contractAddress: '0xA0c68C638235ee32657e8f720a23ceC1bFc77C77',
          challengePeriod: const Duration(hours: 3), // Polygon has shorter challenge period
        );
      default:
        throw BridgeException(
          protocol: name,
          message: 'Unsupported L2 chain: $l2ChainId',
        );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class _NativeBridgeInfo {
  final String name;
  final String contractAddress;
  final Duration challengePeriod;

  const _NativeBridgeInfo({
    required this.name,
    required this.contractAddress,
    required this.challengePeriod,
  });
}