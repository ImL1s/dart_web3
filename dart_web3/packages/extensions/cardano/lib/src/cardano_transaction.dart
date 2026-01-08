import 'dart:typed_data';
import 'cardano_types.dart';

/// Cardano transaction input.
class CardanoTxInput {
  /// Creates a CardanoTxInput.
  const CardanoTxInput({required this.txHash, required this.index});

  /// Creates from a UTxO.
  factory CardanoTxInput.fromUtxo(CardanoUtxo utxo) {
    return CardanoTxInput(txHash: utxo.txHash, index: utxo.outputIndex);
  }

  /// Transaction hash.
  final CardanoTxHash txHash;

  /// Output index.
  final int index;

  /// Converts to CBOR map.
  Map<String, dynamic> toCbor() => {
    'transaction_id': txHash.toHex(),
    'index': index,
  };
}

/// Cardano transaction output.
class CardanoTxOutput {
  /// Creates a CardanoTxOutput.
  const CardanoTxOutput({
    required this.address,
    required this.amount,
    this.datum,
    this.datumHash,
    this.scriptRef,
  });

  /// Recipient address.
  final CardanoAddress address;

  /// Output value.
  final CardanoMultiAsset amount;

  /// Inline datum.
  final CardanoPlutusData? datum;

  /// Datum hash.
  final Uint8List? datumHash;

  /// Reference script.
  final CardanoScript? scriptRef;

  /// Converts to CBOR map.
  Map<String, dynamic> toCbor() => {
    'address': address.toBech32(),
    'amount': amount.toCbor(),
    if (datum != null) 'datum': datum!.toCbor(),
    if (datumHash != null) 'datum_hash': datumHash,
    if (scriptRef != null) 'script_ref': scriptRef!.toCbor(),
  };
}

/// Cardano multi-asset value.
class CardanoMultiAsset {
  /// Creates a CardanoMultiAsset.
  const CardanoMultiAsset({required this.coin, this.multiAsset});

  /// Creates with only ADA.
  factory CardanoMultiAsset.lovelace(BigInt lovelace) {
    return CardanoMultiAsset(coin: lovelace);
  }

  /// ADA amount in lovelace.
  final BigInt coin;

  /// Native tokens: policy_id -> (asset_name -> quantity).
  final Map<String, Map<String, BigInt>>? multiAsset;

  /// Converts to CBOR.
  dynamic toCbor() {
    if (multiAsset == null || multiAsset!.isEmpty) {
      return coin.toString();
    }
    return {
      'coin': coin.toString(),
      'multiasset': multiAsset,
    };
  }

  /// Adds another value.
  CardanoMultiAsset operator +(CardanoMultiAsset other) {
    final newCoin = coin + other.coin;
    final newMultiAsset = <String, Map<String, BigInt>>{};

    // Add this multiasset
    if (multiAsset != null) {
      for (final entry in multiAsset!.entries) {
        newMultiAsset[entry.key] = Map.from(entry.value);
      }
    }

    // Add other multiasset
    if (other.multiAsset != null) {
      for (final entry in other.multiAsset!.entries) {
        if (!newMultiAsset.containsKey(entry.key)) {
          newMultiAsset[entry.key] = {};
        }
        for (final asset in entry.value.entries) {
          final current = newMultiAsset[entry.key]![asset.key] ?? BigInt.zero;
          newMultiAsset[entry.key]![asset.key] = current + asset.value;
        }
      }
    }

    return CardanoMultiAsset(
      coin: newCoin,
      multiAsset: newMultiAsset.isNotEmpty ? newMultiAsset : null,
    );
  }
}

/// Cardano Plutus data.
sealed class CardanoPlutusData {
  const CardanoPlutusData();

  /// Converts to CBOR.
  dynamic toCbor();
}

/// Integer data.
class PlutusInteger extends CardanoPlutusData {
  /// Creates a PlutusInteger.
  const PlutusInteger(this.value);

  /// Integer value.
  final BigInt value;

  @override
  dynamic toCbor() => {'int': value.toString()};
}

/// Bytes data.
class PlutusBytes extends CardanoPlutusData {
  /// Creates a PlutusBytes.
  const PlutusBytes(this.value);

  /// Byte value.
  final Uint8List value;

  @override
  dynamic toCbor() => {'bytes': value};
}

/// List data.
class PlutusList extends CardanoPlutusData {
  /// Creates a PlutusList.
  const PlutusList(this.items);

