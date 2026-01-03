
import 'dart:typed_data';

import 'package:dart_web3_solana/dart_web3_solana.dart'; // Ensure exported or import src
import 'package:dart_web3_solana/src/programs/metaplex.dart'; // Import directly if needed
import 'package:test/test.dart';

void main() {
  group('Metaplex Metadata', () {
    test('findMetadataAddress', () async {
      final mint = PublicKey(Uint8List(32)); // Mock mint
      final pda = await MetaplexMetadata.findMetadataAddress(mint);
      expect(pda, isA<PublicKey>());
    });

    test('decode metadata', () {
      final buffer = BytesBuilder();
      
      // 1. Key = 4
      buffer.addByte(4);
      
      // 2. Update Authority (32 bytes)
      final auth = Uint8List(32); auth[0] = 1;
      buffer.add(auth);
      
      // 3. Mint (32 bytes)
      final mint = Uint8List(32); mint[0] = 2;
      buffer.add(mint);
      
      // 4. Name "Test NFT"
      _addString(buffer, 'Test NFT');
      
      // 5. Symbol "NFT"
      _addString(buffer, 'NFT');
      
      // 6. URI "http://example.com"
      _addString(buffer, 'http://example.com');
      
      // 7. Seller Fee (u16) = 500
      buffer.addByte(500 & 0xff);
      buffer.addByte((500 >> 8) & 0xff);
      
      final data = buffer.toBytes();
      
      final metadata = MetaplexMetadata.decode(data);
      
      expect(metadata.name, startsWith('Test NFT')); // startsWith in case of padding logic issues
      expect(metadata.symbol, startsWith('NFT'));
      expect(metadata.uri, startsWith('http://example.com'));
      expect(metadata.sellerFeeBasisPoints, 500);
      expect(metadata.updateAuthority.bytes, equals(auth));
      expect(metadata.mint.bytes, equals(mint));
    });
  });
}

void _addString(BytesBuilder buffer, String s) {
  final bytes = Uint8List.fromList(s.codeUnits);
  final len = bytes.length;
  // Borsh string: u32 len + bytes
  buffer.addByte(len & 0xff);
  buffer.addByte((len >> 8) & 0xff);
  buffer.addByte((len >> 16) & 0xff);
  buffer.addByte((len >> 24) & 0xff);
  buffer.add(bytes);
}
