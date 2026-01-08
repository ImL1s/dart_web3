import 'dart:typed_data';

/// Cosmos address (Bech32 encoded).
class CosmosAddress {
  /// Creates a CosmosAddress.
  const CosmosAddress({required this.prefix, required this.bytes});

  /// Creates a CosmosAddress from a Bech32 string.
  factory CosmosAddress.fromBech32(String address) {
    // Simple parsing - in production would use proper Bech32 decoding
    final parts = address.split('1');
    if (parts.length < 2) {
      throw ArgumentError('Invalid Bech32 address: $address');
    }
    final prefix = parts[0];
    // Placeholder bytes - real implementation would decode Bech32
    return CosmosAddress(prefix: prefix, bytes: Uint8List(20));
  }

  /// Creates a CosmosAddress from raw bytes and prefix.
  factory CosmosAddress.fromBytes(String prefix, Uint8List bytes) {
    return CosmosAddress(prefix: prefix, bytes: bytes);
  }

  /// The Bech32 prefix (e.g., "cosmos", "osmo").
  final String prefix;

  /// The raw address bytes (typically 20 bytes for secp256k1).
  final Uint8List bytes;

  /// Converts to Bech32 string.
  String toBech32() {
    // Placeholder - would use proper Bech32 encoding
    return '${prefix}1placeholder${bytes.length}';
  }

  /// Converts with a different prefix (for IBC).
  CosmosAddress withPrefix(String newPrefix) {
    return CosmosAddress(prefix: newPrefix, bytes: bytes);
  }

  @override
  String toString() => toBech32();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CosmosAddress) return false;
    if (prefix != other.prefix) return false;
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(prefix, Object.hashAll(bytes));
}

/// Cosmos coin.
class CosmosCoin {
  /// Creates a CosmosCoin.
  const CosmosCoin({required this.denom, required this.amount});

  /// Creates from JSON.
  factory CosmosCoin.fromJson(Map<String, dynamic> json) {
    return CosmosCoin(
      denom: json['denom'] as String,
      amount: BigInt.parse(json['amount'] as String),
    );
  }

  /// Denomination (e.g., "uatom").
  final String denom;

  /// Amount in minimal units.
  final BigInt amount;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'denom': denom,
    'amount': amount.toString(),
  };

  /// Creates a coin with a different amount.
  CosmosCoin withAmount(BigInt newAmount) {
    return CosmosCoin(denom: denom, amount: newAmount);
  }

  /// Adds two coins of the same denomination.
  CosmosCoin operator +(CosmosCoin other) {
    if (denom != other.denom) {
      throw ArgumentError('Cannot add coins with different denominations');
    }
    return CosmosCoin(denom: denom, amount: amount + other.amount);
  }

  @override
  String toString() => '$amount$denom';
}

/// Cosmos fee.
class CosmosFee {
  /// Creates a CosmosFee.
  const CosmosFee({
    required this.amount,
    required this.gasLimit,
    this.payer,
    this.granter,
  });

  /// Creates from JSON.
  factory CosmosFee.fromJson(Map<String, dynamic> json) {
    return CosmosFee(
      amount: (json['amount'] as List)
          .map((e) => CosmosCoin.fromJson(e as Map<String, dynamic>))
          .toList(),
      gasLimit: BigInt.parse(json['gas_limit'] as String? ?? json['gas'] as String),
      payer: json['payer'] as String?,
      granter: json['granter'] as String?,
    );
  }

  /// Fee amount.
  final List<CosmosCoin> amount;

  /// Gas limit.
  final BigInt gasLimit;

  /// Fee payer address (optional).
  final String? payer;

  /// Fee granter address (optional).
  final String? granter;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'amount': amount.map((c) => c.toJson()).toList(),
    'gas_limit': gasLimit.toString(),
    if (payer != null) 'payer': payer,
    if (granter != null) 'granter': granter,
  };
}

/// Cosmos account information.
class CosmosAccount {
  /// Creates a CosmosAccount.
  const CosmosAccount({
    required this.address,
    required this.pubKey,
    required this.accountNumber,
    required this.sequence,
  });

  /// Creates from JSON.
  factory CosmosAccount.fromJson(Map<String, dynamic> json) {
    return CosmosAccount(
      address: json['address'] as String,
      pubKey: json['pub_key'] as Map<String, dynamic>?,
      accountNumber: BigInt.parse(json['account_number'] as String),
      sequence: BigInt.parse(json['sequence'] as String),
    );
  }

