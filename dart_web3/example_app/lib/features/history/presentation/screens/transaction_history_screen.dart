import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('${chain.symbol} History'),
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
      body: _buildBody(walletState, historyState, chain),
    );
  }

  Widget _buildBody(
    WalletState walletState,
    TransactionHistoryState historyState,
    dynamic chain,
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
            Text('Error: ${historyState.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(transactionHistoryProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (historyState.isLoading && historyState.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyState.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
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

    return RefreshIndicator(
      onRefresh: () => ref.read(transactionHistoryProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historyState.transactions.length,
        itemBuilder: (context, index) {
          final tx = historyState.transactions[index];
          return _TransactionCard(transaction: tx, chain: chain);
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
