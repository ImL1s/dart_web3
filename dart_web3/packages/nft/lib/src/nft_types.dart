import 'package:web3_universal_core/web3_universal_core.dart';

/// NFT token standard types
enum NftStandard {
  erc721,
  erc1155,
  metaplex, // Solana
}

/// NFT token information
class NftToken {
  const NftToken({
    required this.contractAddress,
    required this.tokenId,
    required this.standard,
    this.name,
    this.symbol,
    this.tokenUri,
    this.metadata,
    this.balance,
    this.owner,
  });
  final EthereumAddress contractAddress;
  final BigInt tokenId;
  final NftStandard standard;
  final String? name;
  final String? symbol;
  final String? tokenUri;
  final NftMetadata? metadata;
  final BigInt? balance; // For ERC-1155
  final EthereumAddress? owner;

  NftToken copyWith({
    EthereumAddress? contractAddress,
    BigInt? tokenId,
    NftStandard? standard,
    String? name,
    String? symbol,
    String? tokenUri,
    NftMetadata? metadata,
    BigInt? balance,
    EthereumAddress? owner,
  }) {
    return NftToken(
      contractAddress: contractAddress ?? this.contractAddress,
      tokenId: tokenId ?? this.tokenId,
      standard: standard ?? this.standard,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      tokenUri: tokenUri ?? this.tokenUri,
      metadata: metadata ?? this.metadata,
      balance: balance ?? this.balance,
      owner: owner ?? this.owner,
    );
  }

  @override
  String toString() {
    return 'NftToken(contract: $contractAddress, tokenId: $tokenId, standard: $standard)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NftToken &&
        other.contractAddress == contractAddress &&
        other.tokenId == tokenId &&
        other.standard == standard;
  }

  @override
  int get hashCode {
    return Object.hash(contractAddress, tokenId, standard);
  }
}

/// NFT metadata structure following OpenSea metadata standard
class NftMetadata {
  const NftMetadata({
    this.name,
    this.description,
    this.image,
    this.externalUrl,
    this.animationUrl,
    this.youtubeUrl,
    this.backgroundColor,
    this.attributes = const [],
    this.rawMetadata = const {},
  });

  factory NftMetadata.fromJson(Map<String, dynamic> json) {
    final attributes = <NftAttribute>[];
    if (json['attributes'] is List) {
      for (final attr in json['attributes'] as List) {
        if (attr is Map<String, dynamic>) {
          attributes.add(NftAttribute.fromJson(attr));
        }
      }
    }

    return NftMetadata(
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      externalUrl: json['external_url']?.toString(),
      animationUrl: json['animation_url']?.toString(),
      youtubeUrl: json['youtube_url']?.toString(),
      backgroundColor: json['background_color']?.toString(),
      attributes: attributes,
      rawMetadata: Map<String, dynamic>.from(json),
    );
  }
  final String? name;
  final String? description;
  final String? image;
  final String? externalUrl;
  final String? animationUrl;
  final String? youtubeUrl;
  final String? backgroundColor;
  final List<NftAttribute> attributes;
  final Map<String, dynamic> rawMetadata;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (image != null) 'image': image,
      if (externalUrl != null) 'external_url': externalUrl,
      if (animationUrl != null) 'animation_url': animationUrl,
      if (youtubeUrl != null) 'youtube_url': youtubeUrl,
      if (backgroundColor != null) 'background_color': backgroundColor,
      'attributes': attributes.map((a) => a.toJson()).toList(),
      ...rawMetadata,
    };
  }

  @override
  String toString() {
    return 'NftMetadata(name: $name, image: $image)';
  }
}

/// NFT attribute/trait
class NftAttribute {
  const NftAttribute({
    required this.value,
    this.traitType,
    this.displayType,
    this.maxValue,
  });

  factory NftAttribute.fromJson(Map<String, dynamic> json) {
    return NftAttribute(
      traitType: json['trait_type']?.toString(),
      value: json['value'],
      displayType: json['display_type']?.toString(),
      maxValue: json['max_value'] is int ? json['max_value'] as int : null,
    );
  }
  final String? traitType;
  final dynamic value;
  final String? displayType;
  final int? maxValue;

  Map<String, dynamic> toJson() {
    return {
      if (traitType != null) 'trait_type': traitType,
      'value': value,
      if (displayType != null) 'display_type': displayType,
      if (maxValue != null) 'max_value': maxValue,
    };
  }

  @override
  String toString() {
    return 'NftAttribute(traitType: $traitType, value: $value)';
  }
}

/// NFT collection information
class NftCollection {
  const NftCollection({
    required this.contractAddress,
    required this.standard,
    this.name,
    this.symbol,
    this.description,
    this.image,
    this.externalUrl,
    this.totalSupply,
    this.tokens = const [],
    this.metadata = const {},
  });
  final EthereumAddress contractAddress;
  final String? name;
  final String? symbol;
  final NftStandard standard;
  final String? description;
  final String? image;
  final String? externalUrl;
  final BigInt? totalSupply;
  final List<NftToken> tokens;
  final Map<String, dynamic> metadata;

  NftCollection copyWith({
    EthereumAddress? contractAddress,
    String? name,
    String? symbol,
    NftStandard? standard,
    String? description,
    String? image,
    String? externalUrl,
    BigInt? totalSupply,
    List<NftToken>? tokens,
    Map<String, dynamic>? metadata,
  }) {
    return NftCollection(
      contractAddress: contractAddress ?? this.contractAddress,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      standard: standard ?? this.standard,
      description: description ?? this.description,
      image: image ?? this.image,
      externalUrl: externalUrl ?? this.externalUrl,
      totalSupply: totalSupply ?? this.totalSupply,
      tokens: tokens ?? this.tokens,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'NftCollection(name: $name, contract: $contractAddress, tokens: ${tokens.length})';
  }
}

/// NFT transfer parameters
class NftTransferParams {
  const NftTransferParams({
    required this.from,
    required this.to,
    required this.contractAddress,
    required this.tokenId,
    required this.standard,
    this.amount,
    this.requireApproval = true,
  });
  final EthereumAddress from;
  final EthereumAddress to;
  final EthereumAddress contractAddress;
  final BigInt tokenId;
  final BigInt? amount; // For ERC-1155
  final NftStandard standard;
  final bool requireApproval;

  @override
  String toString() {
    return 'NftTransferParams(from: $from, to: $to, contract: $contractAddress, tokenId: $tokenId)';
  }
}

/// NFT query parameters for fetching collections
class NftQueryParams {
  const NftQueryParams({
    required this.owner,
    this.contractAddresses,
    this.standards,
    this.limit,
    this.cursor,
    this.includeMetadata = true,
    this.includeAttributes = true,
  });
  final EthereumAddress owner;
  final List<EthereumAddress>? contractAddresses;
  final List<NftStandard>? standards;
  final int? limit;
  final String? cursor;
  final bool includeMetadata;
  final bool includeAttributes;

  @override
  String toString() {
    return 'NftQueryParams(owner: $owner, limit: $limit, includeMetadata: $includeMetadata)';
  }
}

/// NFT query result with pagination
class NftQueryResult {
  const NftQueryResult({
    required this.tokens,
    required this.totalCount,
    required this.hasMore,
    this.nextCursor,
  });
  final List<NftToken> tokens;
  final String? nextCursor;
  final int totalCount;
  final bool hasMore;

  @override
  String toString() {
    return 'NftQueryResult(tokens: ${tokens.length}, hasMore: $hasMore)';
  }
}
