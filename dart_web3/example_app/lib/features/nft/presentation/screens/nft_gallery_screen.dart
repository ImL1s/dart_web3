import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// NFT Gallery screen - display user's NFTs
class NftGalleryScreen extends ConsumerWidget {
  const NftGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Mock NFT data for demonstration
    final mockNfts = [
      const _NftItem(
        name: 'Cool Cat #1234',
        collection: 'Cool Cats',
        imageColor: Colors.blue,
      ),
      const _NftItem(
        name: 'Bored Ape #5678',
        collection: 'BAYC',
        imageColor: Colors.green,
      ),
      const _NftItem(
        name: 'Doodle #9012',
        collection: 'Doodles',
        imageColor: Colors.orange,
      ),
      const _NftItem(
        name: 'Azuki #3456',
        collection: 'Azuki',
        imageColor: Colors.red,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFT Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
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
                    'Powered by web3_universal_nft\nSupports ERC-721 & ERC-1155',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // NFT grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: mockNfts.length,
              itemBuilder: (context, index) {
                final nft = mockNfts[index];
                return _NftCard(nft: nft);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NftItem {
  final String name;
  final String collection;
  final Color imageColor;

  const _NftItem({
    required this.name,
    required this.collection,
    required this.imageColor,
  });
}

class _NftCard extends StatelessWidget {
  final _NftItem nft;

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
          // NFT image placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    nft.imageColor.withOpacity(0.3),
                    nft.imageColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_rounded,
                  size: 48,
                  color: nft.imageColor,
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
                  nft.collection,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
