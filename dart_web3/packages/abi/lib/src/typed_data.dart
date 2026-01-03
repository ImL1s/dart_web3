import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// EIP-712 Typed Data for structured data signing.
class TypedData {

  TypedData({
    required this.domain,
    required this.types,
    required this.primaryType,
    required this.message,
  });

  /// Creates TypedData from a JSON map.
  factory TypedData.fromJson(Map<String, dynamic> json) {
    final types = <String, List<TypedDataField>>{};
    final jsonTypes = json['types'] as Map<String, dynamic>;

    for (final entry in jsonTypes.entries) {
      if (entry.key == 'EIP712Domain') continue;
      types[entry.key] = (entry.value as List)
          .map((f) => TypedDataField(
                name: f['name'] as String,
                type: f['type'] as String,
              ),)
          .toList();
    }

    return TypedData(
      domain: json['domain'] as Map<String, dynamic>,
      types: types,
      primaryType: json['primaryType'] as String,
      message: json['message'] as Map<String, dynamic>,
    );
  }
  /// The domain separator parameters.
  final Map<String, dynamic> domain;

  /// The type definitions.
  final Map<String, List<TypedDataField>> types;

  /// The primary type being signed.
  final String primaryType;

  /// The message data.
  final Map<String, dynamic> message;

  /// Computes the EIP-712 hash for signing.
  Uint8List hash() {
    final domainSeparator = _hashDomain();
    final structHash = _hashStruct(primaryType, message);

    // \x19\x01 || domainSeparator || structHash
    final data = BytesUtils.concat([
      Uint8List.fromList([0x19, 0x01]),
      domainSeparator,
      structHash,
    ]);

    return Keccak256.hash(data);
  }

  /// Computes the domain separator.
  Uint8List _hashDomain() {
    final domainType = <TypedDataField>[];

    if (domain.containsKey('name')) {
      domainType.add(TypedDataField(name: 'name', type: 'string'));
    }
    if (domain.containsKey('version')) {
      domainType.add(TypedDataField(name: 'version', type: 'string'));
    }
    if (domain.containsKey('chainId')) {
      domainType.add(TypedDataField(name: 'chainId', type: 'uint256'));
    }
    if (domain.containsKey('verifyingContract')) {
      domainType.add(TypedDataField(name: 'verifyingContract', type: 'address'));
    }
    if (domain.containsKey('salt')) {
      domainType.add(TypedDataField(name: 'salt', type: 'bytes32'));
    }

    return _hashStructWithType('EIP712Domain', domainType, domain);
  }

  /// Computes the struct hash.
  Uint8List _hashStruct(String typeName, Map<String, dynamic> data) {
    final typeFields = types[typeName];
    if (typeFields == null) {
      throw ArgumentError('Unknown type: $typeName');
    }
    return _hashStructWithType(typeName, typeFields, data);
  }

  Uint8List _hashStructWithType(
    String typeName,
    List<TypedDataField> fields,
    Map<String, dynamic> data,
  ) {
    final typeHash = _hashType(typeName, fields);
    final encodedValues = <Uint8List>[typeHash];

    for (final field in fields) {
      final value = data[field.name];
      encodedValues.add(_encodeValue(field.type, value));
    }

    return Keccak256.hash(BytesUtils.concat(encodedValues));
  }

  /// Computes the type hash.
  Uint8List _hashType(String typeName, List<TypedDataField> fields) {
    final typeString = _encodeType(typeName, fields);
    return Keccak256.hash(Uint8List.fromList(typeString.codeUnits));
  }

  /// Encodes the type string.
  String _encodeType(String typeName, List<TypedDataField> fields) {
    final params = fields.map((f) => '${f.type} ${f.name}').join(',');
    return '$typeName($params)';
  }

  /// Encodes a value for hashing.
  Uint8List _encodeValue(String type, dynamic value) {
    if (type == 'string') {
      return Keccak256.hash(Uint8List.fromList((value as String).codeUnits));
    }
    if (type == 'bytes') {
      return Keccak256.hash(value as Uint8List);
    }
    if (type == 'bool') {
      final result = Uint8List(32);
      result[31] = (value as bool) ? 1 : 0;
      return result;
    }
    if (type == 'address') {
      final result = Uint8List(32);
      final address = value.toString().toLowerCase();
      final hex = address.startsWith('0x') ? address.substring(2) : address;
      for (var i = 0; i < 20; i++) {
        result[12 + i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return result;
    }
    if (type.startsWith('uint') || type.startsWith('int')) {
      final bigValue = value is BigInt ? value : BigInt.from(value as int);
      final result = Uint8List(32);
      var v = bigValue;
      if (v.isNegative && type.startsWith('int')) {
        v = (BigInt.one << 256) + v;
      }
      for (var i = 31; i >= 0 && v > BigInt.zero; i--) {
        result[i] = (v & BigInt.from(0xff)).toInt();
        v = v >> 8;
      }
      return result;
    }
    if (type.startsWith('bytes') && !type.contains('[')) {
      final bytes = value as Uint8List;
      final result = Uint8List(32);
      result.setRange(0, bytes.length, bytes);
      return result;
    }

    // Custom struct type
    if (types.containsKey(type)) {
      return _hashStruct(type, value as Map<String, dynamic>);
    }

    throw ArgumentError('Unsupported type: $type');
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson() {
    final jsonTypes = <String, dynamic>{};

    // Add EIP712Domain type
    final domainFields = <Map<String, String>>[];
    if (domain.containsKey('name')) {
      domainFields.add({'name': 'name', 'type': 'string'});
    }
    if (domain.containsKey('version')) {
      domainFields.add({'name': 'version', 'type': 'string'});
    }
    if (domain.containsKey('chainId')) {
      domainFields.add({'name': 'chainId', 'type': 'uint256'});
    }
    if (domain.containsKey('verifyingContract')) {
      domainFields.add({'name': 'verifyingContract', 'type': 'address'});
    }
    if (domain.containsKey('salt')) {
      domainFields.add({'name': 'salt', 'type': 'bytes32'});
    }
    jsonTypes['EIP712Domain'] = domainFields;

    // Add other types
    for (final entry in types.entries) {
      jsonTypes[entry.key] = entry.value.map((f) => {'name': f.name, 'type': f.type}).toList();
    }

    return {
      'types': jsonTypes,
      'primaryType': primaryType,
      'domain': domain,
      'message': message,
    };
  }
}

/// A field in a typed data struct.
class TypedDataField {

  TypedDataField({required this.name, required this.type});
  final String name;
  final String type;
}
