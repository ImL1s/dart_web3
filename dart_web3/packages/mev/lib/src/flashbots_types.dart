import 'package:dart_web3_core/dart_web3_core.dart';

/// Flashbots bundle transaction
class FlashbotsBundleTransaction {
  final String? signedTransaction;
  final Map<String, dynamic>? transaction;
  final List<String>? signer;

  FlashbotsBundleTransaction({
    this.signedTransaction,
    this.transaction,
    this.signer,
  });

  Map<String, dynamic> toJson() {
    return {
      if (signedTransaction != null) 'signedTransaction': signedTransaction,
      if (transaction != null) 'transaction': transaction,
      if (signer != null) 'signer': signer,
    };
  }
}

/// Flashbots bundle
class FlashbotsBundle {
  final List<FlashbotsBundleTransaction> txs;
  final BigInt blockNumber;
  final int? minTimestamp;
  final int? maxTimestamp;
  final List<String>? revertingTxHashes;

  FlashbotsBundle({
    required this.txs,
    required this.blockNumber,
    this.minTimestamp,
    this.maxTimestamp,
    this.revertingTxHashes,
  });

  Map<String, dynamic> toJson() {
    return {
      'txs': txs.map((tx) => tx.signedTransaction).toList(), // Simplified for signed txs
      'blockNumber': HexUtils.encode(BytesUtils.bigIntToBytes(blockNumber)),
      if (minTimestamp != null) 'minTimestamp': minTimestamp,
      if (maxTimestamp != null) 'maxTimestamp': maxTimestamp,
      if (revertingTxHashes != null) 'revertingTxHashes': revertingTxHashes,
    };
  }
}
