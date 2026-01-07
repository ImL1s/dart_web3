import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../shared/providers/transaction_history_provider.dart';
import '../../../../shared/providers/wallet_provider.dart';

/// Transaction History Screen
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh on screen load
    Future.microtask(
      () => ref.read(transactionHistoryProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final historyState = ref.watch(transactionHistoryProvider);
    final chain = ref.read(walletProvider.notifier).selectedChainConfig;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${chain.symbol} ${l10n.transactionHistory}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: historyState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: historyState.isLoading
                ? null
                : () => ref.read(transactionHistoryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _buildBody(walletState, historyState, chain, l10n),
    );
  }


  Widget _buildBody(
    WalletState walletState,
    TransactionHistoryState historyState,
    dynamic chain,
    AppLocalizations l10n,
  ) {
    if (walletState.selectedAccount == null) {
      return const Center(child: Text('No wallet loaded'));
    }

    if (historyState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('${l10n.commonError}: ${historyState.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(transactionHistoryProvider.notifier).refresh(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (historyState.isLoading && historyState.transactions.isEmpty) {
      return _buildShimmerList();
    }

    if (historyState.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No transactions yet', // Localize if needed, user didn't request specific key
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${chain.symbol} transactions will appear here',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // Group transactions by date
    final grouped = _groupByDate(historyState.transactions);

    return RefreshIndicator(
      onRefresh: () => ref.read(transactionHistoryProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.toList()[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ...entry.value.asMap().entries.map((e) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 200 + (e.key * 50)),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _TransactionCard(transaction: e.value, chain: chain),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in transactions) {
      final txDate = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      String label;
      if (txDate == today) {
        label = 'Today';
      } else if (txDate == yesterday) {
        label = 'Yesterday';
      } else {
        label = '${tx.timestamp.month}/${tx.timestamp.day}/${tx.timestamp.year}';
      }
      grouped.putIfAbsent(label, () => []).add(tx);
    }
    return grouped;
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.white),
              title: Container(height: 12, width: 80, color: Colors.white),
              subtitle: Container(height: 10, width: 120, color: Colors.white),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 12, width: 60, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(height: 10, width: 40, color: Colors.white),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, required this.chain});

  final Transaction transaction;
  final dynamic chain;

  @override
  Widget build(BuildContext context) {
    final isSend = transaction.type == TransactionType.send;
    final color = isSend ? Colors.red : Colors.green;

    // Format amount with chain decimals
    final chainConfig = chain as ChainConfig;
    final decimals = chainConfig.decimals;
    final divisor = BigInt.from(10).pow(decimals);
    final formattedAmount = (transaction.amount / divisor)
        .toStringAsFixed(decimals > 4 ? 4 : decimals);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isSend ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
          ),
        ),
        title: Text(
          isSend ? 'Sent' : 'Received',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.hash.substring(0, 8)}...${transaction.hash.substring(transaction.hash.length - 6)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isSend ? "-" : "+"}$formattedAmount ${chain.symbol}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatTimestamp(transaction.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () {
          // TODO: Show transaction details or open explorer
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('TX: ${transaction.hash}')),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
