import 'dart:typed_data';



/// Represents a UTXO transaction input (vin).
class TransactionInput {
  TransactionInput({
    required this.txId,
    required this.vout,
    Uint8List? scriptSig,
    this.sequence = 0xffffffff,
    this.witness,
  }) : scriptSig = scriptSig ?? Uint8List(0);

  /// Previous transaction ID (32 bytes).
  final Uint8List txId;

  /// Output index in the previous transaction.
  final int vout;

  /// Unlocking script (Signature Script).
  final Uint8List scriptSig;

  /// Sequence number (default 0xffffffff).
  final int sequence;

  /// Witness data for SegWit inputs.
  final List<Uint8List>? witness;

  /// Calculates the size of this input in bytes.
  int get size => 32 + 4 + _varIntSize(scriptSig.length) + scriptSig.length + 4;
}

/// Represents a UTXO transaction output (vout).
class TransactionOutput {
  TransactionOutput({
    required this.amount,
    required this.scriptPubKey,
  });

  /// Amount in satoshis/smallest unit.
  final BigInt amount;

  /// Locking script (Public Key Script).
  final Uint8List scriptPubKey;

  /// Calculates the size of this output in bytes.
  int get size => 8 + _varIntSize(scriptPubKey.length) + scriptPubKey.length;
}

/// Represents a generic UTXO transaction.
class BitcoinTransaction {
  BitcoinTransaction({
    this.version = 2,
    List<TransactionInput>? inputs,
    List<TransactionOutput>? outputs,
    this.lockTime = 0,
  })  : inputs = inputs ?? [],
        outputs = outputs ?? [];

  /// Transaction version.
  final int version;

  /// List of inputs.
  final List<TransactionInput> inputs;

  /// List of outputs.
  final List<TransactionOutput> outputs;

  /// Transaction lock time.
  final int lockTime;

  /// Serializes the transaction to raw bytes.
  ///
  /// [segwit] - Whether to include witness data (BIP-144).
  Uint8List toBytes({bool segwit = true}) {
    final buffer = BytesBuilder();

    // 1. Version (4 bytes little-endian)
    buffer.add(_int32ToBytes(version));

    // Check if we need extended format (SegWit)
    final hasWitness = segwit && inputs.any((i) => i.witness != null && i.witness!.isNotEmpty);
    if (hasWitness) {
      buffer.addByte(0x00); // Marker
      buffer.addByte(0x01); // Flag
    }

    // 2. Input Count (VarInt)
    buffer.add(_encodeVarInt(inputs.length));

    // 3. Inputs
    for (final input in inputs) {
      buffer.add(input.txId); // Already in correct endian usually
      buffer.add(_int32ToBytes(input.vout));
      buffer.add(_encodeVarInt(input.scriptSig.length));
      buffer.add(input.scriptSig);
      buffer.add(_int32ToBytes(input.sequence));
    }

    // 4. Output Count (VarInt)
    buffer.add(_encodeVarInt(outputs.length));

    // 5. Outputs
    for (final output in outputs) {
      buffer.add(_int64ToBytes(output.amount));
      buffer.add(_encodeVarInt(output.scriptPubKey.length));
      buffer.add(output.scriptPubKey);
    }

    // 6. Witness Data (if extended format)
    if (hasWitness) {
      for (final input in inputs) {
        final witnesses = input.witness ?? const [];
        buffer.add(_encodeVarInt(witnesses.length));
        for (final item in witnesses) {
          buffer.add(_encodeVarInt(item.length));
          buffer.add(item);
        }
      }
    }

    // 7. LockTime (4 bytes little-endian)
    buffer.add(_int32ToBytes(lockTime));

    return buffer.toBytes();
  }

  /// Transaction ID (hash of the transaction).
  String get txId {
    // SegWit txId is hash of legacy serialization (no witness)
    // TODO: Implement proper double SHA256 when imports available
    return ''; 
  }