  /// List items.
  final List<CardanoPlutusData> items;

  @override
  dynamic toCbor() => {'list': items.map((i) => i.toCbor()).toList()};
}

/// Map data.
class PlutusMap extends CardanoPlutusData {
  /// Creates a PlutusMap.
  const PlutusMap(this.entries);

  /// Map entries.
  final Map<CardanoPlutusData, CardanoPlutusData> entries;

  @override
  dynamic toCbor() => {
    'map': entries.entries
        .map((e) => {'k': e.key.toCbor(), 'v': e.value.toCbor()})
        .toList(),
  };
}

/// Constructor data.
class PlutusConstr extends CardanoPlutusData {
  /// Creates a PlutusConstr.
  const PlutusConstr({required this.constructor, required this.fields});

  /// Constructor index.
  final int constructor;

  /// Constructor fields.
  final List<CardanoPlutusData> fields;

  @override
  dynamic toCbor() => {
    'constructor': constructor,
    'fields': fields.map((f) => f.toCbor()).toList(),
  };
}

/// Cardano script.
sealed class CardanoScript {
  const CardanoScript();

  /// Converts to CBOR.
  dynamic toCbor();
}

/// Native script.
class NativeScript extends CardanoScript {
  /// Creates a NativeScript.
  const NativeScript({required this.type, this.scripts, this.keyHash, this.slot, this.required});

  /// Script type.
  final NativeScriptType type;

  /// Sub-scripts (for all/any/n-of-k).
  final List<NativeScript>? scripts;

  /// Key hash (for sig).
  final Uint8List? keyHash;

  /// Slot number (for time locks).
  final BigInt? slot;

  /// Required count (for n-of-k).
  final int? required;

  @override
  dynamic toCbor() => {
    'type': type.name,
    if (scripts != null) 'scripts': scripts!.map((s) => s.toCbor()).toList(),
    if (keyHash != null) 'keyHash': keyHash,
    if (slot != null) 'slot': slot.toString(),
    if (required != null) 'required': required,
  };
}

/// Native script types.
enum NativeScriptType {
  /// Signature required.
  sig,

  /// All scripts must be satisfied.
  all,

  /// Any script must be satisfied.
  any,

  /// N of K scripts must be satisfied.
  atLeast,

  /// Valid after slot.
  after,

  /// Valid before slot.
  before,
}

/// Plutus script.
class PlutusScript extends CardanoScript {
  /// Creates a PlutusScript.
  const PlutusScript({required this.version, required this.bytes});

  /// Plutus version (1 or 2).
  final int version;

  /// Script bytes.
  final Uint8List bytes;

  @override
  dynamic toCbor() => {
    'type': 'plutus_v$version',
    'bytes': bytes,
  };
}

/// Cardano transaction body.
class CardanoTxBody {
  /// Creates a CardanoTxBody.
  const CardanoTxBody({
    required this.inputs,
    required this.outputs,
    required this.fee,
    this.ttl,
    this.certificates,
    this.withdrawals,
    this.mint,
    this.scriptDataHash,
    this.collateral,
    this.requiredSigners,
    this.networkId,
    this.collateralReturn,
    this.totalCollateral,
    this.referenceInputs,
  });

  /// Transaction inputs.
  final List<CardanoTxInput> inputs;

  /// Transaction outputs.
  final List<CardanoTxOutput> outputs;

  /// Fee in lovelace.
  final BigInt fee;

  /// Time to live (slot).
  final BigInt? ttl;

  /// Certificates.
  final List<CardanoCertificate>? certificates;

  /// Withdrawals.
  final Map<String, BigInt>? withdrawals;

  /// Minting/burning.
  final CardanoMultiAsset? mint;

  /// Script data hash.
  final Uint8List? scriptDataHash;

  /// Collateral inputs.
  final List<CardanoTxInput>? collateral;

  /// Required signers.
  final List<Uint8List>? requiredSigners;

  /// Network ID.
  final int? networkId;

  /// Collateral return output.
  final CardanoTxOutput? collateralReturn;

  /// Total collateral.
  final BigInt? totalCollateral;

  /// Reference inputs.
  final List<CardanoTxInput>? referenceInputs;

