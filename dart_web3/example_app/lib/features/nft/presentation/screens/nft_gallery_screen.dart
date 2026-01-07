import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

/// NFT Gallery screen - display user's NFTs
class NftGalleryScreen extends ConsumerStatefulWidget {
  const NftGalleryScreen({super.key});

  @override
  ConsumerState<NftGalleryScreen> createState() => _NftGalleryScreenState();
}

class _NftGalleryScreenState extends ConsumerState<NftGalleryScreen> {
  bool _isLoading = true;
  List<_NftItem> _nfts = [];

  @override
  void initState() {
    super.initState();
    _loadNfts();
  }

  Future<void> _loadNfts() async {
    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _nfts = [
          const _NftItem(
            id: '1',
            name: 'Cool Cat #1234',
            collection: 'Cool Cats',
            imageColor: Colors.blue,
          ),
          const _NftItem(
            id: '2',
            name: 'Bored Ape #5678',
            collection: 'BAYC',
            imageColor: Colors.green,
          ),
          const _NftItem(
            id: '3',
            name: 'Doodle #9012',
            collection: 'Doodles',
            imageColor: Colors.orange,
          ),
          const _NftItem(
            id: '4',
            name: 'Azuki #3456',
            collection: 'Azuki',
            imageColor: Colors.red,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            child: _isLoading ? _buildShimmerGrid() : _buildNftGrid(),
          ),
        ],
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

  Widget _buildNftGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _nfts.length,
      itemBuilder: (context, index) {
        final nft = _nfts[index];
        return Hero(
          tag: 'nft-${nft.id}',
          child: _NftCard(nft: nft),
        );
      },
    );
  }
}

class _NftItem {
  final String id;
  final String name;
  final String collection;
  final Color imageColor;

  const _NftItem({
    required this.id,
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