  /// Parses a transaction from raw bytes.
  static BitcoinTransaction fromBytes(Uint8List bytes) {
    if (bytes.length < 10) throw FormatException('Transaction too short');
    
    var offset = 0;
    final buffer = ByteData.sublistView(bytes);

    // 1. Version
    final version = buffer.getInt32(offset, Endian.little);
    offset += 4;

    // Check for SegWit marker
    final marker = bytes[offset];
    final flag = bytes[offset + 1];
    final isSegwit = marker == 0x00 && flag == 0x01;
    
    if (isSegwit) {
      offset += 2;
    }

    // 2. Inputs
    final inputCountRes = _readVarInt(bytes, offset);
    final inputCount = inputCountRes.value;
    offset = inputCountRes.nextOffset;

    final inputs = <TransactionInput>[];
    for (var i = 0; i < inputCount; i++) {
        final txId = bytes.sublist(offset, offset + 32);
        offset += 32;

        final vout = buffer.getUint32(offset, Endian.little);
        offset += 4;

        final scriptLenRes = _readVarInt(bytes, offset);
        offset = scriptLenRes.nextOffset;

        final scriptSig = bytes.sublist(offset, offset + scriptLenRes.value);
        offset += scriptLenRes.value;

        final sequence = buffer.getUint32(offset, Endian.little);
        offset += 4;

        inputs.add(TransactionInput(
            txId: txId,
            vout: vout,
            scriptSig: scriptSig,
            sequence: sequence,
        ));
    }

    // 3. Outputs
    final outputCountRes = _readVarInt(bytes, offset);
    final outputCount = outputCountRes.value;
    offset = outputCountRes.nextOffset;

    final outputs = <TransactionOutput>[];
    for (var i = 0; i < outputCount; i++) {
        final amount = BigInt.from(buffer.getUint64(offset, Endian.little));
        offset += 8;

        final scriptLenRes = _readVarInt(bytes, offset);
        offset = scriptLenRes.nextOffset;

        final scriptPubKey = bytes.sublist(offset, offset + scriptLenRes.value);
        offset += scriptLenRes.value;

        outputs.add(TransactionOutput(amount: amount, scriptPubKey: scriptPubKey));
    }

    // 4. Witness (if SegWit)
    if (isSegwit) {
        for (var i = 0; i < inputCount; i++) {
            final witnessCountRes = _readVarInt(bytes, offset);
            final witnessCount = witnessCountRes.value;
            offset = witnessCountRes.nextOffset;

            final witnesses = <Uint8List>[];
            for (var w = 0; w < witnessCount; w++) {
                final itemLenRes = _readVarInt(bytes, offset);
                offset = itemLenRes.nextOffset;
                
                final item = bytes.sublist(offset, offset + itemLenRes.value);
                offset += itemLenRes.value;
                witnesses.add(item);
            }
            // Can't easily mutate final fields on input, assume inputs constructed correctly 
            // Workaround: recreate input with witness
            inputs[i] = TransactionInput(
                txId: inputs[i].txId,
                vout: inputs[i].vout,
                scriptSig: inputs[i].scriptSig,
                sequence: inputs[i].sequence,
                witness: witnesses,
            );
        }
    }

    // 5. LockTime
    final lockTime = buffer.getUint32(offset, Endian.little);
    
    return BitcoinTransaction(
        version: version,
        inputs: inputs,
        outputs: outputs,
        lockTime: lockTime,
    );
  }
}

// Internal varint reader helper class
class _VarIntResult {
  _VarIntResult(this.value, this.nextOffset);
  final int value;
  final int nextOffset;
}

_VarIntResult _readVarInt(Uint8List bytes, int offset) {
  final first = bytes[offset];
  if (first < 0xfd) {
    return _VarIntResult(first, offset + 1);
  } else if (first == 0xfd) {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 3).getUint16(0, Endian.little);
    return _VarIntResult(val, offset + 3);
  } else if (first == 0xfe) {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 5).getUint32(0, Endian.little);
    return _VarIntResult(val, offset + 5);
  } else {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 9).getUint64(0, Endian.little);
    return _VarIntResult(val, offset + 9);
  }
}

Uint8List _int32ToBytes(int value) {
  final buffer = Uint8List(4);
  final data = ByteData.view(buffer.buffer);
  data.setInt32(0, value, Endian.little);
  return buffer;
}

Uint8List _int64ToBytes(BigInt value) {
  final buffer = Uint8List(8);
  var v = value;
  for (var i = 0; i < 8; i++) {
    buffer[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return buffer;
}

Uint8List _encodeVarInt(int value) {
  if (value < 0xfd) {
    return Uint8List.fromList([value]);
  } else if (value <= 0xffff) {
    final buffer = Uint8List(3);
    buffer[0] = 0xfd;
    buffer[1] = value & 0xff;
    buffer[2] = (value >> 8) & 0xff;
    return buffer;
  } else if (value <= 0xffffffff) {
    final buffer = Uint8List(5);
    buffer[0] = 0xfe;
    ByteData.view(buffer.buffer).setUint32(1, value, Endian.little);
    return buffer;
  } else {
    final buffer = Uint8List(9);
    buffer[0] = 0xff;
    ByteData.view(buffer.buffer).setUint64(1, value, Endian.little);
    return buffer;
  }
}

int _varIntSize(int value) {
  if (value < 0xfd) return 1;
  if (value <= 0xffff) return 3;
  if (value <= 0xffffffff) return 5;
  return 9;
}
