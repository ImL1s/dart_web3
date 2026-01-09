import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(balanceProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar.large(
              title: Text(l10n.appTitle),
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
                    totalBalance: balanceState.totalUsdValue > 0
                        ? '\$${balanceState.totalUsdValue.toStringAsFixed(2)}'
                        : null,
                    onCopyAddress: () {
                      if (walletState.selectedAccount != null) {
                        Clipboard.setData(
                          ClipboardData(
                            text: walletState.selectedAccount!.address,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copiedToClipboard)),
                        );
                      }
                    },
                    label: l10n.balance,
                  ),
                  const SizedBox(height: 24),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_upward_rounded,
                          label: l10n.send,
                          onTap: () => context.go('/send'),
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_downward_rounded,
                          label: l10n.receive,
                          onTap: () => context.go('/receive'),
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.history_rounded,
                          label: l10n.transactionHistory,
                          onTap: () => context.go('/history'),
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Smart Wallet Button
                  _ActionButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: l10n.smartWallet,
                    onTap: () => context.go('/smart-wallet'),
                    color: colorScheme.tertiary,
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
                    final isSelected =
                        walletState.selectedChain == account.chain.type;

                    return _NetworkTile(
                      chainName: account.chain.name,
                      symbol: account.chain.symbol,
                      address: account.address,
                      balance:
                          balance?.formatted ?? '0 ${account.chain.symbol}',
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(walletProvider.notifier)
                            .selectChain(account.chain.type);
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
    required this.label,
    this.totalBalance,
  });

  final String address;
  final bool isLoading;
  final VoidCallback onCopyAddress;
  final String label;
  final String? totalBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.7),
            colorScheme.tertiary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet label
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Main Wallet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.qr_code_rounded,
                    color: Colors.white70, size: 22),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Address row
          GestureDetector(
            onTap: onCopyAddress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address.length >= 10
                        ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
                        : address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded,
                      color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Balance display
          if (isLoading)
            _buildShimmerBalance(theme)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    totalBalance ?? 'Multi-Chain',
                    key: ValueKey(totalBalance),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerBalance(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 160,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
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

  // Chain icon mapping
  IconData _getChainIcon() {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return Icons.diamond_outlined;
      case 'BTC':
        return Icons.currency_bitcoin;
      case 'SOL':
        return Icons.wb_sunny_outlined;
      case 'MATIC':
        return Icons.hexagon_outlined;
      case 'OP':
        return Icons.circle_outlined;
      default:
        return Icons.link;
    }
  }

  // Chain color mapping
  Color _getChainColor() {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'BTC':
        return const Color(0xFFF7931A);
      case 'SOL':
        return const Color(0xFF14F195);
      case 'MATIC':
        return const Color(0xFF8247E5);
      case 'OP':
        return const Color(0xFFFF0420);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chainColor = _getChainColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? chainColor.withOpacity(0.1) : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? chainColor : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Chain icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: chainColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getChainIcon(),
                    color: chainColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Chain info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            chainName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: chainColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Active',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: chainColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address.substring(0, 8)}...${address.substring(address.length - 6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balance,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      symbol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: chainColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