  /// Account address.
  final String address;

  /// Public key.
  final Map<String, dynamic>? pubKey;

  /// Account number.
  final BigInt accountNumber;

  /// Sequence number (nonce).
  final BigInt sequence;
}

/// Cosmos block information.
class CosmosBlock {
  /// Creates a CosmosBlock.
  const CosmosBlock({
    required this.height,
    required this.hash,
    required this.time,
    required this.proposerAddress,
    this.txCount,
  });

  /// Creates from JSON.
  factory CosmosBlock.fromJson(Map<String, dynamic> json) {
    final header = json['header'] as Map<String, dynamic>? ?? json;
    final blockId = json['block_id'] as Map<String, dynamic>?;
    return CosmosBlock(
      height: BigInt.parse(header['height'] as String),
      hash: blockId?['hash'] as String? ?? '',
      time: DateTime.parse(header['time'] as String),
      proposerAddress: header['proposer_address'] as String? ?? '',
      txCount: json['data']?['txs']?.length as int?,
    );
  }

  /// Block height.
  final BigInt height;

  /// Block hash.
  final String hash;

  /// Block time.
  final DateTime time;

  /// Proposer address.
  final String proposerAddress;

  /// Number of transactions.
  final int? txCount;
}

/// Cosmos transaction result.
class CosmosTxResult {
  /// Creates a CosmosTxResult.
  const CosmosTxResult({
    required this.txHash,
    required this.height,
    required this.code,
    required this.gasWanted,
    required this.gasUsed,
    this.rawLog,
    this.logs,
    this.events,
  });

  /// Creates from JSON.
  factory CosmosTxResult.fromJson(Map<String, dynamic> json) {
    final txResponse = json['tx_response'] as Map<String, dynamic>? ?? json;
    return CosmosTxResult(
      txHash: txResponse['txhash'] as String,
      height: BigInt.parse(txResponse['height'] as String),
      code: txResponse['code'] as int? ?? 0,
      gasWanted: BigInt.parse(txResponse['gas_wanted'] as String? ?? '0'),
      gasUsed: BigInt.parse(txResponse['gas_used'] as String? ?? '0'),
      rawLog: txResponse['raw_log'] as String?,
      logs: txResponse['logs'] as List?,
      events: txResponse['events'] as List?,
    );
  }

  /// Transaction hash.
  final String txHash;

  /// Block height.
  final BigInt height;

  /// Result code (0 = success).
  final int code;

  /// Gas wanted.
  final BigInt gasWanted;

  /// Gas used.
  final BigInt gasUsed;

  /// Raw log.
  final String? rawLog;

  /// Parsed logs.
  final List? logs;

  /// Events.
  final List? events;

  /// Whether the transaction succeeded.
  bool get isSuccess => code == 0;
}

/// Cosmos validator information.
class CosmosValidator {
  /// Creates a CosmosValidator.
  const CosmosValidator({
    required this.operatorAddress,
    required this.consensusPubkey,
    required this.jailed,
    required this.status,
    required this.tokens,
    required this.delegatorShares,
    required this.description,
    required this.commission,
  });

  /// Creates from JSON.
  factory CosmosValidator.fromJson(Map<String, dynamic> json) {
    return CosmosValidator(
      operatorAddress: json['operator_address'] as String,
      consensusPubkey: json['consensus_pubkey'] as Map<String, dynamic>,
      jailed: json['jailed'] as bool,
      status: json['status'] as String,
      tokens: BigInt.parse(json['tokens'] as String),
      delegatorShares: json['delegator_shares'] as String,
      description: CosmosValidatorDescription.fromJson(
        json['description'] as Map<String, dynamic>,
      ),
      commission: CosmosCommission.fromJson(
        json['commission'] as Map<String, dynamic>,
      ),
    );
  }

  final String operatorAddress;
  final Map<String, dynamic> consensusPubkey;
  final bool jailed;
  final String status;
  final BigInt tokens;
  final String delegatorShares;
  final CosmosValidatorDescription description;
  final CosmosCommission commission;
}

/// Cosmos validator description.
class CosmosValidatorDescription {
  /// Creates a CosmosValidatorDescription.
  const CosmosValidatorDescription({
    this.moniker,
    this.identity,
    this.website,
    this.securityContact,
    this.details,
  });

