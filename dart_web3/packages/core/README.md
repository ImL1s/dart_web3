# dart_web3_core

<!-- Package not yet published to pub.dev -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform: Multi-platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue)

The **foundational primitive layer** for the Dart Web3 SDK. This package provides the essential types and utilities required for all blockchain interactions, focusing on performance and cross-platform compatibility.

## 🚀 Features

- **Robust Address Management**: Full support for EIP-55 checksums and ICAP formats.
- **Typed RLP Implementation**: high-performance Recursive Length Prefix encoding for Ethereum data structures.
- **Ether Units**: Type-safe conversions (Wei, Gwei, Ether) with fixed-point accuracy.
- **Byte Manipulation**: Zero-copy friendly extraction and conversion utilities for `Uint8List`.

## Usage Flow
```mermaid
sequenceDiagram
    participant U as User
    participant A as Address
    participant R as RLP
    participant H as Hex
    U->>A: parseHex(0x...)
    A->>H: decode()
    H->>R: encode(data)
    R-->>U: result bytes
```

## 🏗️ Architecture

```mermaid
graph TD
    subgraph Primitives [Fundamental Types]
        Address[EthAddress]
        Hash[Hash / Bytes]
        BlockNum[BlockNumber]
    end

    subgraph Logic [Manipulation Layers]
        RLP[RLP Logic]
        Hex[Hex Utils]
        Units[EthUnit]
    end

    Primitives --> Logic
    Logic --> API[Public Interface]
    
    classDef primary fill:#f9f,stroke:#333,stroke-width:2px;
    class Primitives,Logic primary;
```

## 📚 Technical Reference

### Core Classes
| Class | Responsibility |
|-------|----------------|
| `EthAddress` | Represents an Ethereum address with checksum validation. |
| `RLP` | Handles serialization of arbitrary data for Ethereum transactions. |
| `EthUnit` | Provides precise big-integer based unit conversions. |
}
```

### Advanced RLP Encoding
```dart
final encoded = RLP.encode([
  EthAddress.fromHex('0x...').toBytes(),
  BigInt.from(1000),
  [Uint8List.fromList([1, 2, 3])]
]);
```

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_web3_core: ^0.1.0
```
