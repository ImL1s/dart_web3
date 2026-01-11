import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

import '../../../../shared/providers/wallet_provider.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/providers/nft_provider.dart';
import '../../../../shared/providers/swap_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/providers/currency_provider.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final currentCurrency = ref.watch(currencyNotifierProvider);

    final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preferences Section
          _SectionHeader(title: l10n.settingsPreferences), // Preferences
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language, color: colorScheme.primary),
                  title: Text(l10n.language),
                  subtitle: Text(currentLocale.languageCode == 'zh' ? '繁體中文' : 'English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showLanguageDialog(context, ref);
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.dark_mode, color: colorScheme.primary),
                  title: const Text('Dark Mode'),
                  subtitle: Text(themeMode == ThemeMode.system ? 'System Default' : (themeMode == ThemeMode.dark ? 'On' : 'Off')),
                  trailing: Switch(
                    value: isDark, 
                    onChanged: (value) {
                      final newMode = value ? ThemeMode.dark : ThemeMode.light;
                      ref.read(themeNotifierProvider.notifier).setThemeMode(newMode);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.currency_exchange, color: colorScheme.primary),
                  title: const Text('Currency'),
                  subtitle: Text(currentCurrency.code),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showCurrencyDialog(context, ref);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // API Configuration Section
          _SectionHeader(title: l10n.settingsApiConfiguration),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.key_rounded, color: colorScheme.primary),
                  title: Text(l10n.settingsAlchemyApiKey),
                  subtitle: Text(
                    ref.watch(nftProvider).isConfigured 
                        ? l10n.settingsApiConfigured
                        : l10n.settingsApiNotConfigured,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showApiKeyDialog(context, ref);
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                  title: const Text('1inch API Key'),
                  subtitle: Text(
                    ref.watch(swapProvider).isConfigured
                        ? l10n.settingsApiConfigured
                        : l10n.settingsApiNotConfigured,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showSwapApiKeyDialog(context, ref);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Section
          _SectionHeader(title: l10n.settingsSecurity),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.security, color: colorScheme.primary),
                  title: Text(l10n.settingsRecoveryPhrase),
                  subtitle: Text(l10n.settingsViewBackup),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showRecoveryPhraseDialog(context, ref);
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.fingerprint, color: colorScheme.primary),
                  title: Text(l10n.settingsBiometric),
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
          _SectionHeader(title: l10n.settingsAbout),
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
                  title: Text(l10n.settingsWebWallet),
                  subtitle: Text(l10n.settingsVersion),
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
          _SectionHeader(title: l10n.settingsDangerZone),
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
                l10n.settingsDeleteWallet,
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('繁體中文'),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Alchemy API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Alchemy API key to fetch NFT data.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get a free key at alchemy.com',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'paste your key here',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  ref.read(nftProvider.notifier).setApiKey(key);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API key saved!')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: Currency.values.map((currency) {
              return ListTile(
                title: Text('${currency.code} (${currency.symbol})'),
                onTap: () {
                  ref.read(currencyNotifierProvider.notifier).setCurrency(currency);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showRecoveryPhraseDialog(BuildContext context, WidgetRef ref) {
    // Mock Authentication
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Check'),
        content: const Text('Please authenticate to view protection phrase.\n(Mock: Click Authenticate)'),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close auth dialog
              
              final mnemonic = ref.read(walletProvider).mnemonic;
              
              if (mnemonic == null || mnemonic.isEmpty) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('No wallet loaded')),
                   );
                 }
                 return;
              }
              
              if (context.mounted) {
                _showMnemonicDisplay(context, mnemonic);
              }
            },
            child: const Text('Authenticate'),
          ),
        ],
      ),
    );
  }

  void _showSwapApiKeyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('1inch API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your 1inch API key for swaps.'),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  ref.read(swapProvider.notifier).setApiKey(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showMnemonicDisplay(BuildContext context, List<String> mnemonic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: controller,
            children: [
               Text(
                 'Recovery Phrase',
                 style: Theme.of(context).textTheme.headlineSmall,
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 8),
               const Text(
                 'Write down these 12/24 words inside a safe place. Do not share them with anyone.',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.red),
               ),
               const SizedBox(height: 24),
               Wrap(
                 spacing: 12,
                 runSpacing: 12,
                 children: List.generate(mnemonic.length, (index) {
                   return Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.surfaceContainerHighest,
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           '${index + 1}.',
                           style: TextStyle(
                             color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                             fontSize: 12,
                           ),
                         ),
                         const SizedBox(width: 4),
                         Text(
                           mnemonic[index],
                           style: const TextStyle(fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                   );
                 }),
               ),
               const SizedBox(height: 32),
               FilledButton.icon(
                 onPressed: () => Navigator.pop(context),
                 icon: const Icon(Icons.check),
                 label: const Text('I have backed it up'),
               ),
            ],
          ),
        ),
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
