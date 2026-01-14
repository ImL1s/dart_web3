import 'dart:typed_data';
import 'package:bitcoin_base/bitcoin_base.dart' hide UTXO;
import 'package:bitcoin_base/bitcoin_base.dart' as bb;
import '../models/utxo.dart';

/// PSBT (Partially Signed Bitcoin Transaction) builder for Ordinals inscriptions
class OrdinalPsbtBuilder {
  /// Dust limit in satoshis
  static const int dustAmount = 546;

  /// Default sequence number (RBF enabled)
  static const int defaultSequence = 0xfffffffd;

  /// Build a Commit transaction for inscription
  static String buildCommitTransaction({
    required List<OrdinalUtxo> utxos,
    required Uint8List inscriptionScript,
    required String changeAddress,
    required String privateKeyWif,
    required int feeRate,
    BitcoinNetwork? network,
    int? amount,
  }) {
    network ??= BitcoinNetwork.mainnet;
    final outputAmount = amount ?? dustAmount;

    // Parse private key
    final privateKey = ECPrivate.fromWif(
      privateKeyWif,
      netVersion: network.wifNetVer,
    );
    final publicKey = privateKey.getPublic();

    // Create Taproot address
    _createTaprootAddress(
      publicKey,
      inscriptionScript,
      network,
    );

    // Prepare UTXOs
    final bitcoinUtxos = <UtxoWithAddress>[];
    int totalInput = 0;

    for (final utxo in utxos) {
      totalInput += utxo.value;
      final utxoAddress = _parseAddress(utxo.address ?? changeAddress, network);

      bitcoinUtxos.add(
        UtxoWithAddress(
          utxo: bb.BitcoinUtxo(
            txHash: utxo.txid,
            value: BigInt.from(utxo.value),
            vout: utxo.vout,
            scriptType: utxoAddress.type,
          ),
          ownerDetails: bb.UtxoAddressDetails(
            publicKey: publicKey.toHex(),
            address: utxoAddress,
          ),
        ),
      );
    }

    // Calculate fee
    final estimatedSize = _estimateTransactionSize(utxos.length, 2);
    final fee = estimatedSize * feeRate;

    // Create outputs
    final changeAddr = _parseAddress(changeAddress, network);
    final changeAmount = totalInput - outputAmount - fee;

    final outputs = <bb.BitcoinOutput>[];

    if (changeAmount > dustAmount) {
      outputs.add(
        bb.BitcoinOutput(address: changeAddr, value: BigInt.from(changeAmount)),
      );
    }

    // Build transaction
    final builder = bb.BitcoinTransactionBuilder(
      outPuts: outputs,
      fee: BigInt.from(fee),
      network: network,
      utxos: bitcoinUtxos,
    );

    final transaction = builder.buildTransaction((
      trDigest,
      utxo,
      publicKey,
      sighash,
    ) {
      if (utxo.utxo.isP2tr) {
        return privateKey.signBip340(trDigest);
      }
      return privateKey.signECDSA(trDigest);
    });

    return transaction.serialize();
  }

  /// Build a Reveal transaction for inscription
  static String buildRevealTransaction({
    required String commitTxId,
    required int commitVout,
    required Uint8List inscriptionScript,
    required String receiverAddress,
    required String privateKeyWif,
    required int feeRate,
    BitcoinNetwork? network,
    int? inputAmount,
  }) {
    network ??= BitcoinNetwork.mainnet;
    final amount = inputAmount ?? dustAmount;

    // Parse private key
    final privateKey = ECPrivate.fromWif(
      privateKeyWif,
      netVersion: network.wifNetVer,
    );
    final publicKey = privateKey.getPublic();

    // Create Taproot address (same as commit)
    final taprootAddress = _createTaprootAddress(
      publicKey,
      inscriptionScript,
      network,
    );

    // Calculate fee
    final scriptSize = inscriptionScript.length;
    final estimatedSize = _estimateRevealSize(scriptSize);
    final fee = estimatedSize * feeRate;

    // Calculate output
    final outputAmount = amount - fee;
    if (outputAmount < dustAmount) {
      throw Exception('Output amount too small after fees');
    }

    // Create receiver address
    final receiverAddr = _parseAddress(receiverAddress, network);

    // Prepare UTXO from commit
    final utxos = [
      UtxoWithAddress(
        utxo: bb.BitcoinUtxo(
          txHash: commitTxId,
          value: BigInt.from(amount),
          vout: commitVout,
          scriptType: taprootAddress.type,
        ),
        ownerDetails: UtxoAddressDetails(
          publicKey: publicKey.toHex(),
          address: taprootAddress,
        ),
      ),
    ];

    // Create output
    final outputs = [
      bb.BitcoinOutput(address: receiverAddr, value: BigInt.from(outputAmount)),
    ];

    // Build transaction
    final builder = bb.BitcoinTransactionBuilder(
      outPuts: outputs,
      fee: BigInt.from(fee),
      network: network,
      utxos: utxos,
    );

    final transaction = builder.buildTransaction((
      trDigest,
      utxo,
      publicKey,
      sighash,
    ) {
      if (utxo.utxo.isP2tr) {
        return privateKey.signBip340(trDigest);
      }
      return privateKey.signECDSA(trDigest);
    });

    return transaction.serialize();
  }

