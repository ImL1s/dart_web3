import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

import 'nft_metadata.dart';
import 'nft_types.dart';

/// NFT collection manager for querying and managing NFT collections
class NftCollectionManager {
  NftCollectionManager({
    required PublicClient client,
    NftMetadataParser? metadataParser,
  })  : _client = client,
        _metadataParser = metadataParser ?? NftMetadataParser();
  final PublicClient _client;
  final NftMetadataParser _metadataParser;
  final Map<EthereumAddress, NftCollection> _collectionCache = {};

  /// Get NFT collection information
  Future<NftCollection?> getCollection(
    EthereumAddress contractAddress, {
    bool includeTokens = false,
    int? tokenLimit,
  }) async {
    // Check cache first
    if (_collectionCache.containsKey(contractAddress)) {
      final cached = _collectionCache[contractAddress]!;
      if (!includeTokens || cached.tokens.isNotEmpty) {
        return cached;
      }
    }

    try {
      // Detect NFT standard
      final standard = await _detectNftStandard(contractAddress);
      if (standard == null) return null;

      // Get basic collection info
      final name = await _getCollectionName(contractAddress, standard);
      final symbol = await _getCollectionSymbol(contractAddress, standard);
      final totalSupply = await _getTotalSupply(contractAddress, standard);

      var collection = NftCollection(
        contractAddress: contractAddress,
        name: name,
        symbol: symbol,
        standard: standard,
        totalSupply: totalSupply,
      );

      // Get tokens if requested
      if (includeTokens) {
        final tokens = await _getCollectionTokens(
          contractAddress,
          standard,
          limit: tokenLimit,
        );
        collection = collection.copyWith(tokens: tokens);
      }

      // Cache the collection
      _collectionCache[contractAddress] = collection;
      return collection;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get NFTs owned by an address
  Future<List<NftToken>> getOwnedNfts(
    EthereumAddress owner, {
    List<EthereumAddress>? contractAddresses,
    List<NftStandard>? standards,
    int? limit,
    bool includeMetadata = true,
  }) async {
    final tokens = <NftToken>[];

    // If specific contracts provided, query them
    if (contractAddresses != null) {
      for (final contract in contractAddresses) {
        final collection = await getCollection(contract);
        if (collection != null) {
          final ownedTokens = await _getOwnedTokensFromContract(
            owner,
            contract,
            collection.standard,
            limit: limit,
            includeMetadata: includeMetadata,
          );
          tokens.addAll(ownedTokens);
        }
      }
    } else {
      // This would typically require an indexing service like Moralis, Alchemy, etc.
      // For now, we'll return empty list as we can't enumerate all NFTs on-chain
      // In a real implementation, you'd integrate with NFT indexing APIs
    }

    return tokens;
  }

  /// Get specific NFT token
  Future<NftToken?> getToken(
    EthereumAddress contractAddress,
    BigInt tokenId, {
    bool includeMetadata = true,
  }) async {
    try {
      final standard = await _detectNftStandard(contractAddress);
      if (standard == null) return null;

      // Get token URI
      final tokenUri = await _getTokenUri(contractAddress, tokenId, standard);

      // Get owner
      final owner = await _getTokenOwner(contractAddress, tokenId, standard);

      // Get balance for ERC-1155
      BigInt? balance;
      if (standard == NftStandard.erc1155 && owner != null) {
        balance = await _getTokenBalance(contractAddress, owner, tokenId);
      }

      // Parse metadata if requested
      NftMetadata? metadata;
      if (includeMetadata && tokenUri != null) {
        metadata = await _metadataParser.parseMetadataWithImages(tokenUri);
      }

      return NftToken(
        contractAddress: contractAddress,
        tokenId: tokenId,
        standard: standard,
        tokenUri: tokenUri,
        metadata: metadata,
        balance: balance,
        owner: owner,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  /// Detect NFT standard (ERC-721 or ERC-1155)
  Future<NftStandard?> _detectNftStandard(
      EthereumAddress contractAddress) async {
    try {
      // Check for ERC-165 interface support
      final contract = Contract(
        address: contractAddress.hex,
        abi: _erc165AbiJson,
        publicClient: _client,
      );

      // ERC-721 interface ID: 0x80ac58cd
      final isErc721 = await contract.read('supportsInterface', [
        HexUtils.decode('0x80ac58cd'),
      ]) as bool;

      if (isErc721) return NftStandard.erc721;

      // ERC-1155 interface ID: 0xd9b67a26
      final isErc1155 = await contract.read('supportsInterface', [
        HexUtils.decode('0xd9b67a26'),
      ]) as bool;

      if (isErc1155) return NftStandard.erc1155;

      return null;
    } on Exception catch (_) {
      // Fallback: try calling ERC-721 methods
      try {
        await _getCollectionName(contractAddress, NftStandard.erc721);
        return NftStandard.erc721;
      } on Exception catch (_) {
        return null;
      }
    }
  }

  /// Get collection name
  Future<String?> _getCollectionName(
    EthereumAddress contractAddress,
    NftStandard standard,
  ) async {
    try {
      final contract = Contract(
        address: contractAddress.hex,
        abi: standard == NftStandard.erc721 ? _erc721AbiJson : _erc1155AbiJson,
        publicClient: _client,
      );

      return await contract.read('name', []) as String?;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get collection symbol
  Future<String?> _getCollectionSymbol(
    EthereumAddress contractAddress,
    NftStandard standard,
  ) async {
    try {
      final contract = Contract(
        address: contractAddress.hex,
        abi: standard == NftStandard.erc721 ? _erc721AbiJson : _erc1155AbiJson,
        publicClient: _client,
      );

      return await contract.read('symbol', []) as String?;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get total supply
  Future<BigInt?> _getTotalSupply(
    EthereumAddress contractAddress,
    NftStandard standard,
  ) async {
    try {
      final contract = Contract(
        address: contractAddress.hex,
        abi: standard == NftStandard.erc721 ? _erc721AbiJson : _erc1155AbiJson,
        publicClient: _client,
      );

      return await contract.read('totalSupply', []) as BigInt?;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get token URI
  Future<String?> _getTokenUri(
    EthereumAddress contractAddress,
    BigInt tokenId,
    NftStandard standard,
  ) async {
    try {
      final contract = Contract(
        address: contractAddress.hex,
        abi: standard == NftStandard.erc721 ? _erc721AbiJson : _erc1155AbiJson,
        publicClient: _client,
      );

      final methodName = standard == NftStandard.erc721 ? 'tokenURI' : 'uri';
      return await contract.read(methodName, [tokenId]) as String?;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get token owner
  Future<EthereumAddress?> _getTokenOwner(
    EthereumAddress contractAddress,
    BigInt tokenId,
    NftStandard standard,
  ) async {
    try {
      if (standard == NftStandard.erc721) {
        final contract = Contract(
          address: contractAddress.hex,
          abi: _erc721AbiJson,
          publicClient: _client,
        );

        final ownerHex = await contract.read('ownerOf', [tokenId]) as String;
        return EthereumAddress.fromHex(ownerHex);
      }
      // ERC-1155 doesn't have a single owner concept
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get token balance (for ERC-1155)
  Future<BigInt?> _getTokenBalance(
    EthereumAddress contractAddress,
    EthereumAddress owner,
    BigInt tokenId,
  ) async {
    try {
      final contract = Contract(
        address: contractAddress.hex,
        abi: _erc1155AbiJson,
        publicClient: _client,
      );

      return await contract.read('balanceOf', [owner.hex, tokenId]) as BigInt;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get collection tokens (limited implementation)
  Future<List<NftToken>> _getCollectionTokens(
    EthereumAddress contractAddress,
    NftStandard standard, {
    int? limit,
  }) async {
    // This is a simplified implementation
    // In practice, you'd need event logs or indexing service
    return [];
  }

  /// Get owned tokens from specific contract
  Future<List<NftToken>> _getOwnedTokensFromContract(
    EthereumAddress owner,
    EthereumAddress contractAddress,
    NftStandard standard, {
    int? limit,
    bool includeMetadata = true,
  }) async {
    // This would require event log parsing or indexing service
    // For now, return empty list
    return [];
  }

  /// Clear collection cache
  void clearCache() {
    _collectionCache.clear();
  }

  /// Get cache size
  int get cacheSize => _collectionCache.length;

  // Minimal ABI definitions for NFT contracts
  static const _erc165AbiJson = '''
[
    {
      "inputs": [
        {"internalType": "bytes4", "name": "interfaceId", "type": "bytes4"}
      ],
      "name": "supportsInterface",
      "outputs": [
        {"internalType": "bool", "name": "", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  static const _erc721AbiJson = '''
[
    {
      "inputs": [],
      "name": "name",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "symbol",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "totalSupply",
      "outputs": [
        {"internalType": "uint256", "name": "", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"}
      ],
      "name": "tokenURI",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"}
      ],
      "name": "ownerOf",
      "outputs": [
        {"internalType": "address", "name": "", "type": "address"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  static const _erc1155AbiJson = '''
[
    {
      "inputs": [],
      "name": "name",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "symbol",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "id", "type": "uint256"}
      ],
      "name": "uri",
      "outputs": [
        {"internalType": "string", "name": "", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "account", "type": "address"},
        {"internalType": "uint256", "name": "id", "type": "uint256"}
      ],
      "name": "balanceOf",
      "outputs": [
        {"internalType": "uint256", "name": "", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';
}
