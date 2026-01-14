import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

import '../../../../shared/providers/transaction_history_provider.dart';
import '../../../../shared/providers/wallet_provider.dart';
// import '../../../../core/wallet_service.dart';

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
    Future.microtask(
      () => ref.read(transactionHistoryProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletState = ref.watch(walletProvider);
    final historyState = ref.watch(transactionHistoryProvider);
    final chain = ref.read(walletProvider.notifier).selectedChainConfig;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Decorations
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withOpacity(0.05),
              ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text('${chain.symbol} ${l10n.transactionHistory}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: colorScheme.surface.withOpacity(0.4)),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
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
              
              if (walletState.selectedAccount == null)
                const SliverFillRemaining(child: Center(child: Text('No wallet loaded')))
              else if (historyState.error != null)
                SliverFillRemaining(child: _buildErrorState(historyState.error!, l10n))
              else if (historyState.isLoading && historyState.transactions.isEmpty)
                SliverPadding(padding: const EdgeInsets.all(16), sliver: _buildShimmerGrid())
              else if (historyState.transactions.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(chain, theme))
              else
                _buildTransactionList(historyState.transactions, chain, theme, colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('${l10n.commonError}: $error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(transactionHistoryProvider.notifier).refresh(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic chain, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: theme.colorScheme.outline.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text('No transactions yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your ${chain.symbol} transactions will appear here once you start using your wallet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions, dynamic chain, ThemeData theme, ColorScheme colorScheme) {
    final grouped = _groupByDate(transactions);
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = grouped.entries.toList()[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...entry.value.asMap().entries.map((e) {
                  return _TransactionCard(transaction: e.value, chain: chain);
                }),
              ],
            );
          },
          childCount: grouped.length,
        ),
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

  Widget _buildShimmerGrid() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 80,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        childCount: 5,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSend = transaction.type == TransactionType.send;
    final color = isSend ? Colors.redAccent : Colors.greenAccent.shade700;

    final chainConfig = chain as ChainConfig;
    final decimals = chainConfig.decimals;
    final divisor = BigInt.from(10).pow(decimals);
    final formattedAmount = (transaction.amount / divisor)
        .toStringAsFixed(decimals > 4 ? 4 : decimals);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSend ? Icons.upload_rounded : Icons.download_rounded,
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              isSend ? 'Sent Tokens' : 'Received Tokens',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${transaction.hash.substring(0, 10)}...',
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isSend ? "-" : "+"}$formattedAmount ${chainConfig.symbol}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(transaction.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: transaction.hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction hash copied')),
              );
            },
          ),
        ),
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
