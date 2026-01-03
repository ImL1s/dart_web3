/// ABI encoding and decoding for Ethereum smart contracts.
///
/// This library provides:
/// - [AbiType] - Type system for Solidity types
/// - [AbiEncoder] - Encode function calls and data
/// - [AbiDecoder] - Decode return values and events
/// - [TypedData] - EIP-712 structured data
/// - [AbiParser] - Parse ABI JSON
/// - [AbiPrettyPrinter] - Format ABI data for display
library web3_universal_abi;

export 'src/decoder.dart';
export 'src/encoder.dart';
export 'src/parser.dart';
export 'src/pretty_printer.dart';
export 'src/typed_data.dart';
export 'src/types.dart';
