import 'package:web3_universal_core/web3_universal_core.dart';

/// Flashbots bundle transaction
class FlashbotsBundleTransaction {

  FlashbotsBundleTransaction({
    this.signedTransaction,
    this.transaction,
    this.signer,
  });
  final String? signedTransaction;
  final Map<String, dynamic>? transaction;
  final List<String>? signer;

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

  FlashbotsBundle({
    required this.txs,
    required this.blockNumber,
    this.minTimestamp,
    this.maxTimestamp,
    this.revertingTxHashes,
  });
  final List<FlashbotsBundleTransaction> txs;
  final BigInt blockNumber;
  final int? minTimestamp;
  final int? maxTimestamp;
  final List<String>? revertingTxHashes;

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