  /// Creates from JSON.
  factory CosmosValidatorDescription.fromJson(Map<String, dynamic> json) {
    return CosmosValidatorDescription(
      moniker: json['moniker'] as String?,
      identity: json['identity'] as String?,
      website: json['website'] as String?,
      securityContact: json['security_contact'] as String?,
      details: json['details'] as String?,
    );
  }

  final String? moniker;
  final String? identity;
  final String? website;
  final String? securityContact;
  final String? details;
}

/// Cosmos commission.
class CosmosCommission {
  /// Creates a CosmosCommission.
  const CosmosCommission({
    required this.commissionRates,
    required this.updateTime,
  });

  /// Creates from JSON.
  factory CosmosCommission.fromJson(Map<String, dynamic> json) {
    return CosmosCommission(
      commissionRates: CosmosCommissionRates.fromJson(
        json['commission_rates'] as Map<String, dynamic>,
      ),
      updateTime: DateTime.parse(json['update_time'] as String),
    );
  }

  final CosmosCommissionRates commissionRates;
  final DateTime updateTime;
}

/// Cosmos commission rates.
class CosmosCommissionRates {
  /// Creates CosmosCommissionRates.
  const CosmosCommissionRates({
    required this.rate,
    required this.maxRate,
    required this.maxChangeRate,
  });

  /// Creates from JSON.
  factory CosmosCommissionRates.fromJson(Map<String, dynamic> json) {
    return CosmosCommissionRates(
      rate: json['rate'] as String,
      maxRate: json['max_rate'] as String,
      maxChangeRate: json['max_change_rate'] as String,
    );
  }

  final String rate;
  final String maxRate;
  final String maxChangeRate;
}

/// Cosmos delegation.
class CosmosDelegation {
  /// Creates a CosmosDelegation.
  const CosmosDelegation({
    required this.delegatorAddress,
    required this.validatorAddress,
    required this.shares,
    required this.balance,
  });

  /// Creates from JSON.
  factory CosmosDelegation.fromJson(Map<String, dynamic> json) {
    final delegation = json['delegation'] as Map<String, dynamic>? ?? json;
    return CosmosDelegation(
      delegatorAddress: delegation['delegator_address'] as String,
      validatorAddress: delegation['validator_address'] as String,
      shares: delegation['shares'] as String,
      balance: json['balance'] != null
          ? CosmosCoin.fromJson(json['balance'] as Map<String, dynamic>)
          : null,
    );
  }

  final String delegatorAddress;
  final String validatorAddress;
  final String shares;
  final CosmosCoin? balance;
}

/// IBC channel state.
enum IbcChannelState {
  /// Uninitialized state.
  uninitialized('STATE_UNINITIALIZED_UNSPECIFIED'),

  /// Init state.
  init('STATE_INIT'),

  /// TryOpen state.
  tryOpen('STATE_TRYOPEN'),

  /// Open state.
  open('STATE_OPEN'),

  /// Closed state.
  closed('STATE_CLOSED');

  const IbcChannelState(this.value);
  final String value;
}

/// IBC channel.
class IbcChannel {
  /// Creates an IbcChannel.
  const IbcChannel({
    required this.state,
    required this.ordering,
    required this.counterparty,
    required this.connectionHops,
    required this.version,
  });

  /// Creates from JSON.
  factory IbcChannel.fromJson(Map<String, dynamic> json) {
    return IbcChannel(
      state: IbcChannelState.values.firstWhere(
        (e) => e.value == json['state'],
        orElse: () => IbcChannelState.uninitialized,
      ),
      ordering: json['ordering'] as String,
      counterparty: IbcCounterparty.fromJson(
        json['counterparty'] as Map<String, dynamic>,
      ),
      connectionHops: (json['connection_hops'] as List).cast<String>(),
      version: json['version'] as String,
    );
  }

  final IbcChannelState state;
  final String ordering;
  final IbcCounterparty counterparty;
  final List<String> connectionHops;
  final String version;
}

/// IBC counterparty.
class IbcCounterparty {
  /// Creates an IbcCounterparty.
  const IbcCounterparty({required this.portId, required this.channelId});

  /// Creates from JSON.
  factory IbcCounterparty.fromJson(Map<String, dynamic> json) {
    return IbcCounterparty(
      portId: json['port_id'] as String,
      channelId: json['channel_id'] as String,
    );
  }

  final String portId;
  final String channelId;
}
