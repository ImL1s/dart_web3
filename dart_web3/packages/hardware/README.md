# Web3 Universal Hardware Wallet Support

Hardware wallet integrations for the Dart Web3 SDK.

## Packages

| Package | Description |
|---------|-------------|
| [`web3_universal_ledger`](./ledger) | Ledger hardware wallet support via USB and Bluetooth |
| [`web3_universal_trezor`](./trezor) | Trezor hardware wallet integration |
| [`web3_universal_keystone`](./keystone) | Keystone (air-gapped) wallet via QR codes |
| [`web3_universal_bc_ur`](./bc_ur) | BC-UR (Blockchain Uniform Resources) encoding for QR-based signing |
| [`web3_universal_mpc`](./mpc) | Multi-Party Computation wallet support |

## Features

- **Secure Signing**: Private keys never leave the hardware device
- **Multi-Chain**: Support for Ethereum, Bitcoin, and other major chains
- **Cross-Platform**: Works on mobile (USB OTG, Bluetooth) and desktop

## Usage

```yaml
dependencies:
  web3_universal_ledger: ^0.1.0
```

```dart
import 'package:web3_universal_ledger/web3_universal_ledger.dart';

// Connect to Ledger via USB
final ledger = LedgerSigner();
await ledger.connect();

// Sign a transaction
final signature = await ledger.signTransaction(tx);
```

## Security

All hardware wallet integrations follow security best practices:
- No private key extraction
- Transaction verification on device display
- Support for HD derivation paths (BIP-44/49/84)

## License

MIT License - see the main repository for details.
