# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-01-01

### Added
- **Core (Level 0)**: `dart_web3_core` with address handling, BigInt tools, and RLP.
- **Primitives (Level 1)**: `dart_web3_crypto` (Secp256k1, Keccak, BIP-39/32/44) and `dart_web3_abi`.
- **Transport (Level 2)**: `dart_web3_provider` (HTTP/WS), `dart_web3_signer`, and `dart_web3_chains`.
- **Clients (Level 3)**: `dart_web3_client` (Public/Wallet), `dart_web3_contract`, and `dart_web3_events`.
- **Services (Level 4)**: `dart_web3_multicall`, `dart_web3_ens`.
- **Advanced (Level 5)**: `dart_web3_aa` (ERC-4337), `dart_web3_reown`, `dart_web3_swap`, `dart_web3_bridge`, `dart_web3_nft`, `dart_web3_staking`, `dart_web3_debug`, `dart_web3_mev`.
- **Hardware (Level 6)**: `dart_web3_bc_ur`, `dart_web3_keystone`, `dart_web3_ledger`, `dart_web3_trezor`, `dart_web3_mpc`.
- **Extensions (Level 7)**: Solana, Polkadot, Tron, TON, Bitcoin (Inscriptions/BRC-20).
- **Meta-Package**: `dart_web3` integrating all modules.

### Fixed
- Fixed various type errors in NFT and DApp providers.
- Improved deterministic signing logic for testing.
- Fixed dependency paths for workspace compatibility.
