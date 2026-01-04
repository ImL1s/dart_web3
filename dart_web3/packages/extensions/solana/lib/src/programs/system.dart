import 'dart:typed_data';
import '../models/instruction.dart';
import '../models/public_key.dart';

class SystemProgram {
    SystemProgram._();
    
    static final programId = PublicKey.fromString('11111111111111111111111111111111');
    
    /// Create a Transfer instruction.
    static TransactionInstruction transfer({
        required PublicKey fromPublicKey,
        required PublicKey toPublicKey,
        required int lamports,
    }) {
        final data = ByteData(12);
        data.setUint32(0, 2, Endian.little);
        data.setUint64(4, lamports, Endian.little);
        
        return TransactionInstruction(
            programId: programId,
            keys: [
                AccountMeta.writable(fromPublicKey, isSigner: true),
                AccountMeta.writable(toPublicKey),
            ],
            data: data.buffer.asUint8List(),
        );
    }
}
