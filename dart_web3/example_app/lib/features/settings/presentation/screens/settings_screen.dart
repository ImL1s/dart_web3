import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/wallet_provider.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About section
          const _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Web3 Wallet'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Powered by'),
                  subtitle: Text('dart_web3 SDK'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SDK Packages section
          const _SectionHeader(title: 'SDK Packages Used'),
          const Card(
            child: Column(
              children: [
                _PackageTile(
                  name: 'web3_universal_core',
                  description: 'Core utilities',
                ),
                Divider(),
                _PackageTile(
                  name: 'web3_universal_crypto',
                  description: 'BIP-39/44 HD Wallet',
                ),
                Divider(),
                _PackageTile(
                  name: 'web3_universal_signer',
                  description: 'Transaction signing',
                ),
                Divider(),
                _PackageTile(
                  name: 'web3_universal_client',
                  description: 'Blockchain interaction',
                ),
                Divider(),
                _PackageTile(
                  name: 'web3_universal_swap',
                  description: 'DEX aggregation',
                ),
                Divider(),
                _PackageTile(
                  name: 'web3_universal_nft',
                  description: 'NFT services',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security section
          const _SectionHeader(title: 'Security'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.security,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Recovery Phrase'),
                  subtitle: const Text('View or backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show recovery phrase with auth
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.fingerprint,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Biometric Lock'),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      // TODO: Enable biometric
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger zone
          const _SectionHeader(title: 'Danger Zone'),
          Card(
            color: colorScheme.errorContainer.withOpacity(0.3),
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: colorScheme.error,
              ),
              title: Text(
                'Delete Wallet',
                style: TextStyle(color: colorScheme.error),
              ),
              subtitle: const Text('Remove wallet from this device'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Wallet?'),
                    content: const Text(
                      'This will remove your wallet from this device. Make sure you have backed up your recovery phrase.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                        ),
                        onPressed: () async {
                          await ref
                              .read(walletProvider.notifier)
                              .clearWallet();
                          if (context.mounted) {
                            context.go('/onboarding');
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final String name;
  final String description;

  const _PackageTile({
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.extension, size: 20),
      title: Text(
        name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      subtitle: Text(description),
    );
  }
}
