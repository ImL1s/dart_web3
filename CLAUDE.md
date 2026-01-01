# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

This is a Dart monorepo using Melos. All commands run from `dart_web3/` directory:

```bash
# Setup
dart pub global activate melos
cd dart_web3
melos bootstrap

# Testing
melos test                          # Run all package tests (sequential, concurrency=1)
melos exec --scope="dart_web3_core" -- dart test  # Test single package
cd packages/core && dart test test/rlp_test.dart  # Run single test file (from package dir)

# Code Quality
melos analyze                       # Static analysis (--fatal-infos)
dart format --set-exit-if-changed . # Check formatting

# Coverage
melos test:coverage                 # Generate coverage reports

# Publishing
melos publish:dry                   # Dry run publish for all packages
melos clean                         # Clean all packages
```

## Environment Requirements

- **Dart SDK**: ^3.6.0
- **Melos**: Latest (install via `dart pub global activate melos`)

## Architecture

**8-Level Layered Dependency System** - packages can only depend on lower-level packages (no circular dependencies):

| Level | Purpose | Packages |
|-------|---------|----------|
| 0 | Core Primitives | `core` |
| 1 | Cryptography & Encoding | `crypto`, `abi` |
| 2 | Connectivity & Identity | `provider`, `signer`, `chains` |
| 3 | Client & Interaction | `client`, `contract`, `events` |
| 4 | Services & Queries | `multicall`, `ens`, `history`, `price` |
| 5 | Advanced Features | `aa`, `reown`, `swap`, `bridge`, `nft`, `staking`, `debug`, `mev` |
| 6 | Hardware Wallets | `bc_ur`, `keystone`, `ledger`, `trezor`, `mpc` (in `packages/hardware/`) |
| 7 | Chain Extensions | `solana`, `polkadot`, `bitcoin`, `ton`, `tron` (in `packages/extensions/`) |

**Key Design Principles:**
- Pure Dart implementation - no FFI, C++, or Rust bindings
- Each package is independently publishable and usable
- Strict type safety with `strict-casts`, `strict-inference`, `strict-raw-types` enabled

## Code Style

- Use `require_trailing_commas` for all argument lists
- Prefer `prefer_single_quotes`
- Declare return types on all functions (`always_declare_return_types`)
- Avoid dynamic calls (`avoid_dynamic_calls`)
- Use `prefer_final_locals` and `prefer_final_in_for_each`
- Close subscriptions and sinks properly (`cancel_subscriptions`, `close_sinks`)

## Testing

- Test files: `packages/*/test/*_test.dart`
- Property-based testing: Use `glados` package for randomized property tests
- Target >80% code coverage
- Follow TDD: Red (failing test) → Green (minimal implementation) → Refactor
- CI runs core packages sequentially with fail-fast (see `.github/workflows/ci.yml`)

## Package Naming

All packages use the prefix `dart_web3_`:
- Import: `package:dart_web3_core/dart_web3_core.dart`
- Dependency: `dart_web3_core: ^0.1.0`

## Key Blockchain Standards Implemented

- EIP-1559 (fee market), EIP-4844 (blob transactions)
- EIP-712 (typed data signing), EIP-7702 (EOA code delegation)
- ERC-4337 (account abstraction)
- BIP-32/39/44 (HD wallets)
- RLP encoding/decoding

## Workflow

Development follows TDD with task tracking in `conductor/plan.md`. Commit message format:
```
<type>(<scope>): <description>
# Types: feat, fix, docs, style, refactor, test, chore
```

## Key Package Responsibilities

| Package | Core Exports |
|---------|--------------|
| `core` | `Address`, `Bytes`, `Hex`, `RLP`, `EthUnit` |
| `crypto` | `secp256k1`, `keccak256`, HD wallet derivation |
| `abi` | `AbiCoder`, `AbiFunction`, `AbiEvent` |
| `provider` | `HttpProvider`, `WebSocketProvider` |
| `signer` | `PrivateKeySigner`, `Signer` abstract class |
| `client` | `PublicClient`, `WalletClient`, `ClientFactory` |
| `contract` | `Contract`, typed contract interactions |

## Adding a New Package

1. Create directory under appropriate level in `packages/`
2. Follow naming: `dart_web3_<name>`
3. Only depend on lower-level packages
4. Add to `melos.yaml` workspace if needed (usually auto-discovered)
5. Run `melos bootstrap` to link
