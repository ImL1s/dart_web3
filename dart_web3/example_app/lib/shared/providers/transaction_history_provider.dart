/// Transaction History Provider
///
/// Fetches transaction history from blockchain APIs for all supported chains.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wallet_provider.dart';

/// Transaction model
class Transaction {
  const Transaction({
    required this.hash,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.from,
    required this.to,
    this.status = TransactionStatus.confirmed,
    this.fee,
  });

  final String hash;
  final TransactionType type;
  final BigInt amount;
  final DateTime timestamp;
  final String from;
  final String to;
  final TransactionStatus status;
  final BigInt? fee;

  String get formattedAmount => type == TransactionType.send
      ? '-${_formatAmount(amount)}'
      : '+${_formatAmount(amount)}';

  String _formatAmount(BigInt value) {
    // Simplified formatting - caller should apply decimals
    return value.toString();
  }
}

enum TransactionType { send, receive }

enum TransactionStatus { pending, confirmed, failed }

/// Transaction history state
class TransactionHistoryState {
  const TransactionHistoryState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  final List<Transaction> transactions;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  TransactionHistoryState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Transaction history notifier
class TransactionHistoryNotifier
    extends StateNotifier<TransactionHistoryState> {
  TransactionHistoryNotifier(this._ref)
      : super(const TransactionHistoryState());

  final Ref _ref;

  /// Fetches transaction history for the selected account
  Future<void> refresh() async {
    final walletState = _ref.read(walletProvider);
    final account = walletState.selectedAccount;
    if (account == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final transactions = await _fetchTransactions(account);
      state = TransactionHistoryState(
        transactions: transactions,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<Transaction>> _fetchTransactions(Account account) async {
    return switch (account.chain.type) {
      ChainType.ethereum || ChainType.polygon => _fetchEvmTransactions(account),
      ChainType.bitcoin => _fetchBitcoinTransactions(account),
      ChainType.solana => _fetchSolanaTransactions(account),
      _ => [],
    };
  }

  Future<List<Transaction>> _fetchEvmTransactions(Account account) async {
    // For demo, return mock data
    // In production: Use Etherscan/Polygonscan API
    // Example: https://api.etherscan.io/api?module=account&action=txlist&address=...
    return _mockTransactions(account);
  }

  Future<List<Transaction>> _fetchBitcoinTransactions(Account account) async {
    // For demo, return mock data
    // In production: Use Blockstream API
    // Example: https://blockstream.info/api/address/{address}/txs
    return _mockTransactions(account);
  }

  Future<List<Transaction>> _fetchSolanaTransactions(Account account) async {
    // For demo, return mock data
    // In production: Use Solana RPC getSignaturesForAddress
    return _mockTransactions(account);
  }

  List<Transaction> _mockTransactions(Account account) {
    final now = DateTime.now();
    return [
      Transaction(
        hash: '${account.chain.symbol.toLowerCase()}...mock1',
        type: TransactionType.send,
        amount: BigInt.from(100000000), // 0.1 in 8 decimals
        timestamp: now.subtract(const Duration(hours: 2)),
        from: account.address,
        to: 'recipient1...',
      ),
      Transaction(
        hash: '${account.chain.symbol.toLowerCase()}...mock2',
        type: TransactionType.receive,
        amount: BigInt.from(500000000), // 0.5
        timestamp: now.subtract(const Duration(days: 1)),
        from: 'sender1...',
        to: account.address,
      ),
      Transaction(
        hash: '${account.chain.symbol.toLowerCase()}...mock3',
        type: TransactionType.send,
        amount: BigInt.from(250000000), // 0.25
        timestamp: now.subtract(const Duration(days: 3)),
        from: account.address,
        to: 'recipient2...',
      ),
    ];
  }
}

/// Transaction history provider
final transactionHistoryProvider =
    StateNotifierProvider<TransactionHistoryNotifier, TransactionHistoryState>(
  (ref) => TransactionHistoryNotifier(ref),
);
