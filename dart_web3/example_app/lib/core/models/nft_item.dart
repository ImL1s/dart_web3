/// NFT item data model matching Alchemy API response.
class NftItem {
  const NftItem({
    required this.contractAddress,
    required this.tokenId,
    required this.name,
    this.description,
    this.imageUrl,
    this.collectionName,
    this.tokenType,
    this.attributes,
  });

  final String contractAddress;
  final String tokenId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? collectionName;
  final String? tokenType; // ERC721, ERC1155
  final List<NftAttribute>? attributes;

  factory NftItem.fromAlchemyJson(Map<String, dynamic> json) {
    final contract = json['contract'] as Map<String, dynamic>? ?? {};
    final image = json['image'] as Map<String, dynamic>? ?? {};
    final rawMetadata = json['raw'] as Map<String, dynamic>? ?? {};
    final metadata = rawMetadata['metadata'] as Map<String, dynamic>? ?? {};

    // Parse attributes
    List<NftAttribute>? attributes;
    final rawAttributes = metadata['attributes'] as List<dynamic>?;
    if (rawAttributes != null) {
      attributes = rawAttributes
          .map((attr) => NftAttribute.fromJson(attr as Map<String, dynamic>))
          .toList();
    }

    return NftItem(
      contractAddress: contract['address'] as String? ?? '',
      tokenId: json['tokenId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed NFT',
      description: json['description'] as String?,
      imageUrl: image['cachedUrl'] as String? ?? 
                image['originalUrl'] as String? ??
                image['pngUrl'] as String?,
      collectionName: contract['name'] as String?,
      tokenType: contract['tokenType'] as String?,
      attributes: attributes,
    );
  }

  Map<String, dynamic> toJson() => {
    'contractAddress': contractAddress,
    'tokenId': tokenId,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'collectionName': collectionName,
    'tokenType': tokenType,
    'attributes': attributes?.map((a) => a.toJson()).toList(),
  };
}

/// NFT attribute (trait).
class NftAttribute {
  const NftAttribute({
    required this.traitType,
    required this.value,
  });

  final String traitType;
  final String value;

  factory NftAttribute.fromJson(Map<String, dynamic> json) {
    return NftAttribute(
      traitType: json['trait_type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'trait_type': traitType,
    'value': value,
  };
}
