import 'package:test/test.dart';
import 'package:dart_web3_nft/dart_web3_nft.dart';
import 'package:dart_web3_core/dart_web3_core.dart';

void main() {
  group('NFT Service Tests', () {
    test('should create NFT metadata from JSON', () {
      final json = {
        'name': 'Test NFT',
        'description': 'A test NFT',
        'image': 'ipfs://QmTest123',
        'attributes': [
          {'trait_type': 'Color', 'value': 'Blue'},
          {'trait_type': 'Rarity', 'value': 'Common'},
        ],
      };

      final metadata = NftMetadata.fromJson(json);

      expect(metadata.name, equals('Test NFT'));
      expect(metadata.description, equals('A test NFT'));
      expect(metadata.image, equals('ipfs://QmTest123'));
      expect(metadata.attributes.length, equals(2));
      expect(metadata.attributes[0].traitType, equals('Color'));
      expect(metadata.attributes[0].value, equals('Blue'));
    });

    test('should create NFT token with required fields', () {
      final contractAddress = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final tokenId = BigInt.from(1);

      final token = NftToken(
        contractAddress: contractAddress,
        tokenId: tokenId,
        standard: NftStandard.erc721,
      );

      expect(token.contractAddress, equals(contractAddress));
      expect(token.tokenId, equals(tokenId));
      expect(token.standard, equals(NftStandard.erc721));
    });

    test('should create NFT collection with basic info', () {
      final contractAddress = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');

      final collection = NftCollection(
        contractAddress: contractAddress,
        name: 'Test Collection',
        symbol: 'TEST',
        standard: NftStandard.erc721,
      );

      expect(collection.contractAddress, equals(contractAddress));
      expect(collection.name, equals('Test Collection'));
      expect(collection.symbol, equals('TEST'));
      expect(collection.standard, equals(NftStandard.erc721));
    });

    test('should create NFT transfer parameters', () {
      final from = EthereumAddress.fromHex('0x1111111111111111111111111111111111111111');
      final to = EthereumAddress.fromHex('0x2222222222222222222222222222222222222222');
      final contractAddress = EthereumAddress.fromHex('0x3333333333333333333333333333333333333333');
      final tokenId = BigInt.from(123);

      final params = NftTransferParams(
        from: from,
        to: to,
        contractAddress: contractAddress,
        tokenId: tokenId,
        standard: NftStandard.erc721,
      );

      expect(params.from, equals(from));
      expect(params.to, equals(to));
      expect(params.contractAddress, equals(contractAddress));
      expect(params.tokenId, equals(tokenId));
      expect(params.standard, equals(NftStandard.erc721));
      expect(params.requireApproval, isTrue);
    });

    test('should create NFT query parameters', () {
      final owner = EthereumAddress.fromHex('0x1111111111111111111111111111111111111111');

      final params = NftQueryParams(
        owner: owner,
        limit: 50,
        includeMetadata: true,
      );

      expect(params.owner, equals(owner));
      expect(params.limit, equals(50));
      expect(params.includeMetadata, isTrue);
    });

    test('should handle NFT attribute creation', () {
      final attribute = NftAttribute(
        traitType: 'Background',
        value: 'Red',
        displayType: 'string',
      );

      expect(attribute.traitType, equals('Background'));
      expect(attribute.value, equals('Red'));
      expect(attribute.displayType, equals('string'));
    });

    test('should convert NFT metadata to JSON', () {
      final metadata = NftMetadata(
        name: 'Test NFT',
        description: 'A test NFT',
        image: 'https://example.com/image.png',
        attributes: [
          NftAttribute(traitType: 'Color', value: 'Blue'),
        ],
      );

      final json = metadata.toJson();

      expect(json['name'], equals('Test NFT'));
      expect(json['description'], equals('A test NFT'));
      expect(json['image'], equals('https://example.com/image.png'));
      expect(json['attributes'], isA<List>());
      expect((json['attributes'] as List).length, equals(1));
    });

    test('should handle NFT query result', () {
      final tokens = [
        NftToken(
          contractAddress: EthereumAddress.fromHex('0x1234567890123456789012345678901234567890'),
          tokenId: BigInt.from(1),
          standard: NftStandard.erc721,
        ),
      ];

      final result = NftQueryResult(
        tokens: tokens,
        totalCount: 1,
        hasMore: false,
      );

      expect(result.tokens.length, equals(1));
      expect(result.totalCount, equals(1));
      expect(result.hasMore, isFalse);
    });
  });

  group('IPFS Gateway Tests', () {
    test('should identify IPFS URIs correctly', () {
      final gateway = IpfsGateway();

      // Test resolveUri with non-IPFS URI (should return as-is)
      expect(gateway.resolveUri('https://example.com/image.png'), 
             completion(equals('https://example.com/image.png')));
    });

    test('should handle gateway management', () {
      final gateway = IpfsGateway();
      final initialCount = gateway.gateways.length;

      gateway.addGateway('https://custom-gateway.com/ipfs/');
      expect(gateway.gateways.length, equals(initialCount + 1));
      expect(gateway.gateways.contains('https://custom-gateway.com/ipfs/'), isTrue);

      gateway.removeGateway('https://custom-gateway.com/ipfs/');
      expect(gateway.gateways.length, equals(initialCount));
      expect(gateway.gateways.contains('https://custom-gateway.com/ipfs/'), isFalse);
    });

    test('should manage cache', () {
      final gateway = IpfsGateway();
      expect(gateway.cacheSize, equals(0));

      gateway.clearCache();
      expect(gateway.cacheSize, equals(0));
    });
  });
}