  /// Create inscription script for text content
  static Uint8List createTextInscriptionScript(String text) {
    final contentBytes = Uint8List.fromList(text.codeUnits);
    return _createInscriptionEnvelope('text/plain', contentBytes);
  }

  /// Create inscription script for image content
  static Uint8List createImageInscriptionScript(
    Uint8List imageData,
    String mimeType,
  ) {
    return _createInscriptionEnvelope(mimeType, imageData);
  }

  /// Create inscription script for JSON content (e.g., BRC-20)
  static Uint8List createJsonInscriptionScript(Map<String, dynamic> json) {
    final jsonStr = _encodeJson(json);
    final contentBytes = Uint8List.fromList(jsonStr.codeUnits);
    return _createInscriptionEnvelope('application/json', contentBytes);
  }

  // Private helpers

  static P2trAddress _createTaprootAddress(
    ECPublic publicKey,
    Uint8List inscriptionScript,
    BitcoinNetwork network,
  ) {
    return publicKey.toTaprootAddress();
  }

  static BitcoinBaseAddress _parseAddress(
    String address,
    BitcoinNetwork network,
  ) {
    if (address.startsWith('bc1') || address.startsWith('tb1')) {
      if (address.length == 42) {
        return P2wpkhAddress.fromAddress(address: address, network: network);
      } else {
        return P2trAddress.fromAddress(address: address, network: network);
      }
    } else if (address.startsWith('1') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      return P2pkhAddress.fromAddress(address: address, network: network);
    } else {
      return P2shAddress.fromAddress(address: address, network: network);
    }
  }

  static int _estimateTransactionSize(int inputCount, int outputCount) {
    var size = 4 + 1 + 1 + 4; // version + counts + locktime
    size += inputCount * (32 + 4 + 1 + 107 + 4); // inputs
    size += outputCount * (8 + 1 + 25); // outputs
    size += inputCount * 68; // witness data estimate
    return size;
  }

  static int _estimateRevealSize(int scriptSize) {
    return 100 + scriptSize + 43 + (scriptSize / 4).ceil();
  }

  static Uint8List _createInscriptionEnvelope(
    String contentType,
    Uint8List content,
  ) {
    // Ordinals envelope format
    final envelope = <int>[];
    envelope.add(0x00); // OP_FALSE
    envelope.add(0x63); // OP_IF
    envelope.add(0x03); // PUSH 3
    envelope.addAll('ord'.codeUnits);
    envelope.add(0x01); // OP_1
    envelope.add(contentType.length);
    envelope.addAll(contentType.codeUnits);
    envelope.add(0x00); // OP_0
    _addPushData(envelope, content);
    envelope.add(0x68); // OP_ENDIF

    return Uint8List.fromList(envelope);
  }

  static void _addPushData(List<int> script, Uint8List data) {
    const maxChunkSize = 520;
    var offset = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      final chunkSize = remaining > maxChunkSize ? maxChunkSize : remaining;
      final chunk = data.sublist(offset, offset + chunkSize);

      if (chunkSize < 76) {
        script.add(chunkSize);
      } else if (chunkSize < 256) {
        script.add(0x4c);
        script.add(chunkSize);
      } else {
        script.add(0x4d);
        script.add(chunkSize & 0xff);
        script.add((chunkSize >> 8) & 0xff);
      }

      script.addAll(chunk);
      offset += chunkSize;
    }
  }

  static String _encodeJson(Map<String, dynamic> json) {
    final buffer = StringBuffer('{');
    var first = true;
    for (final entry in json.entries) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"${entry.key}":');
      final value = entry.value;
      if (value is String) {
        buffer.write('"$value"');
      } else if (value is num || value is bool) {
        buffer.write(value);
      } else {
        buffer.write('"$value"');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }
}
