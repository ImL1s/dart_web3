/// UTXO (Unspent Transaction Output) model for Bitcoin
/// UTXO (Unspent Transaction Output) model for Bitcoin Ordinals
class OrdinalUtxo {
  /// Transaction ID
  final String txid;

  /// Output index
  final int vout;

  /// Value in satoshis
  final int value;

  /// Whether this is a SegWit output
  final bool isSegwit;

  /// Address associated with this UTXO
  final String? address;

  /// Script pubkey (optional)
  final String? scriptPubKey;

  OrdinalUtxo({
    required this.txid,
    required this.vout,
    required this.value,
    this.isSegwit = false,
    this.address,
    this.scriptPubKey,
  });

  /// Create from JSON
  factory OrdinalUtxo.fromJson(Map<String, dynamic> json) {
    return OrdinalUtxo(
      txid: json['txid'] as String,
      vout: json['vout'] as int,
      value: json['value'] as int,
      isSegwit: json['isSegwit'] as bool? ?? false,
      address: json['address'] as String?,
      scriptPubKey: json['scriptPubKey'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'txid': txid,
        'vout': vout,
        'value': value,
        'isSegwit': isSegwit,
        if (address != null) 'address': address,
        if (scriptPubKey != null) 'scriptPubKey': scriptPubKey,
      };

  /// Get the outpoint string (txid:vout)
  String get outpoint => '$txid:$vout';

  @override
  String toString() => 'OrdinalUtxo($outpoint, $value sats)';
}
