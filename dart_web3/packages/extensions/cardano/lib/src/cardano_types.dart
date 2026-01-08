import 'dart:typed_data';

/// Cardano address types.
enum CardanoAddressType {
  /// Base address (payment + staking).
  base(0),

  /// Pointer address.
  pointer(4),

  /// Enterprise address (payment only).
  enterprise(6),

  /// Reward/stake address.
  reward(14),

  /// Byron address (legacy).
  byron(8);

  const CardanoAddressType(this.header);

  /// Address header nibble.
  final int header;
}

/// Cardano address.
class CardanoAddress {
  /// Creates a CardanoAddress.
  const CardanoAddress({
    required this.type,
    required this.network,
    required this.bytes,
    this.bech32,
  });

  /// Creates from Bech32 string.
  factory CardanoAddress.fromBech32(String bech32) {
    // Simple parsing - determine type from prefix
    CardanoAddressType type;
    int network;

    if (bech32.startsWith('addr1')) {
      type = CardanoAddressType.base;
      network = 1; // mainnet
    } else if (bech32.startsWith('addr_test1')) {
      type = CardanoAddressType.base;
      network = 0; // testnet
    } else if (bech32.startsWith('stake1')) {
      type = CardanoAddressType.reward;
      network = 1;
    } else if (bech32.startsWith('stake_test1')) {
      type = CardanoAddressType.reward;
      network = 0;
    } else {
      type = CardanoAddressType.base;
      network = 1;
    }

    return CardanoAddress(
      type: type,
      network: network,
      bytes: Uint8List(57), // Placeholder
      bech32: bech32,
    );
  }

  /// Address type.
  final CardanoAddressType type;

  /// Network ID (0 = testnet, 1 = mainnet).
  final int network;

  /// Raw address bytes.
  final Uint8List bytes;

  /// Bech32 representation.
  final String? bech32;

  /// Whether this is a mainnet address.
  bool get isMainnet => network == 1;

  /// Converts to Bech32 string.
  String toBech32() {
    if (bech32 != null) return bech32!;
    // Placeholder - would use proper Bech32 encoding
    final prefix = isMainnet ? 'addr1' : 'addr_test1';
    return '${prefix}placeholder';
  }

  @override
  String toString() => toBech32();
}

/// Cardano transaction hash.
class CardanoTxHash {
  /// Creates a CardanoTxHash.
  const CardanoTxHash(this.bytes);

  /// Creates from hex string.
  factory CardanoTxHash.fromHex(String hex) {
    var cleanHex = hex;
    if (cleanHex.startsWith('0x')) {
      cleanHex = cleanHex.substring(2);
    }
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return CardanoTxHash(bytes);
  }

  /// The 32-byte hash.
  final Uint8List bytes;

  /// Converts to hex string.
  String toHex() {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  String toString() => toHex();
}

/// Cardano UTxO (Unspent Transaction Output).
class CardanoUtxo {
  /// Creates a CardanoUtxo.
  const CardanoUtxo({
    required this.txHash,
    required this.outputIndex,
    required this.amount,
    this.datum,
    this.datumHash,
    this.scriptRef,
  });

  /// Creates from JSON (Blockfrost format).
  factory CardanoUtxo.fromJson(Map<String, dynamic> json) {
    return CardanoUtxo(
      txHash: CardanoTxHash.fromHex(json['tx_hash'] as String),
      outputIndex: json['output_index'] as int? ?? json['tx_index'] as int,
      amount: (json['amount'] as List)
          .map((e) => CardanoValue.fromJson(e as Map<String, dynamic>))
          .toList(),
      datum: json['inline_datum'] as Map<String, dynamic>?,
      datumHash: json['data_hash'] as String?,
      scriptRef: json['reference_script_hash'] as String?,
    );
  }

  /// Transaction hash.
  final CardanoTxHash txHash;

  /// Output index.
  final int outputIndex;

  /// Amount (ADA + native tokens).
  final List<CardanoValue> amount;

  /// Inline datum.
  final Map<String, dynamic>? datum;

  /// Datum hash.
  final String? datumHash;

  /// Reference script hash.
  final String? scriptRef;

