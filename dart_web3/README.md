# Dart Web3 SDK

A comprehensive, pure Dart Web3 SDK for EVM-compatible blockchains and multi-chain support.

## Features

- **Pure Dart Implementation** - No native dependencies (FFI, C++, Rust bindings), works on all Dart/Flutter platforms
- **Modular Architecture** - Import only what you need, each package is independently usable
- **Multi-Chain Support** - Core EVM support with extensions for Solana, Polkadot, Tron, TON, and Bitcoin
- **Type-Safe** - Leverages Dart's type system for compile-time error checking
- **Modern Standards** - Supports EIP-1559, EIP-4844 (Blob), EIP-7702, ERC-4337 (Account Abstraction)

## Installation

Add the packages you need to your `pubspec.yaml`:

```yaml
dependencies:
  # Core functionality
  dart_web3_core: ^0.1.0
  dart_web3_crypto: ^0.1.0
  dart_web3_abi: ^0.1.0
  
  # Client and provider
  dart_web3_provider: ^0.1.0
  dart_web3_client: ^0.1.0
  
  # Or use the meta-package for everything
  dart_web3: ^0.1.0
```

## Quick Start

```dart
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_signer/dart_web3_signer.dart';

void main() async {
  // Create a public client for read-only operations
  final publicClient = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
    chain: Chains.ethereum,
  );
  
  // Get balance
  final balance = await publicClient.getBalance('0x...');
  print('Balance: ${EthUnit.formatEther(balance)} ETH');
  
  // Create a wallet client for transactions
  final signer = PrivateKeySigner.fromHex('0x...', Chains.ethereum.chainId);
  final walletClient = ClientFactory.createWalletClient(
    rpcUrl: 'https://eth.llamarpc.com',
    chain: Chains.ethereum,
    signer: signer,
  );
  
  // Send transaction
  final txHash = await walletClient.transfer(
    '0xRecipient...',
    EthUnit.ether('0.1'),
  );
  print('Transaction: $txHash');
}
```

## Package Structure

| Package | Description | Level |
|---------|-------------|-------|
| `dart_web3_core` | Core utilities (address, BigInt, encoding, RLP) | 0 |
| `dart_web3_crypto` | Cryptography (secp256k1, keccak, BIP-32/39/44) | 1 |
| `dart_web3_abi` | ABI encoding/decoding | 1 |
| `dart_web3_provider` | RPC Provider (HTTP/WebSocket) | 2 |
| `dart_web3_signer` | Signer abstraction | 2 |
| `dart_web3_chains` | Chain configurations | 2 |
| `dart_web3_client` | PublicClient/WalletClient | 3 |
| `dart_web3_contract` | Contract abstraction | 3 |
| `dart_web3_events` | Event subscription | 3 |
| `dart_web3_multicall` | Multicall support | 4 |
| `dart_web3_ens` | ENS resolution | 4 |
| `dart_web3_aa` | ERC-4337 Account Abstraction | 5 |
| `dart_web3_reown` | Reown/WalletConnect v2 | 5 |
| `dart_web3_swap` | DEX aggregation | 5 |
| `dart_web3_bridge` | Cross-chain bridging | 5 |
| `dart_web3_nft` | NFT services | 5 |
| `dart_web3_staking` | Staking services | 5 |
| `dart_web3_debug` | Debug/Trace API | 5 |
| `dart_web3_mev` | MEV protection/Flashbots | 5 |
| `dart_web3_keystone` | Keystone hardware wallet | 6 |
| `dart_web3_ledger` | Ledger hardware wallet | 6 |
| `dart_web3_trezor` | Trezor hardware wallet | 6 |
| `dart_web3_mpc` | MPC wallet support | 6 |
| `dart_web3_solana` | Solana extension | 7 |
| `dart_web3_polkadot` | Polkadot extension | 7 |
| `dart_web3_tron` | Tron extension | 7 |
| `dart_web3_ton` | TON extension | 7 |
| `dart_web3_bitcoin` | Bitcoin extension | 7 |

## Development

This project uses [Melos](https://melos.invertase.dev/) for monorepo management.

```bash
# Install melos globally
dart pub global activate melos

# Bootstrap the workspace
melos bootstrap

# Run tests
melos test

# Run analysis
melos analyze
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## References

This SDK is inspired by and references:
- [viem](https://viem.sh/) - Modern TypeScript EVM library
- [ethers.js](https://ethers.org/) - Classic TypeScript EVM library
- [alloy](https://alloy.rs/) - Rust Ethereum SDK
- [blockchain_utils](https://github.com/mrtnetwork/blockchain_utils) - Pure Dart crypto utilities
- [on_chain](https://github.com/mrtnetwork/on_chain) - Multi-chain Dart library
