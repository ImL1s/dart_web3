import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

import '../../../../shared/providers/smart_wallet_provider.dart';
import '../../../../shared/providers/wallet_provider.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.smartWallet, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: colorScheme.surface.withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: smartWalletState.isLoading && smartWalletState.smartAccountAddress == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Smart Account Card with Glassmorphism
                        _SmartAccountCard(
                          address: smartWalletState.smartAccountAddress ?? 'Loading...',
                          isDeployed: smartWalletState.isDeployed,
                          eoaAddress: walletState.selectedAccount?.address ?? '',
                          colorScheme: colorScheme,
                          theme: theme,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 32),

                        // Paymaster Toggle Card
                        _PaymasterCard(
                          isEnabled: smartWalletState.paymasterEnabled,
                          onChanged: (val) => ref.read(smartWalletProvider.notifier).togglePaymaster(val),
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                        const SizedBox(height: 32),

                        // Send UserOperation UI
                        _SendUserOpForm(
                          recipientController: _recipientController,
                          amountController: _amountController,
                          isLoading: smartWalletState.isLoading,
                          currentStep: smartWalletState.currentStep,
                          onSend: _sendUserOperation,
                          colorScheme: colorScheme,
                          theme: theme,
                          l10n: l10n,
                        ),

                        // Error Display
                        if (smartWalletState.error != null) ...[
                          const SizedBox(height: 20),
                          _ErrorBanner(error: smartWalletState.error!, colorScheme: colorScheme),
                        ],

                        // Pending UserOp Hash Card
                        if (smartWalletState.pendingUserOpHash != null) ...[
                          const SizedBox(height: 24),
                          _UserOpHashCard(
                            hash: smartWalletState.pendingUserOpHash!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ],

                        const SizedBox(height: 40),
                        _InfoSection(colorScheme: colorScheme, theme: theme),
                      ],
                    ),
                  ),
          ),
        ],
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

    final amountEth = double.tryParse(amountStr) ?? 0;
    final amountWei = BigInt.from(amountEth * 1e18);

    await ref.read(smartWalletProvider.notifier).sendUserOperation(
      to: recipient,
      value: amountWei,
    );
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.tertiary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withOpacity(0.2),
                    child: Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Smart Wallet',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _StatusChip(isDeployed: isDeployed, l10n: l10n),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'CONTRACT ADDRESS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          address,
                          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 16, color: colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isDeployed;
  final AppLocalizations l10n;

  const _StatusChip({required this.isDeployed, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDeployed ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDeployed ? Colors.green : Colors.orange),
      ),
      child: Text(
        isDeployed ? 'Deployed' : l10n.accountNotDeployed,
        style: TextStyle(
          color: isDeployed ? Colors.green : Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PaymasterCard extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PaymasterCard({
    required this.isEnabled,
    required this.onChanged,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flash_on_rounded, color: colorScheme.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gas Sponsorship',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sponsored by Paymaster',
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _SendUserOpForm extends StatelessWidget {
  final TextEditingController recipientController;
  final TextEditingController amountController;
  final bool isLoading;
  final UserOpStep? currentStep;
  final VoidCallback onSend;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _SendUserOpForm({
    required this.recipientController,
    required this.amountController,
    required this.isLoading,
    this.currentStep,
    required this.onSend,
    required this.colorScheme,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Send UserOperation',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: recipientController,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'Recipient Address',
            hintText: '0x...',
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          enabled: !isLoading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (ETH)',
            hintText: '0.001',
            prefixIcon: const Icon(Icons.attach_money),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 24),
        if (isLoading)
          _ExecutionSteps(currentStep: currentStep, colorScheme: colorScheme)
        else
          FilledButton(
            onPressed: onSend,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(l10n.sendUserOp),
          ),
      ],
    );
  }
}

class _ExecutionSteps extends StatelessWidget {
  final UserOpStep? currentStep;
  final ColorScheme colorScheme;

  const _ExecutionSteps({required this.currentStep, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _StepItem(
            label: 'Building UserOperation',
            isActive: currentStep == UserOpStep.building,
            isDone: currentStep != null && currentStep!.index > UserOpStep.building.index,
            colorScheme: colorScheme,
          ),
          _StepDivider(isActive: currentStep != null && currentStep!.index > UserOpStep.building.index),
          _StepItem(
            label: 'Sponsoring Gas',
            isActive: currentStep == UserOpStep.sponsoring,
            isDone: currentStep != null && currentStep!.index > UserOpStep.sponsoring.index,
            colorScheme: colorScheme,
          ),
          _StepDivider(isActive: currentStep != null && currentStep!.index > UserOpStep.sponsoring.index),
          _StepItem(
            label: 'Signing with EOA',
            isActive: currentStep == UserOpStep.signing,
            isDone: currentStep != null && currentStep!.index > UserOpStep.signing.index,
            colorScheme: colorScheme,
          ),
          _StepDivider(isActive: currentStep != null && currentStep!.index > UserOpStep.signing.index),
          _StepItem(
            label: 'Bundling to Chain',
            isActive: currentStep == UserOpStep.bundling,
            isDone: currentStep == UserOpStep.completed,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;
  final ColorScheme colorScheme;

  const _StepItem({
    required this.label,
    required this.isActive,
    required this.isDone,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? Colors.green : (isActive ? colorScheme.primary : colorScheme.outline.withOpacity(0.2)),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : (isActive ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))) : null),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isDone ? Colors.green : (isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5)),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  final bool isActive;
  const _StepDivider({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 11),
      height: 16,
      width: 2,
      color: isActive ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final ColorScheme colorScheme;

  const _ErrorBanner({required this.error, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.errorContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(error, style: TextStyle(color: colorScheme.onErrorContainer))),
        ],
      ),
    );
  }
}

class _UserOpHashCard extends StatelessWidget {
  final String hash;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _UserOpHashCard({required this.hash, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.secondaryContainer.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRANSACTION SUBMITTED', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(hash, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _InfoSection({required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/aa_illustration.png',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Text('About ERC-4337', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            const _InfoCard(icon: Icons.flash_on, label: 'No Gas Fees', color: Colors.blue),
            const _InfoCard(icon: Icons.batch_prediction, label: 'Batches', color: Colors.purple),
            const _InfoCard(icon: Icons.security, label: 'Recovery', color: Colors.green),
            const _InfoCard(icon: Icons.code, label: 'Custom Logic', color: Colors.orange),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.2)), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
