# Dart Web3 SDK Usage Guide

This guide provides deep dives into using the Dart Web3 SDK effectively for various blockchain development tasks.

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Wallet Management](#wallet-management)
3. [Connecting to Blockchain](#connecting-to-blockchain)
4. [Smart Contract Interaction](#smart-contract-interaction)
5. [Account Abstraction (ERC-4337)](#account-abstraction)
6. [Multi-Chain Extensions](#multi-chain)

---

<a name="core-concepts"></a>
## 1. Core Concepts

The SDK is built on a **Layered Architecture (v0-v7)**.
- **Layers 0-1**: Foundational data types, RLP, and cryptography.
- **Layer 2-3**: Connectivity (Providers) and basic interactions (Clients).
- **Layer 4-5**: High-level features like ENS, AA, and DEX swaps.
- **Layer 6-7**: Hardware wallets and non-EVM chain extensions.

---

<a name="wallet-management"></a>
## 2. Wallet Management

### Creating an HD Wallet
Using the `HDWallet` class from `dart_web3_crypto`:

```dart
final mnemonic = Bip39.generate();
final hdWallet = HDWallet.fromMnemonic(mnemonic);

// Derive default Ethereum account
final ethAccount = hdWallet.derivePath("m/44'/60'/0'/0/0");
print('Address: ${ethAccount.address}');
```

### Private Key Signer
Used for signing transactions and messages:

```dart
final signer = PrivateKeySigner(hdWallet.privateKey, 1); // 1 = Mainnet
final signature = await signer.signMessage("Verify me");
```

---

<a name="connecting-to-blockchain"></a>
## 3. Connecting to Blockchain

### Public Client (Read-only)
Use `PublicClient` for querying state:

```dart
final client = ClientFactory.createPublicClient(
  rpcUrl: 'https://eth.llamarpc.com',
  chain: Chains.ethereum,
);

final balance = await client.getBalance('0x...');
```

---

<a name="smart-contract-interaction"></a>
## 4. Smart Contract Interaction

### Using Built-in Contract Helpers
We provide wrappers for common standards:

```dart
final usdt = ERC20Contract(address: '0x...', publicClient: client);
final balance = await usdt.balanceOf('0x...');
```

### Generic Contract Calls
For custom contracts:

```dart
final contract = DeployedContract(abi: myAbi, address: '0x...');
final result = await contract.call('myFunction', [arg1, arg2]);
```

---

<a name="account-abstraction"></a>
## 5. Account Abstraction (ERC-4337)

The SDK fully supports EIP-4337 focusing on `UserOperations`:

```dart
final smartAccount = SimpleAccount(owner: signer, factoryAddress: '0x...');
final userOp = await smartAccount.createUnsignedUserOp(callData: ...);
```

---

<a name="multi-chain"></a>
## 6. Multi-Chain Extensions

Extensions provide native-like support for other chains:

```dart
// Solana Example
final solanaClient = SolanaClient(rpcUrl: '...');
final balance = await solanaClient.getBalance('SolanaAddress...');

// Bitcoin Example
final bitcoinAddress = BitcoinAddress.fromPublicKey(pubKey, network: BitcoinNetwork.mainnet);
```

---

For complete runnable code, see the [example/](example/) directory.
