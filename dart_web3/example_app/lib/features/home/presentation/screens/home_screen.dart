import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/balance_provider.dart';
import '../../../../shared/providers/wallet_provider.dart';

/// Home screen - main dashboard with real balances
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load wallet and fetch balances on init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(walletProvider.notifier).loadWallet();
      ref.read(balanceProvider.notifier).refresh();
      ref.read(balanceProvider.notifier).startAutoRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletState = ref.watch(walletProvider);
    final balanceState = ref.watch(balanceProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(balanceProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar.large(
              title: const Text('Web3 Wallet'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.go('/settings'),
                ),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Total balance card
                  _BalanceCard(
                    address: walletState.selectedAccount?.address ?? '0x...',
                    isLoading: balanceState.isLoading,
                    onCopyAddress: () {
                      if (walletState.selectedAccount != null) {
                        Clipboard.setData(
                          ClipboardData(
                            text: walletState.selectedAccount!.address,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied!')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Send',
                          onTap: () => context.go('/send'),
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Receive',
                          onTap: () => context.go('/receive'),
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.history_rounded,
                          label: 'History',
                          onTap: () => context.go('/history'),
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Networks section
                  Text(
                    'Networks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Chain list
                  ...walletState.accounts.map((account) {
                    final balance = balanceState.getBalance(account.chain.type);
                    final isSelected = walletState.selectedChain == account.chain.type;

                    return _NetworkTile(
                      chainName: account.chain.name,
                      symbol: account.chain.symbol,
                      address: account.address,
                      balance: balance?.formatted ?? '0 ${account.chain.symbol}',
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(walletProvider.notifier).selectChain(account.chain.type);
                      },
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Private Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.address,
    required this.isLoading,
    required this.onCopyAddress,
  });

  final String address;
  final bool isLoading;
  final VoidCallback onCopyAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                onPressed: onCopyAddress,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const CircularProgressIndicator(color: Colors.white)
          else
            Text(
              'Balances loaded',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.chainName,
    required this.symbol,
    required this.address,
    required this.balance,
    required this.isSelected,
    required this.onTap,
  });

  final String chainName;
  final String symbol;
  final String address;
  final String balance;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Text(
            symbol.substring(0, 1),
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
        title: Text(chainName),
        subtitle: Text(
          '${address.substring(0, 8)}...${address.substring(address.length - 6)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          balance,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
