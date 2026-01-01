# Dart Web3 SDK

A comprehensive, pure Dart Web3 SDK for EVM-compatible blockchains and multi-chain support.

## Features

- **Pure Dart Implementation** - No native dependencies (FFI, C++, Rust bindings), works on all Dart/Flutter platforms
- **Modular Architecture** - Import only what you need, each package is independently usable
- **Multi-Chain Support** - Core EVM support with extensions for Solana, Polkadot, Tron, TON, and Bitcoin
- **Hardware Wallets** - Built-in support for Ledger, Trezor, Keystone, and various MPC solutions
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

## Usage Workflow

```mermaid
graph LR
    A[Setup] --> B[Core Components]
    B --> C[Connect & Sign]
    C --> D[Interact]
    D --> E[Advanced Features]

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#bfb,stroke:#333,stroke-width:2px
    style D fill:#fbf,stroke:#333,stroke-width:2px
    style E fill:#fbb,stroke:#333,stroke-width:2px
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

## Examples

We provide a variety of examples to help you get started with the SDK:

| Example | Description |
|---------|-------------|
| [Connectivity](dart_web3/example/connectivity.dart) | Check connectivity across multiple networks |
| [Wallet Management](dart_web3/example/wallet_overview.dart) | HD Wallet derivation, mnemonic generation, and signing |
| [Token Interactions](dart_web3/example/token_interactions.dart) | Reading ERC-20 metadata and balances |
| [Account Abstraction](dart_web3/example/account_abstraction_basic.dart) | ERC-4337 Smart Account setup and UserOps |

Find more details in the [Usage Guide](dart_web3/USAGE_GUIDE.md).

## Architecture Blueprint

```mermaid
graph TD
    subgraph L0 [Layer 0: Core Primitives]
        Core[dart_web3_core]
    end

    subgraph L1 [Layer 1: Cryptography & Encoding]
        Crypto[dart_web3_crypto]
        ABI[dart_web3_abi]
    end

    subgraph L2 [Layer 2: Connectivity & Identity]
        Provider[dart_web3_provider]
        Signer[dart_web3_signer]
        Chains[dart_web3_chains]
    end

    subgraph L3 [Layer 3: Client & Interaction]
        Client[dart_web3_client]
        Contract[dart_web3_contract]
    end

    subgraph L4 [Layer 4: Advanced Features]
        ENS[dart_web3_ens]
        AA[dart_web3_aa]
        NFT[dart_web3_nft]
        Swap[dart_web3_swap]
    end

    subgraph Ext [Extensions & Hardware]
        Solana[dart_web3_solana]
        Bitcoin[dart_web3_bitcoin]
        Ledger[dart_web3_ledger]
    end

    Core --> Crypto
    Crypto --> ABI
    ABI --> Provider
    Provider --> Client
    Signer --> Client
    Chains --> Client
    Client --> Contract
    
    Client -.-> ENS
    Client -.-> AA
    Client -.-> NFT
    
    L2 --- Ext
```

## Package Structure

| Package | Description | Level |
|---------|-------------|-------|
| [`dart_web3_core`](dart_web3/packages/core) | Core utilities (address, BigInt, encoding, RLP) | 0 |
| [`dart_web3_crypto`](dart_web3/packages/crypto) | Cryptography (secp256k1, keccak, BIP-32/39/44) | 1 |
| [`dart_web3_abi`](dart_web3/packages/abi) | ABI encoding/decoding | 1 |
| [`dart_web3_provider`](dart_web3/packages/provider) | RPC Provider (HTTP/WebSocket) | 2 |
| [`dart_web3_signer`](dart_web3/packages/signer) | Signer abstraction | 2 |
| [`dart_web3_chains`](dart_web3/packages/chains) | Chain configurations | 2 |
| [`dart_web3_client`](dart_web3/packages/client) | PublicClient/WalletClient | 3 |
| [`dart_web3_contract`](dart_web3/packages/contract) | Contract abstraction | 3 |
| [`dart_web3_events`](dart_web3/packages/events) | Event subscription | 3 |
| [`dart_web3_multicall`](dart_web3/packages/multicall) | Multicall support | 4 |
| [`dart_web3_ens`](dart_web3/packages/ens) | ENS resolution | 4 |
| [`dart_web3_aa`](dart_web3/packages/aa) | ERC-4337 Account Abstraction | 5 |
| [`dart_web3_reown`](dart_web3/packages/reown) | Reown/WalletConnect v2 | 5 |
| [`dart_web3_swap`](dart_web3/packages/swap) | DEX aggregation | 5 |
| [`dart_web3_bridge`](dart_web3/packages/bridge) | Cross-chain bridging | 5 |
| [`dart_web3_nft`](dart_web3/packages/nft) | NFT services | 5 |
| [`dart_web3_staking`](dart_web3/packages/staking) | Staking services | 5 |
| [`dart_web3_debug`](dart_web3/packages/debug) | Debug/Trace API | 5 |
| [`dart_web3_mev`](dart_web3/packages/mev) | MEV protection/Flashbots | 5 |
| [`dart_web3_dapp`](dart_web3/packages/dapp) | DApp state & session management | 5 |
| [`dart_web3_history`](dart_web3/packages/history) | Transaction history explorer | 5 |
| [`dart_web3_price`](dart_web3/packages/price) | Asset pricing and oracles | 5 |
| [`dart_web3_bc_ur`](dart_web3/packages/hardware/bc_ur) | BC-UR air-gapped protocol | 6 |
| [`dart_web3_keystone`](dart_web3/packages/hardware/keystone) | Keystone hardware wallet | 6 |
| [`dart_web3_ledger`](dart_web3/packages/hardware/ledger) | Ledger hardware wallet | 6 |
| [`dart_web3_trezor`](dart_web3/packages/hardware/trezor) | Trezor hardware wallet | 6 |
| [`dart_web3_mpc`](dart_web3/packages/hardware/mpc) | MPC wallet support | 6 |
| [`dart_web3_solana`](dart_web3/packages/extensions/solana) | Solana extension | 7 |
| [`dart_web3_polkadot`](dart_web3/packages/extensions/polkadot) | Polkadot extension | 7 |
| [`dart_web3_tron`](dart_web3/packages/extensions/tron) | Tron extension | 7 |
| [`dart_web3_ton`](dart_web3/packages/extensions/ton) | TON extension | 7 |
| [`dart_web3_bitcoin`](dart_web3/packages/extensions/bitcoin) | Bitcoin extension | 7 |

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
