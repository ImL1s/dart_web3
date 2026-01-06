import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/wallet_provider.dart';

/// Send screen - send transactions
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final txHash = await ref.read(walletProvider.notifier).sendTransaction(
            to: _addressController.text.trim(),
            amount: _amountController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Transaction sent! Hash: ${txHash.substring(0, 10)}...'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletState = ref.watch(walletProvider);
    final notifier = ref.read(walletProvider.notifier);
    final chain = notifier.selectedChainConfig;
    final symbol = chain.symbol;

    return Scaffold(
      appBar: AppBar(
        title: Text('Send $symbol'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // From account card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.diamond_outlined,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chain.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              walletState.selectedAccount?.address
                                      .substring(0, 12) ??
                                  '...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recipient address
                Text(
                  'Recipient',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Address',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () {
                        // TODO: QR scanner
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient address';
                    }

                    // Chain-specific validation
                    if (chain.isEvm) {
                      if (!value.startsWith('0x') || value.length != 42) {
                        return 'Invalid Ethereum address';
                      }
                    } else if (chain.type == ChainType.bitcoin) {
                      if (!value.startsWith('bc1') &&
                          !value.startsWith('1') &&
                          !value.startsWith('3')) {
                        return 'Invalid Bitcoin address';
                      }
                    } else if (chain.type == ChainType.solana) {
                      if (value.length < 32 || value.length > 44) {
                        return 'Invalid Solana address';
                      }
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Amount
                Text(
                  'Amount',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    suffixText: symbol,
                    suffixIcon: TextButton(
                      onPressed: () {
                        _amountController.text =
                            '0.00'; // TODO: Max balance logic
                      },
                      child: const Text('MAX'),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),

                const Spacer(),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _sendTransaction,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Send $symbol'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
