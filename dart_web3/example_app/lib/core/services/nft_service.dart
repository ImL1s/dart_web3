import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nft_item.dart';

/// Service for fetching NFTs from Alchemy API.
class NftService {
  NftService({
    this.apiKey,
    this.chain = 'eth-mainnet',
  });

  String? apiKey;
  final String chain;

  static const _apiKeyPrefKey = 'alchemy_api_key';

  /// Load API key from storage.
  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString(_apiKeyPrefKey);
  }

  /// Save API key to storage.
  Future<void> saveApiKey(String key) async {
    apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, key);
  }

  /// Check if API key is configured.
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Get NFTs owned by an address.
  Future<List<NftItem>> getNftsForOwner(String ownerAddress) async {
    if (!isConfigured) {
      throw NftServiceException('Alchemy API key not configured');
    }

    final url = Uri.parse(
      'https://$chain.g.alchemy.com/nft/v3/$apiKey/getNFTsForOwner'
      '?owner=$ownerAddress'
      '&withMetadata=true'
      '&pageSize=50',
    );

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw NftServiceException(
          'API request failed: ${response.statusCode} - ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final ownedNfts = data['ownedNfts'] as List<dynamic>? ?? [];

      return ownedNfts
          .map((nft) => NftItem.fromAlchemyJson(nft as Map<String, dynamic>))
          .where((nft) => nft.imageUrl != null) // Filter out NFTs without images
          .toList();
    } catch (e) {
      if (e is NftServiceException) rethrow;
      throw NftServiceException('Failed to fetch NFTs: $e');
    }
  }

  /// Get metadata for a specific NFT.
  Future<NftItem?> getNftMetadata({
    required String contractAddress,
    required String tokenId,
  }) async {
    if (!isConfigured) {
      throw NftServiceException('Alchemy API key not configured');
    }

    final url = Uri.parse(
      'https://$chain.g.alchemy.com/nft/v3/$apiKey/getNFTMetadata'
      '?contractAddress=$contractAddress'
      '&tokenId=$tokenId',
    );

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return NftItem.fromAlchemyJson(data);
    } catch (e) {
      return null;
    }
  }
}

/// Exception thrown by NftService.
class NftServiceException implements Exception {
  NftServiceException(this.message);
  final String message;

  @override
  String toString() => 'NftServiceException: $message';
}
