import 'dart:typed_data';
import '../models/instruction.dart';
import '../models/public_key.dart';
import 'system.dart';

class TokenProgram {
    TokenProgram._();
    
    static final programId = PublicKey.fromString('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
    
    /// Create a Transfer instruction.
    static TransactionInstruction transfer({
        required PublicKey source,
        required PublicKey destination,
        required PublicKey owner,
        required int amount,
    }) {
        final data = ByteData(9);
        data.setUint8(0, 3); // Transfer instruction index
        data.setUint64(1, amount, Endian.little);
        
        return TransactionInstruction(
            programId: programId,
            keys: [
                AccountMeta.writable(source, isSigner: false),
                AccountMeta.writable(destination, isSigner: false),
                AccountMeta.readonly(owner, isSigner: true),
            ],
            data: data.buffer.asUint8List(),
        );
    }

    /// Create a MintTo instruction.
    static TransactionInstruction mintTo({
        required PublicKey mint,
        required PublicKey destination,
        required PublicKey authority,
        required int amount,
    }) {
        final data = ByteData(9);
        data.setUint8(0, 7); // MintTo instruction index
        data.setUint64(1, amount, Endian.little);
        
        return TransactionInstruction(
            programId: programId,
            keys: [
                AccountMeta.writable(mint, isSigner: false),
                AccountMeta.writable(destination, isSigner: false),
                AccountMeta.readonly(authority, isSigner: true),
            ],
            data: data.buffer.asUint8List(),
        );
    }
}

class AssociatedTokenProgram {
    AssociatedTokenProgram._();
    
    static final programId = PublicKey.fromString('ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL');
    
    /// Create an Associated Token Account.
    static TransactionInstruction create({
        required PublicKey payer,
        required PublicKey associatedToken,
        required PublicKey owner,
        required PublicKey mint,
    }) {
        return TransactionInstruction(
            programId: programId,
            keys: [
                AccountMeta.writable(payer, isSigner: true),
                AccountMeta.writable(associatedToken, isSigner: false),
                AccountMeta.readonly(owner, isSigner: false),
                AccountMeta.readonly(mint, isSigner: false),
                AccountMeta.readonly(SystemProgram.programId, isSigner: false),
                AccountMeta.readonly(TokenProgram.programId, isSigner: false),
                AccountMeta.readonly(PublicKey.fromString('SysvarRent111111111111111111111111111111111'), isSigner: false),
            ],
            data: Uint8List(0),
        );
    }
}
