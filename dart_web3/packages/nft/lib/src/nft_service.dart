import 'dart:async';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'nft_types.dart';
import 'nft_metadata.dart';
import 'nft_collection.dart';
import 'nft_transfer.dart';
import 'ipfs_gateway.dart';

/// Main NFT service providing comprehensive NFT functionality
class NftService {
  final PublicClient _publicClient;
  final WalletClient? _walletClient;
  final NftMetadataParser _metadataParser;
  final NftCollectionManager _collectionManager;
  final NftTransferManager? _transferManager;
  final IpfsGateway _ipfsGateway;

  NftService({
    required PublicClient publicClient,
    WalletClient? walletClient,
    IpfsGateway? ipfsGateway,
    NftMetadataParser? metadataParser,
  })  : _publicClient = publicClient,
        _walletClient = walletClient,
        _ipfsGateway = ipfsGateway ?? IpfsGateway(),
        _metadataParser = metadataParser ?? NftMetadataParser(ipfsGateway: ipfsGateway),
        _collectionManager = NftCollectionManager(
          client: publicClient,
          metadataParser: metadataParser ?? NftMetadataParser(ipfsGateway: ipfsGateway),
        ),
        _transferManager = walletClient != null
            ? NftTransferManager(client: walletClient)
            : null;

  /// Get NFT collections owned by an address
  Future<List<NftCollection>> getCollections(
    EthereumAddress owner, {
    List<EthereumAddress>? contractAddresses,
    List<NftStandard>? standards,
    int? limit,
    bool includeMetadata = true,
  }) async {
    final collections = <NftCollection>[];

    if (contractAddresses != null) {
      for (final contractAddress in contractAddresses) {
        final collection = await _collectionManager.getCollection(
          contractAddress,
          includeTokens: true,
        );
        if (collection != null) {
          // Filter by standards if specified
          if (standards == null || standards.contains(collection.standard)) {
            collections.add(collection);
          }
        }
      }
    }

    return collections;
  }

  /// Get NFTs owned by an address
  Future<NftQueryResult> getNfts(NftQueryParams params) async {
    final tokens = await _collectionManager.getOwnedNfts(
      params.owner,
      contractAddresses: params.contractAddresses,
      standards: params.standards,
      limit: params.limit,
      includeMetadata: params.includeMetadata,
    );

    return NftQueryResult(
      tokens: tokens,
      totalCount: tokens.length,
      hasMore: false, // Would be determined by actual pagination
      nextCursor: null,
    );
  }

  /// Get specific NFT token
  Future<NftToken?> getNft(
    EthereumAddress contractAddress,
    BigInt tokenId, {
    bool includeMetadata = true,
  }) async {
    return await _collectionManager.getToken(
      contractAddress,
      tokenId,
      includeMetadata: includeMetadata,
    );
  }

  /// Get NFT collection information
  Future<NftCollection?> getCollection(
    EthereumAddress contractAddress, {
    bool includeTokens = false,
    int? tokenLimit,
  }) async {
    return await _collectionManager.getCollection(
      contractAddress,
      includeTokens: includeTokens,
      tokenLimit: tokenLimit,
    );
  }

  /// Parse NFT metadata from URI
  Future<NftMetadata?> parseMetadata(String? tokenUri) async {
    return await _metadataParser.parseMetadataWithImages(tokenUri);
  }

  /// Resolve IPFS URI to accessible URL
  Future<String?> resolveIpfsUri(String uri) async {
    return await _ipfsGateway.resolveUri(uri);
  }

  /// Transfer NFT (requires wallet client)
  Future<String> transferNft(NftTransferParams params) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for NFT transfers');
    }
    return await _transferManager!.transferNft(params);
  }

  /// Check if approval is needed for NFT transfer
  Future<bool> needsApproval(NftTransferParams params) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for approval checks');
    }
    return await _transferManager!.needsApproval(params);
  }

  /// Approve NFT for transfer
  Future<String> approveNft(NftTransferParams params) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for NFT approvals');
    }
    return await _transferManager!.approveNft(params);
  }

  /// Get approval status for NFT
  Future<bool> isApproved(NftTransferParams params) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for approval status');
    }
    return await _transferManager!.isApproved(params);
  }

  /// Estimate gas for NFT transfer
  Future<BigInt> estimateTransferGas(NftTransferParams params) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for gas estimation');
    }
    return await _transferManager!.estimateTransferGas(params);
  }

  /// Batch transfer multiple NFTs
  Future<List<String>> batchTransferNfts(List<NftTransferParams> transfers) async {
    if (_transferManager == null) {
      throw Exception('Wallet client required for NFT transfers');
    }
    return await _transferManager!.batchTransferNfts(transfers);
  }

  /// Search NFTs by metadata attributes
  Future<List<NftToken>> searchNfts({
    required EthereumAddress contractAddress,
    Map<String, dynamic>? attributes,
    String? nameQuery,
    int? limit,
  }) async {
    // This would typically require an indexing service
    // For now, return empty list as on-chain search is not practical
    return [];
  }

  /// Get NFT floor price (requires external price API)
  Future<double?> getFloorPrice(EthereumAddress contractAddress) async {
    // This would integrate with NFT marketplace APIs like OpenSea
    // For now, return null as it requires external services
    return null;
  }

  /// Get NFT trading history (requires external indexing)
  Future<List<Map<String, dynamic>>> getTradingHistory(
    EthereumAddress contractAddress,
    BigInt tokenId,
  ) async {
    // This would integrate with NFT marketplace APIs
    // For now, return empty list as it requires external services
    return [];
  }

  /// Refresh NFT metadata cache
  Future<void> refreshMetadata(
    EthereumAddress contractAddress,
    BigInt tokenId,
  ) async {
    // Clear cached metadata and re-fetch
    _metadataParser.clearCache();
    await getNft(contractAddress, tokenId, includeMetadata: true);
  }

  /// Add custom IPFS gateway
  void addIpfsGateway(String gateway) {
    _ipfsGateway.addGateway(gateway);
  }

  /// Remove IPFS gateway
  void removeIpfsGateway(String gateway) {
    _ipfsGateway.removeGateway(gateway);
  }

  /// Get available IPFS gateways
  List<String> get ipfsGateways => _ipfsGateway.gateways;

  /// Clear all caches
  void clearCache() {
    _metadataParser.clearCache();
    _collectionManager.clearCache();
    _ipfsGateway.clearCache();
  }

  /// Get cache statistics
  Map<String, int> get cacheStats => {
        'metadata': _metadataParser.cacheSize,
        'collections': _collectionManager.cacheSize,
        'ipfs': _ipfsGateway.cacheSize,
      };

  /// Check if wallet client is available
  bool get hasWalletClient => _walletClient != null;

  /// Get public client
  PublicClient get publicClient => _publicClient;

  /// Get wallet client
  WalletClient? get walletClient => _walletClient;

  /// Get metadata parser
  NftMetadataParser get metadataParser => _metadataParser;

  /// Get collection manager
  NftCollectionManager get collectionManager => _collectionManager;

  /// Get transfer manager
  NftTransferManager? get transferManager => _transferManager;

  /// Get IPFS gateway
  IpfsGateway get ipfsGateway => _ipfsGateway;
}