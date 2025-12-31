import 'package:dart_web3_core/dart_web3_core.dart';

/// NFT token standard types
enum NftStandard {
  erc721,
  erc1155,
  metaplex, // Solana
}

/// NFT token information
class NftToken {
  final EthereumAddress contractAddress;
  final BigInt tokenId;
  final NftStandard standard;
  final String? name;
  final String? symbol;
  final String? tokenUri;
  final NftMetadata? metadata;
  final BigInt? balance; // For ERC-1155
  final EthereumAddress? owner;

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
  final String? name;
  final String? description;
  final String? image;
  final String? externalUrl;
  final String? animationUrl;
  final String? youtubeUrl;
  final String? backgroundColor;
  final List<NftAttribute> attributes;
  final Map<String, dynamic> rawMetadata;

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
      for (final attr in json['attributes']) {
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
  final String? traitType;
  final dynamic value;
  final String? displayType;
  final int? maxValue;

  const NftAttribute({
    this.traitType,
    required this.value,
    this.displayType,
    this.maxValue,
  });

  factory NftAttribute.fromJson(Map<String, dynamic> json) {
    return NftAttribute(
      traitType: json['trait_type']?.toString(),
      value: json['value'],
      displayType: json['display_type']?.toString(),
      maxValue: json['max_value'] is int ? json['max_value'] : null,
    );
  }

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

  const NftCollection({
    required this.contractAddress,
    this.name,
    this.symbol,
    required this.standard,
    this.description,
    this.image,
    this.externalUrl,
    this.totalSupply,
    this.tokens = const [],
    this.metadata = const {},
  });

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
  final EthereumAddress from;
  final EthereumAddress to;
  final EthereumAddress contractAddress;
  final BigInt tokenId;
  final BigInt? amount; // For ERC-1155
  final NftStandard standard;
  final bool requireApproval;

  const NftTransferParams({
    required this.from,
    required this.to,
    required this.contractAddress,
    required this.tokenId,
    this.amount,
    required this.standard,
    this.requireApproval = true,
  });

  @override
  String toString() {
    return 'NftTransferParams(from: $from, to: $to, contract: $contractAddress, tokenId: $tokenId)';
  }
}

/// NFT query parameters for fetching collections
class NftQueryParams {
  final EthereumAddress owner;
  final List<EthereumAddress>? contractAddresses;
  final List<NftStandard>? standards;
  final int? limit;
  final String? cursor;
  final bool includeMetadata;
  final bool includeAttributes;

  const NftQueryParams({
    required this.owner,
    this.contractAddresses,
    this.standards,
    this.limit,
    this.cursor,
    this.includeMetadata = true,
    this.includeAttributes = true,
  });

  @override
  String toString() {
    return 'NftQueryParams(owner: $owner, limit: $limit, includeMetadata: $includeMetadata)';
  }
}

/// NFT query result with pagination
class NftQueryResult {
  final List<NftToken> tokens;
  final String? nextCursor;
  final int totalCount;
  final bool hasMore;

  const NftQueryResult({
    required this.tokens,
    this.nextCursor,
    required this.totalCount,
    required this.hasMore,
  });

  @override
  String toString() {
    return 'NftQueryResult(tokens: ${tokens.length}, hasMore: $hasMore)';
  }
}