  /// Converts to CBOR map.
  Map<String, dynamic> toCbor() => {
    'inputs': inputs.map((i) => i.toCbor()).toList(),
    'outputs': outputs.map((o) => o.toCbor()).toList(),
    'fee': fee.toString(),
    if (ttl != null) 'ttl': ttl.toString(),
    if (certificates != null)
      'certificates': certificates!.map((c) => c.toCbor()).toList(),
    if (withdrawals != null) 'withdrawals': withdrawals,
    if (mint != null) 'mint': mint!.toCbor(),
    if (scriptDataHash != null) 'script_data_hash': scriptDataHash,
    if (collateral != null)
      'collateral': collateral!.map((c) => c.toCbor()).toList(),
    if (requiredSigners != null) 'required_signers': requiredSigners,
    if (networkId != null) 'network_id': networkId,
    if (collateralReturn != null)
      'collateral_return': collateralReturn!.toCbor(),
    if (totalCollateral != null) 'total_collateral': totalCollateral.toString(),
    if (referenceInputs != null)
      'reference_inputs': referenceInputs!.map((r) => r.toCbor()).toList(),
  };
}

/// Cardano certificate.
sealed class CardanoCertificate {
  const CardanoCertificate();

  /// Converts to CBOR.
  dynamic toCbor();
}

/// Stake key registration.
class StakeRegistration extends CardanoCertificate {
  /// Creates a StakeRegistration.
  const StakeRegistration(this.stakeCredential);

  /// Stake credential.
  final Uint8List stakeCredential;

  @override
  dynamic toCbor() => {
    'type': 'stake_registration',
    'stake_credential': stakeCredential,
  };
}

/// Stake key deregistration.
class StakeDeregistration extends CardanoCertificate {
  /// Creates a StakeDeregistration.
  const StakeDeregistration(this.stakeCredential);

  /// Stake credential.
  final Uint8List stakeCredential;

  @override
  dynamic toCbor() => {
    'type': 'stake_deregistration',
    'stake_credential': stakeCredential,
  };
}

/// Stake delegation.
class StakeDelegation extends CardanoCertificate {
  /// Creates a StakeDelegation.
  const StakeDelegation({required this.stakeCredential, required this.poolKeyHash});

  /// Stake credential.
  final Uint8List stakeCredential;

  /// Pool key hash.
  final Uint8List poolKeyHash;

  @override
  dynamic toCbor() => {
    'type': 'stake_delegation',
    'stake_credential': stakeCredential,
    'pool_keyhash': poolKeyHash,
  };
}

/// Cardano witness set.
class CardanoWitnessSet {
  /// Creates a CardanoWitnessSet.
  const CardanoWitnessSet({
    this.vkeyWitnesses,
    this.nativeScripts,
    this.bootstrapWitnesses,
    this.plutusScripts,
    this.plutusData,
    this.redeemers,
  });

  /// VKey witnesses.
  final List<CardanoVkeyWitness>? vkeyWitnesses;

  /// Native scripts.
  final List<NativeScript>? nativeScripts;

  /// Bootstrap witnesses (Byron).
  final List<dynamic>? bootstrapWitnesses;

  /// Plutus scripts.
  final List<PlutusScript>? plutusScripts;

  /// Plutus data.
  final List<CardanoPlutusData>? plutusData;

  /// Redeemers.
  final List<CardanoRedeemer>? redeemers;

  /// Converts to CBOR map.
  Map<String, dynamic> toCbor() => {
    if (vkeyWitnesses != null)
      'vkeywitnesses': vkeyWitnesses!.map((w) => w.toCbor()).toList(),
    if (nativeScripts != null)
      'native_scripts': nativeScripts!.map((s) => s.toCbor()).toList(),
    if (bootstrapWitnesses != null) 'bootstrap_witnesses': bootstrapWitnesses,
    if (plutusScripts != null)
      'plutus_scripts': plutusScripts!.map((s) => s.toCbor()).toList(),
    if (plutusData != null)
      'plutus_data': plutusData!.map((d) => d.toCbor()).toList(),
    if (redeemers != null)
      'redeemers': redeemers!.map((r) => r.toCbor()).toList(),
  };
}

/// VKey witness.
class CardanoVkeyWitness {
  /// Creates a CardanoVkeyWitness.
  const CardanoVkeyWitness({required this.vkey, required this.signature});

  /// Public key.
  final Uint8List vkey;

  /// Signature.
  final Uint8List signature;

