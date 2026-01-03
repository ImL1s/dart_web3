
import 'dart:typed_data';
import '../models/public_key.dart';

class MetaplexMetadata {
  MetaplexMetadata({
    required this.updateAuthority,
    required this.mint,
    required this.name,
    required this.symbol,
    required this.uri,
    required this.sellerFeeBasisPoints,
    this.creators,
  });

  final PublicKey updateAuthority;
  final PublicKey mint;
  final String name;
  final String symbol;
  final String uri;
  final int sellerFeeBasisPoints;
  final List<MetaplexCreator>? creators;

  static final programId = PublicKey.fromString('metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s');

  /// Derives the Metadata PDA.
  static Future<PublicKey> findMetadataAddress(PublicKey mint) async {
    final seeds = [
      Uint8List.fromList('metadata'.codeUnits),
      programId.bytes,
      mint.bytes,
    ];
    final pda = PublicKey.findProgramAddress(seeds, programId);
    return pda.address;
  }

  /// Decodes Metaplex Metadata Account data.
  static MetaplexMetadata decode(Uint8List data) {
    if (data.isEmpty) throw Exception('Empty data');
    
    final buffer = ByteData.sublistView(data);
    var offset = 0;
    
    // Key (u8) = 4
    final key = buffer.getUint8(offset);
    offset += 1;
    if (key != 4) {
        // Warning: This ignores padding or other enum variants, strict check usually requires 4
        // throw Exception('Invalid Metadata Key: $key');
    }

    // Update Authority (32 bytes)
    final updateAuthority = PublicKey(data.sublist(offset, offset + 32));
    offset += 32;

    // Mint (32 bytes)
    final mint = PublicKey(data.sublist(offset, offset + 32));
    offset += 32;

    // Name (String)
    final nameRes = _readBorshString(data, offset);
    final name = nameRes.value.replaceAll(RegExp(r'\u0000'), ''); // Strip null padding
    offset = nameRes.nextOffset;

    // Symbol (String)
    final symbolRes = _readBorshString(data, offset);
    final symbol = symbolRes.value.replaceAll(RegExp(r'\u0000'), '');
    offset = symbolRes.nextOffset;

    // URI (String)
    final uriRes = _readBorshString(data, offset);
    final uri = uriRes.value.replaceAll(RegExp(r'\u0000'), '');
    offset = uriRes.nextOffset;

    // Seller Fee Basis Points (u16)
    final sellerFeeBasisPoints = buffer.getUint16(offset, Endian.little);
    offset += 2;

    // Creators (Option<Vec<Creator>>)
    final creators = <MetaplexCreator>[];
    if (offset < data.length) {
      final hasCreators = data[offset] == 1;
      offset += 1;
      if (hasCreators && offset < data.length) {
          final creatorCount = buffer.getUint32(offset, Endian.little);
          offset += 4;
          for (var i = 0; i < creatorCount; i++) {
              final address = PublicKey(data.sublist(offset, offset + 32));
              offset += 32;
              final verified = data[offset] == 1;
              offset += 1;
              final share = data[offset];
              offset += 1;
              creators.add(MetaplexCreator(address: address, verified: verified, share: share));
          }
      }
    }

    return MetaplexMetadata(
      updateAuthority: updateAuthority,
      mint: mint,
      name: name,
      symbol: symbol,
      uri: uri,
      sellerFeeBasisPoints: sellerFeeBasisPoints,
      creators: creators.isEmpty ? null : creators,
    );
  }

  static _BorshStringResult _readBorshString(Uint8List data, int offset) {
    final len = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
    final end = offset + 4 + len;
    
    final strBytes = data.sublist(offset + 4, end);
    final str = String.fromCharCodes(strBytes); // Usually UTF-8
    
    return _BorshStringResult(str, end);
  }
}

class MetaplexCreator {
    MetaplexCreator({
        required this.address,
        required this.verified,
        required this.share,
    });
    final PublicKey address;
    final bool verified;
    final int share;
}

class _BorshStringResult {
    _BorshStringResult(this.value, this.nextOffset);
    final String value;
    final int nextOffset;
}
