import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../shared/providers/smart_wallet_provider.dart';
import '../../../../shared/providers/wallet_provider.dart';

/// Smart Wallet Screen - Demonstrates ERC-4337 Account Abstraction.
class SmartWalletScreen extends ConsumerStatefulWidget {
  const SmartWalletScreen({super.key});

  @override
  ConsumerState<SmartWalletScreen> createState() => _SmartWalletScreenState();
}

class _SmartWalletScreenState extends ConsumerState<SmartWalletScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize smart account on screen load
    Future.microtask(() {
      ref.read(smartWalletProvider.notifier).initializeSmartAccount();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final smartWalletState = ref.watch(smartWalletProvider);
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.smartWallet),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: smartWalletState.isLoading && smartWalletState.smartAccountAddress == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Smart Account Card
                  _SmartAccountCard(
                    address: smartWalletState.smartAccountAddress ?? 'Loading...',
                    isDeployed: smartWalletState.isDeployed,
                    eoaAddress: walletState.selectedAccount?.address ?? '',
                    colorScheme: colorScheme,
                    theme: theme,
                    l10n: l10n,
                  ),
                  const SizedBox(height: 24),

                  // UserOperation Section
                  Text(
                    'Send UserOperation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Recipient Field
                  TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Address',
                      hintText: '0x...',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount Field
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (ETH)',
                      hintText: '0.001',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Send Button
                  FilledButton.icon(
                    onPressed: smartWalletState.isLoading ? null : _sendUserOperation,
                    icon: smartWalletState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(l10n.sendUserOp),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),

                  // Error Display
                  if (smartWalletState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              smartWalletState.error!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Pending UserOp Hash
                  if (smartWalletState.pendingUserOpHash != null) ...[
                    const SizedBox(height: 24),
                    _UserOpHashCard(
                      hash: smartWalletState.pendingUserOpHash!,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Info Section
                  _InfoSection(colorScheme: colorScheme, theme: theme),
                ],
              ),
            ),
    );
  }

  Future<void> _sendUserOperation() async {
    final recipient = _recipientController.text.trim();
    final amountStr = _amountController.text.trim();

    if (recipient.isEmpty || amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Parse amount to Wei
    final amountEth = double.tryParse(amountStr) ?? 0;
    final amountWei = BigInt.from(amountEth * 1e18);

    final hash = await ref.read(smartWalletProvider.notifier).sendUserOperation(
      to: recipient,
      value: amountWei,
    );

    if (hash != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('UserOp submitted: ${hash.substring(0, 10)}...')),
      );
    }
  }
}

class _SmartAccountCard extends StatelessWidget {
  const _SmartAccountCard({
    required this.address,
    required this.isDeployed,
    required this.eoaAddress,
    required this.colorScheme,
    required this.theme,
    required this.l10n,
  });

  final String address;
  final bool isDeployed;
  final String eoaAddress;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.smartWallet,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDeployed ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDeployed ? 'Deployed' : l10n.accountNotDeployed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Account Address',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.copiedToClipboard)),
                );
              },
              child: Text(
                address,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Owner (EOA)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              eoaAddress.isNotEmpty
                  ? '${eoaAddress.substring(0, 10)}...${eoaAddress.substring(eoaAddress.length - 8)}'
                  : 'N/A',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserOpHashCard extends StatelessWidget {
  const _UserOpHashCard({
    required this.hash,
    required this.colorScheme,
    required this.theme,
  });

  final String hash;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tag, color: colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'UserOp Hash',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hash copied!')),
                );
              },
              child: Text(
                hash,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.colorScheme,
    required this.theme,
  });

  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'About ERC-4337',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Smart Wallets use smart contract logic instead of private keys. '
              'This enables features like:\n'
              '• Gas sponsorship (Paymasters)\n'
              '• Batch transactions\n'
              '• Social recovery\n'
              '• Custom validation logic',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
