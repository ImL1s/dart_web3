import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Swap screen - token swaps using DEX aggregation
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  final _fromAmountController = TextEditingController();
  String _fromToken = 'ETH';
  String _toToken = 'USDC';
  bool _isLoading = false;

  final _tokens = ['ETH', 'USDC', 'USDT', 'DAI', 'WBTC', 'LINK'];

  @override
  void dispose() {
    _fromAmountController.dispose();
    super.dispose();
  }

  void _swapTokens() {
    setState(() {
      final temp = _fromToken;
      _fromToken = _toToken;
      _toToken = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // From token
              _TokenInputCard(
                label: 'From',
                token: _fromToken,
                tokens: _tokens,
                controller: _fromAmountController,
                balance: '0.00',
                onTokenChanged: (token) {
                  setState(() => _fromToken = token);
                },
              ),

              // Swap button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: IconButton.filled(
                  onPressed: _swapTokens,
                  icon: const Icon(Icons.swap_vert_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

              // To token
              _TokenInputCard(
                label: 'To',
                token: _toToken,
                tokens: _tokens,
                balance: '0.00',
                readOnly: true,
                estimatedAmount: '0.00',
                onTokenChanged: (token) {
                  setState(() => _toToken = token);
                },
              ),

              const SizedBox(height: 24),

              // Swap details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Rate',
                      value: '1 $_fromToken = 0.00 $_toToken',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Slippage',
                      value: '0.5%',
                      trailing: TextButton(
                        onPressed: () {
                          // TODO: Slippage settings
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                    const Divider(height: 24),
                    const _DetailRow(
                      label: 'Network Fee',
                      value: '~\$0.00',
                    ),
                    const Divider(height: 24),
                    const _DetailRow(
                      label: 'Route',
                      value: '1inch',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info about dart_web3 swap
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Powered by web3_universal_swap with 1inch, Paraswap aggregation',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Swap button
              FilledButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _isLoading = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Swap feature coming soon!'),
                              ),
                            );
                          }
                        });
                      },
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Swap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenInputCard extends StatelessWidget {
  final String label;
  final String token;
  final List<String> tokens;
  final TextEditingController? controller;
  final String balance;
  final bool readOnly;
  final String? estimatedAmount;
  final ValueChanged<String> onTokenChanged;

  const _TokenInputCard({
    required this.label,
    required this.token,
    required this.tokens,
    this.controller,
    required this.balance,
    this.readOnly = false,
    this.estimatedAmount,
    required this.onTokenChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Balance: $balance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: readOnly
                    ? Text(
                        estimatedAmount ?? '0.00',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              PopupMenuButton<String>(
                initialValue: token,
                onSelected: onTokenChanged,
                itemBuilder: (context) => tokens
                    .map(
                      (t) => PopupMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        token,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
