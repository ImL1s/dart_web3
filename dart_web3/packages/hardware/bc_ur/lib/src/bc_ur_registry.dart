import 'dart:typed_data';

/// BC-UR Registry for standard types
/// Based on the Blockchain Commons UR Registry
class BCURRegistry {
  // Standard UR types
  static const int cryptoPsbt = 1;
  static const int cryptoAccount = 2;
  static const int cryptoHdkey = 3;
  static const int cryptoKeypath = 4;
  static const int cryptoCoinInfo = 5;
  static const int cryptoEckey = 6;
  static const int cryptoAddress = 7;
  static const int cryptoOutput = 8;
  static const int ethSignRequest = 401;
  static const int ethSignature = 402;
  static const int ethSignTypedData = 403;
  
  // Type names mapping
  static const Map<int, String> typeNames = {
    cryptoPsbt: 'crypto-psbt',
    cryptoAccount: 'crypto-account',
    cryptoHdkey: 'crypto-hdkey',
    cryptoKeypath: 'crypto-keypath',
    cryptoCoinInfo: 'crypto-coin-info',
    cryptoEckey: 'crypto-eckey',
    cryptoAddress: 'crypto-address',
    cryptoOutput: 'crypto-output',
    ethSignRequest: 'eth-sign-request',
    ethSignature: 'eth-signature',
    ethSignTypedData: 'eth-sign-typed-data',
  };
  
  static const Map<String, int> nameToType = {
    'crypto-psbt': cryptoPsbt,
    'crypto-account': cryptoAccount,
    'crypto-hdkey': cryptoHdkey,
    'crypto-keypath': cryptoKeypath,
    'crypto-coin-info': cryptoCoinInfo,
    'crypto-eckey': cryptoEckey,
    'crypto-address': cryptoAddress,
    'crypto-output': cryptoOutput,
    'eth-sign-request': ethSignRequest,
    'eth-signature': ethSignature,
    'eth-sign-typed-data': ethSignTypedData,
  };
  
  /// Get type name from type code
  static String? getTypeName(int type) {
    return typeNames[type];
  }
  
  /// Get type code from type name
  static int? getTypeCode(String name) {
    return nameToType[name];
  }
}

/// Ethereum Sign Request structure
class EthSignRequest {
  final Uint8List requestId;
  final Uint8List signData;
  final int dataType; // 1 = transaction, 2 = typed data, 3 = personal message
  final int? chainId;
  final String? derivationPath;
  final Uint8List? address;
  
  EthSignRequest({
    required this.requestId,
    required this.signData,
    required this.dataType,
    this.chainId,
    this.derivationPath,
    this.address,
  });
  
  Map<int, dynamic> toCbor() {
    final Map<int, dynamic> cbor = {
      1: requestId, // request-id
      2: signData, // sign-data
      3: dataType, // data-type
    };
    
    if (chainId != null) cbor[4] = chainId; // chain-id
    if (derivationPath != null) cbor[5] = derivationPath; // derivation-path
    if (address != null) cbor[6] = address; // address
    
    return cbor;
  }
  
  static EthSignRequest fromCbor(Map<int, dynamic> cbor) {
    return EthSignRequest(
      requestId: cbor[1] as Uint8List,
      signData: cbor[2] as Uint8List,
      dataType: cbor[3] as int,
      chainId: cbor[4] as int?,
      derivationPath: cbor[5] as String?,
      address: cbor[6] as Uint8List?,
    );
  }
}

/// Ethereum Signature structure
class EthSignature {
  final Uint8List requestId;
  final Uint8List signature;
  
  EthSignature({
    required this.requestId,
    required this.signature,
  });
  
  Map<int, dynamic> toCbor() {
    return {
      1: requestId, // request-id
      2: signature, // signature
    };
  }
  
  static EthSignature fromCbor(Map<int, dynamic> cbor) {
    return EthSignature(
      requestId: cbor[1] as Uint8List,
      signature: cbor[2] as Uint8List,
    );
  }
}