  /// Gets the lovelace amount.
  BigInt get lovelace {
    for (final value in amount) {
      if (value.unit == 'lovelace') {
        return value.quantity;
      }
    }
    return BigInt.zero;
  }
}

/// Cardano value (ADA or native token).
class CardanoValue {
  /// Creates a CardanoValue.
  const CardanoValue({required this.unit, required this.quantity});

  /// Creates from JSON.
  factory CardanoValue.fromJson(Map<String, dynamic> json) {
    return CardanoValue(
      unit: json['unit'] as String,
      quantity: BigInt.parse(json['quantity'] as String),
    );
  }

  /// Unit (lovelace or policy_id + asset_name).
  final String unit;

  /// Quantity.
  final BigInt quantity;

  /// Whether this is ADA (lovelace).
  bool get isAda => unit == 'lovelace';

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'unit': unit,
    'quantity': quantity.toString(),
  };
}

/// Cardano asset (native token).
class CardanoAsset {
  /// Creates a CardanoAsset.
  const CardanoAsset({
    required this.policyId,
    required this.assetName,
    required this.quantity,
    this.fingerprint,
    this.metadata,
  });

  /// Creates from JSON.
  factory CardanoAsset.fromJson(Map<String, dynamic> json) {
    return CardanoAsset(
      policyId: json['policy_id'] as String,
      assetName: json['asset_name'] as String? ?? '',
      quantity: BigInt.parse(json['quantity'] as String),
      fingerprint: json['fingerprint'] as String?,
      metadata: json['onchain_metadata'] as Map<String, dynamic>?,
    );
  }

  /// Policy ID (28 bytes hex).
  final String policyId;

  /// Asset name (hex encoded).
  final String assetName;

  /// Quantity.
  final BigInt quantity;

  /// Asset fingerprint.
  final String? fingerprint;

  /// On-chain metadata.
  final Map<String, dynamic>? metadata;

  /// Gets the full unit string.
  String get unit => '$policyId$assetName';
}

/// Cardano block.
class CardanoBlock {
  /// Creates a CardanoBlock.
  const CardanoBlock({
    required this.hash,
    required this.height,
    required this.slot,
    required this.epoch,
    required this.epochSlot,
    required this.time,
    required this.txCount,
    this.size,
    this.previousBlock,
  });

  /// Creates from JSON.
  factory CardanoBlock.fromJson(Map<String, dynamic> json) {
    return CardanoBlock(
      hash: json['hash'] as String,
      height: json['height'] as int? ?? json['block_no'] as int,
      slot: json['slot'] as int? ?? json['abs_slot'] as int,
      epoch: json['epoch'] as int? ?? json['epoch_no'] as int,
      epochSlot: json['epoch_slot'] as int,
      time: DateTime.fromMillisecondsSinceEpoch(
        (json['time'] as int? ?? json['block_time'] as int) * 1000,
      ),
      txCount: json['tx_count'] as int,
      size: json['size'] as int?,
      previousBlock: json['previous_block'] as String?,
    );
  }

  final String hash;
  final int height;
  final int slot;
  final int epoch;
  final int epochSlot;
  final DateTime time;
  final int txCount;
  final int? size;
  final String? previousBlock;
}

/// Cardano epoch.
class CardanoEpoch {
  /// Creates a CardanoEpoch.
  const CardanoEpoch({
    required this.epoch,
    required this.startTime,
    required this.endTime,
    required this.firstBlockTime,
    required this.lastBlockTime,
    required this.blockCount,
    required this.txCount,
    required this.output,
    required this.fees,
    required this.activeStake,
  });

  /// Creates from JSON.
  factory CardanoEpoch.fromJson(Map<String, dynamic> json) {
    return CardanoEpoch(
      epoch: json['epoch'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (json['start_time'] as int) * 1000,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (json['end_time'] as int) * 1000,
      ),
      firstBlockTime: DateTime.fromMillisecondsSinceEpoch(
        (json['first_block_time'] as int) * 1000,
      ),
      lastBlockTime: DateTime.fromMillisecondsSinceEpoch(
        (json['last_block_time'] as int) * 1000,
      ),
      blockCount: json['block_count'] as int,
      txCount: json['tx_count'] as int,
      output: BigInt.parse(json['output'] as String),
      fees: BigInt.parse(json['fees'] as String),
      activeStake: json['active_stake'] != null
          ? BigInt.parse(json['active_stake'] as String)
          : null,
    );
  }

