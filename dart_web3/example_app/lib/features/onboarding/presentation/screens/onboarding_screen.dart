import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Onboarding screen - entry point for new users
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Logo and branding
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 64,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Web3 Wallet',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Your gateway to multi-chain DeFi',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'Powered by dart_web3 SDK',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Feature highlights
              const _FeatureRow(
                icon: Icons.security_rounded,
                title: 'Secure',
                subtitle: 'Your keys, your crypto',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.hub_rounded,
                title: 'Multi-Chain',
                subtitle: 'Ethereum, Polygon, Arbitrum & more',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.swap_horiz_rounded,
                title: 'DEX Aggregation',
                subtitle: 'Best rates across exchanges',
              ),

              const Spacer(),

              // Action buttons
              FilledButton(
                onPressed: () => context.go('/create-wallet'),
                child: const Text('Create New Wallet'),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => context.go('/import-wallet'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Import Existing Wallet'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
