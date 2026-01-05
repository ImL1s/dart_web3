# Web3 Universal Extensions

Multi-chain blockchain extensions for the Dart Web3 SDK.

## Packages

| Package | Description |
|---------|-------------|
| [`web3_universal_bitcoin`](./bitcoin) | Bitcoin/UTXO chain support with SegWit, Taproot, and BIP-340 Schnorr signatures |
| [`web3_universal_cosmos`](./cosmos) | Cosmos SDK chain support with IBC and Tendermint RPC |
| [`web3_universal_polkadot`](./polkadot) | Polkadot/Substrate chain support with SCALE codec and Sr25519 |
| [`web3_universal_solana`](./solana) | Solana support with PDA, Transactions, and Metaplex integration |
| [`web3_universal_ton`](./ton) | TON (The Open Network) blockchain support |
| [`web3_universal_tron`](./tron) | TRON blockchain support with TRC-20 tokens |

## Usage

Each extension package can be added independently:

```yaml
dependencies:
  web3_universal_solana: ^0.1.1
  web3_universal_bitcoin: ^0.1.0
```

```dart
import 'package:web3_universal_solana/web3_universal_solana.dart';

// Create a Solana client
final client = SolanaClient('https://api.mainnet-beta.solana.com');
final balance = await client.getBalance(publicKey);
```

## Architecture

All extension packages follow a consistent architecture:
- **Client**: Chain-specific RPC client
- **Signer**: Native signing support (Ed25519, Schnorr, etc.)
- **Transaction**: Chain-specific transaction building

## License

MIT License - see the main repository for details.