  final int epoch;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime firstBlockTime;
  final DateTime lastBlockTime;
  final int blockCount;
  final int txCount;
  final BigInt output;
  final BigInt fees;
  final BigInt? activeStake;
}

/// Cardano stake pool.
class CardanoPool {
  /// Creates a CardanoPool.
  const CardanoPool({
    required this.poolId,
    required this.hex,
    required this.vrfKey,
    required this.pledge,
    required this.cost,
    required this.margin,
    required this.rewardAccount,
    this.metadata,
    this.activeStake,
    this.liveStake,
  });

  /// Creates from JSON.
  factory CardanoPool.fromJson(Map<String, dynamic> json) {
    return CardanoPool(
      poolId: json['pool_id'] as String,
      hex: json['hex'] as String,
      vrfKey: json['vrf_key'] as String,
      pledge: BigInt.parse(json['pledge'] as String),
      cost: BigInt.parse(json['fixed_cost'] as String? ?? json['cost'] as String),
      margin: double.parse(json['margin_cost'] as String? ?? json['margin'] as String),
      rewardAccount: json['reward_account'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      activeStake: json['active_stake'] != null
          ? BigInt.parse(json['active_stake'] as String)
          : null,
      liveStake: json['live_stake'] != null
          ? BigInt.parse(json['live_stake'] as String)
          : null,
    );
  }

  final String poolId;
  final String hex;
  final String vrfKey;
  final BigInt pledge;
  final BigInt cost;
  final double margin;
  final String rewardAccount;
  final Map<String, dynamic>? metadata;
  final BigInt? activeStake;
  final BigInt? liveStake;
}

/// Protocol parameters.
class CardanoProtocolParams {
  /// Creates CardanoProtocolParams.
  const CardanoProtocolParams({
    required this.minFeeA,
    required this.minFeeB,
    required this.maxTxSize,
    required this.maxValSize,
    required this.keyDeposit,
    required this.poolDeposit,
    required this.coinsPerUtxoSize,
    required this.priceMem,
    required this.priceStep,
    required this.collateralPercent,
    required this.maxCollateralInputs,
  });

  /// Creates from JSON.
  factory CardanoProtocolParams.fromJson(Map<String, dynamic> json) {
    return CardanoProtocolParams(
      minFeeA: json['min_fee_a'] as int,
      minFeeB: json['min_fee_b'] as int,
      maxTxSize: json['max_tx_size'] as int,
      maxValSize: json['max_val_size'] as int? ?? 5000,
      keyDeposit: BigInt.parse(json['key_deposit'] as String),
      poolDeposit: BigInt.parse(json['pool_deposit'] as String),
      coinsPerUtxoSize: BigInt.parse(
        json['coins_per_utxo_size'] as String? ??
            json['coins_per_utxo_word'] as String,
      ),
      priceMem: double.parse(json['price_mem'] as String),
      priceStep: double.parse(json['price_step'] as String),
      collateralPercent: json['collateral_percent'] as int,
      maxCollateralInputs: json['max_collateral_inputs'] as int,
    );
  }

  /// Minimum fee coefficient A.
  final int minFeeA;

  /// Minimum fee coefficient B.
  final int minFeeB;

  /// Maximum transaction size in bytes.
  final int maxTxSize;

  /// Maximum value size in bytes.
  final int maxValSize;

  /// Key registration deposit in lovelace.
  final BigInt keyDeposit;

  /// Pool registration deposit in lovelace.
  final BigInt poolDeposit;

  /// Coins per UTxO byte.
  final BigInt coinsPerUtxoSize;

  /// Plutus memory price.
  final double priceMem;

  /// Plutus step price.
  final double priceStep;

  /// Collateral percentage.
  final int collateralPercent;

  /// Maximum collateral inputs.
  final int maxCollateralInputs;
}
