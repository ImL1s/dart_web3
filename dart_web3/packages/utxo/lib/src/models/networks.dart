class NetworkType {
  const NetworkType({
    required this.messagePrefix,
    required this.bech32Hrp,
    required this.pubKeyHashPrefix,
    required this.scriptHashPrefix,
    required this.wifPrefix,
    this.opReturnVout,
  });

  final String messagePrefix;
  final String bech32Hrp;
  final int pubKeyHashPrefix;
  final int scriptHashPrefix;
  final int wifPrefix;
  final int? opReturnVout; // For chains using different logic if any

  // Bitcoin
  static const bitcoinMainnet = NetworkType(
    messagePrefix: '\x18Bitcoin Signed Message:\n',
    bech32Hrp: 'bc',
    pubKeyHashPrefix: 0x00,
    scriptHashPrefix: 0x05,
    wifPrefix: 0x80,
  );

  static const bitcoinTestnet = NetworkType(
    messagePrefix: '\x18Bitcoin Signed Message:\n',
    bech32Hrp: 'tb',
    pubKeyHashPrefix: 0x6f,
    scriptHashPrefix: 0xc4,
    wifPrefix: 0xef,
  );

  // Litecoin
  static const litecoinMainnet = NetworkType(
    messagePrefix: '\x19Litecoin Signed Message:\n',
    bech32Hrp: 'ltc',
    pubKeyHashPrefix: 0x30,
    scriptHashPrefix: 0x32, // Deprecated: 0x05
    wifPrefix: 0xb0,
  );

  static const litecoinTestnet = NetworkType(
    messagePrefix: '\x19Litecoin Signed Message:\n',
    bech32Hrp: 'tltc',
    pubKeyHashPrefix: 0x6f,
    scriptHashPrefix: 0x3a, // Deprecated: 0xc4
    wifPrefix: 0xef,
  );

  // Dogecoin
  static const dogecoinMainnet = NetworkType(
    messagePrefix: '\x19Dogecoin Signed Message:\n',
    bech32Hrp: '', // No Bech32 standard
    pubKeyHashPrefix: 0x1e,
    scriptHashPrefix: 0x16,
    wifPrefix: 0x9e,
  );

  static const dogecoinTestnet = NetworkType(
    messagePrefix: '\x19Dogecoin Signed Message:\n',
    bech32Hrp: '',
    pubKeyHashPrefix: 0x71,
    scriptHashPrefix: 0xc4,
    wifPrefix: 0xf1,
  );

  // Bitcoin Cash (BCH)
  // Uses CashAddr usually, but legacy addresses supported
  static const bitcoinCashMainnet = NetworkType(
    messagePrefix: '\x18Bitcoin Crypto Signed Message:\n', // Verify prefix
    bech32Hrp: 'bitcoincash', // CashAddr prefix usually
    pubKeyHashPrefix: 0x00,
    scriptHashPrefix: 0x05,
    wifPrefix: 0x80,
  );

  // TODO: Add Dash, Zcash etc if requested
}
