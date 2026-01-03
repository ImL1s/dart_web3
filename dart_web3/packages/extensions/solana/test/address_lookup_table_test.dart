
import 'dart:typed_data';
import 'package:dart_web3_solana/src/models/public_key.dart';
import 'package:dart_web3_solana/src/programs/address_lookup_table.dart';
import 'package:test/test.dart';

void main() {
  group('AddressLookupTableProgram', () {
    test('Program ID is correct', () {
      expect(AddressLookupTableProgram.programId.toBase58(), 'AddressLookupTab1e1111111111111111111111111');
    });

    test('findLookupTableAddress derivation', () async {
      // Use arbitrary authority and slot
      final authority = PublicKey(Uint8List(32)); // All zeros
      final recentSlot = 123456789;
      
      final result = await AddressLookupTableProgram.findLookupTableAddress(authority, recentSlot);
      
      expect(result['address'], isA<PublicKey>());
      expect(result['bump'], isA<int>());
      
      final address = result['address'] as PublicKey;
      print('Derived Address: $address');
    });

    // TODO: Verify against official solana-web3.js vector if available
  });
}