  /// Converts to CBOR.
  Map<String, dynamic> toCbor() => {
    'vkey': vkey,
    'signature': signature,
  };
}

/// Redeemer.
class CardanoRedeemer {
  /// Creates a CardanoRedeemer.
  const CardanoRedeemer({
    required this.tag,
    required this.index,
    required this.data,
    required this.exUnits,
  });

  /// Redeemer tag (spend, mint, cert, reward).
  final RedeemerTag tag;

  /// Index.
  final int index;

  /// Redeemer data.
  final CardanoPlutusData data;

  /// Execution units.
  final ExUnits exUnits;

  /// Converts to CBOR.
  Map<String, dynamic> toCbor() => {
    'tag': tag.name,
    'index': index,
    'data': data.toCbor(),
    'ex_units': exUnits.toCbor(),
  };
}

/// Redeemer tags.
enum RedeemerTag {
  /// Spend redeemer.
  spend,

  /// Mint redeemer.
  mint,

  /// Certificate redeemer.
  cert,

  /// Reward redeemer.
  reward,
}

/// Execution units.
class ExUnits {
  /// Creates ExUnits.
  const ExUnits({required this.mem, required this.steps});

  /// Memory units.
  final BigInt mem;

  /// CPU steps.
  final BigInt steps;

  /// Converts to CBOR.
  Map<String, String> toCbor() => {
    'mem': mem.toString(),
    'steps': steps.toString(),
  };
}

/// Complete signed transaction.
class CardanoTransaction {
  /// Creates a CardanoTransaction.
  const CardanoTransaction({
    required this.body,
    required this.witnessSet,
    this.isValid = true,
    this.auxiliaryData,
  });

  /// Transaction body.
  final CardanoTxBody body;

  /// Witness set.
  final CardanoWitnessSet witnessSet;

  /// Whether the transaction is valid.
  final bool isValid;

  /// Auxiliary data (metadata).
  final Map<String, dynamic>? auxiliaryData;

  /// Serializes to CBOR bytes.
  Uint8List serialize() {
    // CBOR serialization would go here
    return Uint8List(0);
  }

  /// Serializes to CBOR hex.
  String toHex() {
    final bytes = serialize();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Transaction builder.
class CardanoTxBuilder {
  /// Creates a CardanoTxBuilder.
  CardanoTxBuilder({required this.protocolParams});

  /// Protocol parameters.
  final CardanoProtocolParams protocolParams;

  final List<CardanoTxInput> _inputs = [];
  final List<CardanoTxOutput> _outputs = [];
  BigInt? _fee;
  BigInt? _ttl;
  final List<CardanoCertificate> _certificates = [];
  final Map<String, BigInt> _withdrawals = {};

  /// Adds an input.
  CardanoTxBuilder addInput(CardanoTxInput input) {
    _inputs.add(input);
    return this;
  }

  /// Adds an output.
  CardanoTxBuilder addOutput(CardanoTxOutput output) {
    _outputs.add(output);
    return this;
  }

  /// Sets the fee.
  CardanoTxBuilder setFee(BigInt fee) {
    _fee = fee;
    return this;
  }

  /// Sets the TTL.
  CardanoTxBuilder setTtl(BigInt ttl) {
    _ttl = ttl;
    return this;
  }

  /// Adds a certificate.
  CardanoTxBuilder addCertificate(CardanoCertificate certificate) {
    _certificates.add(certificate);
    return this;
  }

  /// Adds a withdrawal.
  CardanoTxBuilder addWithdrawal(String rewardAddress, BigInt amount) {
    _withdrawals[rewardAddress] = amount;
    return this;
  }

  /// Calculates minimum fee.
  BigInt calculateMinFee(int txSize) {
    return BigInt.from(protocolParams.minFeeA * txSize + protocolParams.minFeeB);
  }

  /// Builds the transaction body.
  CardanoTxBody build() {
    if (_inputs.isEmpty) {
      throw StateError('No inputs added');
    }
    if (_outputs.isEmpty) {
      throw StateError('No outputs added');
    }
    if (_fee == null) {
      throw StateError('Fee not set');
    }

    return CardanoTxBody(
      inputs: _inputs,
      outputs: _outputs,
      fee: _fee!,
      ttl: _ttl,
      certificates: _certificates.isNotEmpty ? _certificates : null,
      withdrawals: _withdrawals.isNotEmpty ? _withdrawals : null,
    );
  }
}
