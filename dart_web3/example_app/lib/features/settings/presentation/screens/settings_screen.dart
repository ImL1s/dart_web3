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
          // Preferences Section
          const _SectionHeader(title: 'Preferences'),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.dark_mode, color: colorScheme.primary),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use system theme'),
                  trailing: Switch(
                    value: true, // Placeholder
                    onChanged: (value) {
                      // TODO: Implement theme switching
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Theme switching coming soon!')),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.currency_exchange, color: colorScheme.primary),
                  title: const Text('Currency'),
                  subtitle: const Text('USD'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement currency selection
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Section
          const _SectionHeader(title: 'Security'),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.security, color: colorScheme.primary),
                  title: const Text('Recovery Phrase'),
                  subtitle: const Text('View or backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show recovery phrase
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.fingerprint, color: colorScheme.primary),
                  title: const Text('Biometric Lock'),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      // TODO: Implement biometrics
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          const _SectionHeader(title: 'About'),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: colorScheme.onPrimaryContainer),
                  ),
                  title: const Text('Web3 Wallet'),
                  subtitle: const Text('v1.0.0 (Beta)'),
                ),
                const Divider(height: 1, indent: 56),
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
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Column(
              children: [
                _PackageTile(
                  name: 'web3_universal_core',
                  description: 'Core utilities',
                ),
                Divider(height: 1, indent: 56),
                _PackageTile(
                  name: 'web3_universal_crypto',
                  description: 'BIP-39/44 HD Wallet',
                ),
                Divider(height: 1, indent: 56),
                _PackageTile(
                  name: 'web3_universal_signer',
                  description: 'Transaction signing',
                ),
                Divider(height: 1, indent: 56),
                _PackageTile(
                  name: 'web3_universal_client',
                  description: 'Blockchain interaction',
                ),
                Divider(height: 1, indent: 56),
                _PackageTile(
                  name: 'web3_universal_swap',
                  description: 'DEX aggregation',
                ),
                Divider(height: 1, indent: 56),
                _PackageTile(
                  name: 'web3_universal_nft',
                  description: 'NFT services',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          const _SectionHeader(title: 'Danger Zone'),
          Card(
            clipBehavior: Clip.antiAlias,
            color: colorScheme.errorContainer.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.error.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: colorScheme.error),
              title: Text(
                'Delete Wallet',
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Remove wallet from this device',
                style: TextStyle(color: colorScheme.error.withOpacity(0.8)),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Wallet?'),
                    content: const Text(
                      'This will permanently remove the wallet from this device. ensure you have backed up your recovery phrase.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                        onPressed: () async {
                          await ref.read(walletProvider.notifier).deleteWallet();
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
          const SizedBox(height: 32),
          
          Center(
            child: Text(
              'Made with ❤️ by dart_web3 Team',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 32),
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
