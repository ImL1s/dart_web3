
import 'dart:typed_data';

import '../models/instruction.dart';
import '../models/public_key.dart';
import 'system.dart'; // For SystemProgram

class AddressLookupTableProgram {
  static final programId = PublicKey.fromString('AddressLookupTab1e1111111111111111111111111');

  /// Creates a [createLookupTable] instruction.
  static TransactionInstruction createLookupTable({
    required PublicKey authority,
    required PublicKey payer,
    required PublicKey lookupTableAddress,
    required int recentSlot,
  }) {
    final buffer = BytesBuilder();
    // Instruction Index: 0 (u32)
    buffer.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0, Endian.little));
    // Recent Slot: u64
    final slotBytes = Uint8List(8);
    _setInt64(slotBytes, recentSlot);
    buffer.add(slotBytes);
    // Bump: u8 (we assume 255 or similar if not provided, but usually we just need the slot)
    buffer.addByte(255); 

    return TransactionInstruction(
        programId: programId,
        keys: [
            AccountMeta(publicKey: lookupTableAddress, isSigner: false, isWritable: true),
            AccountMeta(publicKey: authority, isSigner: true, isWritable: false), 
            AccountMeta(publicKey: payer, isSigner: true, isWritable: true),
            AccountMeta(publicKey: SystemProgram.programId, isSigner: false, isWritable: false), 
        ],
        data: buffer.toBytes(),
    );
  }
  
  /// Helper to derive lookup table address.
  static Future<Map<String, dynamic>> findLookupTableAddress(
      PublicKey authority, int recentSlot,) async {
      final slotBytes = Uint8List(8);
      _setInt64(slotBytes, recentSlot);
      
      final seeds = [authority.bytes, slotBytes];
      final pda = PublicKey.findProgramAddress(seeds, programId);
      
      return {
          'address': pda.address,
          'bump': pda.nonce,
      };
  }

  static void _setInt64(Uint8List bytes, int value) {
      var v = BigInt.from(value);
      for (var i = 0; i < 8; i++) {
        bytes[i] = (v & BigInt.from(0xff)).toInt();
        v >>= 8;
      }
  }

  /// Extend lookup table
  static TransactionInstruction extendLookupTable({
      required PublicKey lookupTable,
      required PublicKey authority,
      required PublicKey payer, 
      required List<PublicKey> newAddresses,
  }) {
      final buffer = BytesBuilder();
      // Instruction Index: 2 (u32)
      buffer.add(Uint8List(4)..buffer.asByteData().setUint32(0, 2, Endian.little));
      // Address Count: u64
      final countBytes = Uint8List(8);
      _setInt64(countBytes, newAddresses.length);
      buffer.add(countBytes);
      // Addresses
      for (final addr in newAddresses) {
          buffer.add(addr.bytes);
      }
      
      return TransactionInstruction(
          programId: programId,
          keys: [
              AccountMeta(publicKey: lookupTable, isSigner: false, isWritable: true),
              AccountMeta(publicKey: authority, isSigner: true, isWritable: false),
              AccountMeta(publicKey: payer, isSigner: true, isWritable: true),
              AccountMeta(publicKey: SystemProgram.programId, isSigner: false, isWritable: false),
          ],
          data: buffer.toBytes(),
      );
  }
}
