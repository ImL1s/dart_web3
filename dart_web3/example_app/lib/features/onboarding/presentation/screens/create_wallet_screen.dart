import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/wallet_provider.dart';

/// Create wallet screen - generates and displays mnemonic with premium UI
class CreateWalletScreen extends ConsumerStatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  ConsumerState<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends ConsumerState<CreateWalletScreen> {
  List<String>? _mnemonic;
  bool _isLoading = false;
  bool _hasBackedUp = false;
  bool _isBackingUpToCloud = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _generateWallet());
  }

  Future<void> _generateWallet() async {
    setState(() => _isLoading = true);
    try {
      final mnemonic = await ref.read(walletProvider.notifier).createWallet();
      if (mounted) {
        setState(() {
          _mnemonic = mnemonic;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _simulateCloudBackup() async {
    setState(() => _isBackingUpToCloud = true);
    // Simulate encryption and upload
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isBackingUpToCloud = false;
        _hasBackedUp = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done, color: Colors.white),
              SizedBox(width: 12),
              Text('Securely backed up to Cloud'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('New Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Premium Warning Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.errorContainer, colorScheme.errorContainer.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_person_rounded, color: colorScheme.error, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Your recovery phrase is the master key to your funds. Never share it with anyone.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          'Recovery Phrase',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Mnemonic Display
                        if (_mnemonic != null) _buildMnemonicGrid(_mnemonic!, colorScheme, theme),

                        const SizedBox(height: 24),

                        // Action Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _mnemonic?.join(' ') ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isBackingUpToCloud ? null : _simulateCloudBackup,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.secondary,
                                  foregroundColor: colorScheme.onSecondary,
                                ),
                                icon: _isBackingUpToCloud 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.cloud_upload_rounded, size: 18),
                                label: const Text('Cloud Backup'),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Confirmation
                        _buildConfirmationSection(theme, colorScheme),

                        const SizedBox(height: 16),

                        FilledButton(
                          onPressed: _hasBackedUp ? () => context.go('/home') : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Go to Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicGrid(List<String> words, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: words.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${index + 1} ',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary.withOpacity(0.5)),
                    ),
                    TextSpan(
                      text: words[index],
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfirmationSection(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => setState(() => _hasBackedUp = !_hasBackedUp),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Checkbox.adaptive(
              value: _hasBackedUp,
              onChanged: (val) => setState(() => _hasBackedUp = val ?? false),
              activeColor: colorScheme.primary,
            ),
            const Expanded(
              child: Text(
                'I understand that if I lose my recovery phrase, I will lose access to my funds forever.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
