import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:web3_wallet_app/l10n/generated/app_localizations.dart';

import '../../../../core/models/nft_item.dart';
import '../../../../shared/providers/nft_provider.dart';

class NftGalleryScreen extends ConsumerStatefulWidget {
  const NftGalleryScreen({super.key});

  @override
  ConsumerState<NftGalleryScreen> createState() => _NftGalleryScreenState();
}

class _NftGalleryScreenState extends ConsumerState<NftGalleryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(nftProvider.notifier).fetchNfts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final nftState = ref.watch(nftProvider);

    final filteredNfts = nftState.nfts.where((nft) {
      final query = _searchQuery.toLowerCase();
      return nft.name.toLowerCase().contains(query) ||
          (nft.collectionName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium AppBar
          SliverAppBar.large(
            title: Text(l10n.nftGallery, style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
            actions: [
              IconButton(
                icon: nftState.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: nftState.isLoading ? null : () => ref.read(nftProvider.notifier).refresh(),
              ),
            ],
          ),

          // Search & Info Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search collection or NFT...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            }) 
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Promo Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer.withOpacity(0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.orangeAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Powered by Alchemy NFT API\nMultichain Assets Visualized',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Grid
          if (!nftState.isConfigured)
            SliverFillRemaining(child: _buildNotConfiguredState(theme, colorScheme))
          else if (nftState.isLoading && nftState.nfts.isEmpty)
            SliverPadding(padding: const EdgeInsets.all(16), sliver: _buildShimmerGrid())
          else if (nftState.error != null && nftState.nfts.isEmpty)
            SliverFillRemaining(child: _buildErrorState(nftState.error!, theme, colorScheme, l10n))
          else if (filteredNfts.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(theme, colorScheme, l10n))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'nft-${filteredNfts[index].contractAddress}-${filteredNfts[index].tokenId}',
                    child: _NftCard(nft: filteredNfts[index]),
                  );
                },
                childCount: filteredNfts.length,
              ),
            ),
        ],
      ),
    );
  }

  // --- States ---

  Widget _buildNotConfiguredState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.8,
              child: Image.asset('assets/images/empty_nft.png', width: 200, height: 200),
            ),
            const SizedBox(height: 32),
            const Text('Alchemy API Key Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            const Text(
              'To view your NFTs, please configure your Alchemy API key in settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Configure API Key'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.nftLoadError, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextButton(onPressed: () => ref.read(nftProvider.notifier).refresh(), child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/empty_nft.png', width: 200, height: 200),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? l10n.noNftsFound : 'No NFTs match your search',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (_searchQuery.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: Text(
                'This wallet doesn\'t seem to have any digital collectibles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: index.isOdd ? 250 : 200,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
      childCount: 6,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (nft.imageUrl != null)
            Image.network(
              nft.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
            )
          else
            _buildPlaceholder(colorScheme),
          
          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nft.collectionName != null)
                  Text(
                    nft.collectionName!,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
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

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: colorScheme.outline, size: 40),
      ),
    );
  }
}
