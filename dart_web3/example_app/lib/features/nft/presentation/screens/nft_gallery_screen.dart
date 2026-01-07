import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/models/nft_item.dart';
import '../../../../shared/providers/nft_provider.dart';

/// NFT Gallery Screen - Display user's NFTs from Alchemy API.
class NftGalleryScreen extends ConsumerStatefulWidget {
  const NftGalleryScreen({super.key});

  @override
  ConsumerState<NftGalleryScreen> createState() => _NftGalleryScreenState();
}

class _NftGalleryScreenState extends ConsumerState<NftGalleryScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch NFTs on screen load
    Future.microtask(() {
      ref.read(nftProvider.notifier).fetchNfts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final nftState = ref.watch(nftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nftGallery),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: nftState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: nftState.isLoading
                ? null
                : () => ref.read(nftProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.tertiaryContainer,
                  colorScheme.primaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Powered by Alchemy NFT API\nSupports ERC-721 & ERC-1155',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(nftState, theme, colorScheme, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    NftState nftState,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    // Not configured
    if (!nftState.isConfigured) {
      return _buildNotConfiguredState(theme, colorScheme);
    }

    // Loading
    if (nftState.isLoading && nftState.nfts.isEmpty) {
      return _buildShimmerGrid();
    }

    // Error
    if (nftState.error != null && nftState.nfts.isEmpty) {
      return _buildErrorState(nftState.error!, theme, colorScheme, l10n);
    }

    // Empty
    if (nftState.nfts.isEmpty) {
      return _buildEmptyState(theme, colorScheme, l10n);
    }

    // NFT Grid
    return RefreshIndicator(
      onRefresh: () => ref.read(nftProvider.notifier).refresh(),
      child: _buildNftGrid(nftState.nfts),
    );
  }

  Widget _buildNotConfiguredState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.key_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'API Key Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your Alchemy API key in Settings to view NFTs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String error,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.nftLoadError,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(nftProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_rounded,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noNftsFound,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your NFTs will appear here once you own some.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(child: Container(color: Colors.white)),
                Container(height: 60, color: Colors.white),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNftGrid(List<NftItem> nfts) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        final nft = nfts[index];
        return Hero(
          tag: 'nft-${nft.contractAddress}-${nft.tokenId}',
          child: _NftCard(nft: nft),
        );
      },
    );
  }
}

class _NftCard extends StatelessWidget {
  final NftItem nft;

  const _NftCard({required this.nft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NFT image
          Expanded(
            child: Container(
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: nft.imageUrl != null
                  ? Image.network(
                      nft.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.image_rounded,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                    ),
            ),
          ),
          // NFT info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  nft.collectionName ?? 'Unknown Collection',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
