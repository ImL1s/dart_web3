
  // ═══════════════════════════════════════════════════════════════════════════
  // Bitcoin Implementation (P2WPKH)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _sendBitcoinTransaction(
    ChainConfig chain,
    String to,
    BigInt amount,
    int accountIndex,
  ) async {
    // 1. Get Keys
    final derived = _hdWallet!.derive("m/84'/0'/0'/0/$accountIndex");
    final privateKey = derived.getPrivateKey();
    final publicKey = derived.getPublicKey();
    final pubKeyHash = Ripemd160.hash(Sha256.hash(publicKey));

    // 2. Mock UTXO Fetching (In production: await _fetchUtxos(address))
    // We assume we have one UTXO with enough balance
    final utxoTxId = HexUtils.decode(
      '0000000000000000000000000000000000000000000000000000000000000000',
    );
    final utxoAmount = amount + BigInt.from(10000); // Amount + Fee
    final inputs = [
      TransactionInput(
        txId: utxoTxId,
        vout: 0,
        scriptSig: Uint8List(0), // Empty for Witness
      ),
    ];

    // 3. Create Outputs
    final outputs = <TransactionOutput>[];
    
    // a. Destination Output (Decode Bech32 or P2PKH address)
    // For simplicity, we assume 'to' is also P2WPKH Bech32
    final decodedTo = Bech32.decode(to);
    final toScript = Script.p2wpkh(decodedTo.data); 
    outputs.add(TransactionOutput(amount: amount, scriptPubKey: toScript));

    // b. Change Output (Back to self)
    // Simplified: No change if exact match, or remainder is fee
    // In real app, calculate change: inputs - amount - fee

    // 4. Construct Transaction
    final tx = BitcoinTransaction(
      version: 2,
      inputs: inputs,
      outputs: outputs,
      lockTime: 0,
    );

    // 5. Sign Input
    // We need to calculate BIP-143 Sighash for the input
    final sighash = _calculateBip143Sighash(
      tx: tx,
      inputIndex: 0,
      utxoScriptCode: Script([
        OpCode.opDup,
        OpCode.opHash160,
        pubKeyHash,
        OpCode.opEqualVerify,
        OpCode.opCheckSig,
      ]).compile(), // P2PKH script code for P2WPKH
      utxoAmount: utxoAmount,
      sighashType: 0x01, // SIGHASH_ALL
    );

    // Sign with Secp256k1
    final signature = Secp256k1.sign(sighash, privateKey);
    // Append Sighash type byte
    final scriptSig = Uint8List.fromList([...signature, 0x01]);

    // Attach Witness
    // Witness stack for P2WPKH: [Signature, PublicKey]
    tx.inputs[0] = TransactionInput(
      txId: tx.inputs[0].txId,
      vout: tx.inputs[0].vout,
      scriptSig: tx.inputs[0].scriptSig, // Empty
      sequence: tx.inputs[0].sequence,
      witness: [scriptSig, publicKey],
    );

    // 6. Serialize & Broadcast
    final rawTx = tx.toBytes(segwit: true);
    final rawHex = HexUtils.encode(rawTx);

    // In production: await _broadcastBitcoin(rawHex);
    // Return Mock TxID
    return '0x${Sha256.doubleHash(rawTx).map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}';
  }

  /// Calculates BIP-143 Sighash for SegWit inputs
  Uint8List _calculateBip143Sighash({
    required BitcoinTransaction tx,
    required int inputIndex,
    required Uint8List utxoScriptCode,
    required BigInt utxoAmount,
    required int sighashType,
  }) {
    final buffer = BytesBuilder();

    // 1. Version
    buffer.add(_int32ToBytes(tx.version));

    // 2. HashPrevouts (Double SHA256 of all outpoints)
    final prevouts = BytesBuilder();
    for (final input in tx.inputs) {
      prevouts.add(input.txId);
      prevouts.add(_int32ToBytes(input.vout));
    }
    buffer.add(Sha256.doubleHash(prevouts.toBytes()));

    // 3. HashSequence (Double SHA256 of all sequences)
    final sequences = BytesBuilder();
    for (final input in tx.inputs) {
      sequences.add(_int32ToBytes(input.sequence));
    }
    buffer.add(Sha256.doubleHash(sequences.toBytes()));

    // 4. Outpoint (Specific input)
    final input = tx.inputs[inputIndex];
    buffer.add(input.txId);
    buffer.add(_int32ToBytes(input.vout));

    // 5. ScriptCode (P2PKH script of the UTXO)
    // For P2WPKH, scriptCode is 0x1976a914{20-byte-pubkey-hash}88ac
    // 0x19 is varint length (25)
    // 76 (DUP) a9 (HASH160) 14 (Bytes:20) ... 88 (EQUALVERIFY) ac (CHECKSIG)
    // NOTE: The caller already passed the compiled script, we just need to verify it's not prefixed with length if strictly following standard, 
    // but typically scriptCode includes the length prefix if viewed as a "script". 
    // Actually BIP-143 says "scriptCode of the input". For P2WPKH witness program, it is the P2PKH script.
    // Length (VarInt) + Script
    if (utxoScriptCode.length < 0xfd) {
        buffer.addByte(utxoScriptCode.length);
    } else {
        // Handle varint if needed, but P2PKH is small
        buffer.addByte(utxoScriptCode.length);
    }
    buffer.add(utxoScriptCode);

    // 6. Amount (8 bytes)
    buffer.add(_int64ToBytes(utxoAmount));

    // 7. Sequence (4 bytes)
    buffer.add(_int32ToBytes(input.sequence));

    // 8. HashOutputs (Double SHA256 of all outputs)
    final outputs = BytesBuilder();
    for (final output in tx.outputs) {
      outputs.add(_int64ToBytes(output.amount));
      // Length + ScriptPubKey
      if (output.scriptPubKey.length < 0xfd) {
          outputs.addByte(output.scriptPubKey.length);
      } else {
          // Simplification for demo
          outputs.addByte(output.scriptPubKey.length);
      }
      outputs.add(output.scriptPubKey);
    }
    buffer.add(Sha256.doubleHash(outputs.toBytes()));

    // 9. LockTime
    buffer.add(_int32ToBytes(tx.lockTime));

    // 10. Sighash Type
    buffer.add(_int32ToBytes(sighashType));

    return Sha256.doubleHash(buffer.toBytes());
  }

  Uint8List _int32ToBytes(int value) {
    final buffer = Uint8List(4);
    ByteData.view(buffer.buffer).setInt32(0, value, Endian.little);
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
