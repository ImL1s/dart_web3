/// Core utilities for Dart Web3 SDK.
///
/// This library provides fundamental utilities for blockchain development:
/// - [EthereumAddress] - Ethereum address handling with EIP-55 checksum
/// - [EthUnit] - Wei/Gwei/Ether unit conversions
/// - [HexUtils] - Hexadecimal encoding/decoding
/// - [RLP] - Recursive Length Prefix encoding/decoding
/// - [BytesUtils] - Byte array manipulation utilities
library dart_web3_core;

export 'src/address.dart';
export 'src/units.dart';
export 'src/hex.dart';
export 'src/rlp.dart';
export 'src/bytes.dart';
export 'src/exceptions.dart';
