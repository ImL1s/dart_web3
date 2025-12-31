# Requirements Document

## Introduction

本文件定義了 Dart Web3 SDK 的需求規格，目標是打造一個功能完備、模組化的 Dart 原生 Web3 SDK，以替代 ethers.js/viem 成為 Dart/Flutter 領域的首選方案。基於現有 Dart Web3 生態系統的功能缺口調查，並結合 2024-2025 年最新的區塊鏈標準，本 SDK 將涵蓋核心通訊、簽名、ABI 編碼、合約互動等關鍵功能。

**設計原則：**
- **模組化架構**：每個功能模組可獨立引用，減少不必要的依賴
- **多鏈支援**：核心模組支援 EVM 兼容鏈，並提供擴展點支援其他鏈
- **純 Dart 實現**：無外部原生依賴，支援所有 Dart/Flutter 平台

**現有生態系統狀態（2025年更新）：**
- `web3dart` 已於 2022 年停止維護
- `webthree` 是活躍維護的 fork，支援 WalletConnect 和 MetaMask
- `WalletConnectFlutterV2` 已被棄用，需使用 Reown 套件
- EIP-4844 (Blob Transactions) 於 2024 年 3 月 Dencun 升級後啟用
- EIP-7702 (EOA Code Delegation) 於 2025 年 5 月 Pectra 升級後啟用

**可借鑑的純 Dart 套件（MRTNetwork 生態系統，BSD-3-Clause 授權）：**
- `blockchain_utils` - 跨鏈密碼學基礎（BIP32/39/44、多曲線、編碼）
- `bitcoin_base` - Bitcoin/Dogecoin/Litecoin/BCH/Dash 交易支援
- `polkadot_dart` - Polkadot/Substrate 完整支援（SCALE 編碼、SR25519）
- `on_chain` - Ethereum/Tron/Solana/Cardano/Aptos/Sui 多鏈支援

**其他純 Dart 套件：**
- `solana` (Espresso Cash) - Solana 鏈支援
- `polkadart` - Polkadot 官方推薦的 Dart SDK

**支援的區塊鏈：**
- **EVM 兼容鏈**（核心支援）：Ethereum、Polygon、BSC、Arbitrum、Optimism、Base、Avalanche C-Chain
- **非 EVM 鏈**（擴展模組）：Solana、Polkadot/Substrate、Tron、TON、Bitcoin

## Glossary

- **SDK**: Software Development Kit，軟體開發套件
- **RPC_Provider**: 與區塊鏈節點通訊的客戶端，負責發送 JSON-RPC 請求
- **Signer**: 簽名器，負責交易和訊息簽名的抽象介面
- **Credentials**: 簽名憑證，包含私鑰及簽署行為的抽象類別
- **ABI**: Application Binary Interface，智能合約的應用程式二進位介面
- **EIP**: Ethereum Improvement Proposal，以太坊改進提案
- **EVM**: Ethereum Virtual Machine，以太坊虛擬機
- **PublicClient**: 公共客戶端，僅提供區塊鏈讀取功能，不涉及私鑰
- **WalletClient**: 錢包客戶端，綁定帳戶並可發送交易、簽署訊息
- **TypedData**: EIP-712 定義的結構化資料格式
- **ChainConfig**: 鏈網路配置，包含 chainId、RPC URL、區塊瀏覽器等資訊
- **Multicall**: 在單一 RPC 請求中執行多個合約只讀調用的方案
- **Reown_Client**: Reown（原 WalletConnect）客戶端，用於連接外部錢包
- **UserOperation**: ERC-4337 定義的用戶操作對象，用於帳戶抽象
- **Bundler**: ERC-4337 中負責打包 UserOperation 的節點
- **Paymaster**: ERC-4337 中負責代付 gas 費用的合約
- **EIP-7702_Transaction**: EIP-7702 定義的 Type 4 交易，允許 EOA 臨時委託智能合約代碼執行
- **Authorization_List**: EIP-7702 中的授權列表，包含 chainId、address、nonce 和簽名
- **Blob_Transaction**: EIP-4844 定義的 Type 3 交易，用於 L2 數據可用性
- **Package**: Dart 套件，可獨立發布和引用的模組單元
- **BC-UR**: Blockchain Commons Uniform Resources，用於 QR 碼數據交換的標準協議
- **PSBT**: Partially Signed Bitcoin Transaction，部分簽名的比特幣交易格式
- **HardwareWallet_Signer**: 硬體錢包簽名器，透過外部設備進行安全簽名
- **DEX_Aggregator**: 去中心化交易所聚合器，整合多個 DEX 獲取最佳價格
- **Bridge_Service**: 跨鏈橋接服務，用於在不同區塊鏈間轉移資產
- **NFT_Service**: NFT 服務，管理 ERC-721/ERC-1155 代幣
- **Staking_Service**: 質押服務，管理資產質押和獎勵
- **ENS_Service**: 以太坊域名服務，解析人類可讀地址
- **Inscription**: Bitcoin Ordinals 銘文，刻在聰上的數據
- **BRC-20**: 基於 Ordinals 的比特幣代幣標準
- **Runes**: Bitcoin 上的可替代代幣協議
- **DApp_Browser**: DApp 瀏覽器，注入 Web3 Provider 與 DApp 互動
- **EIP-1193**: 以太坊 Provider JavaScript API 標準
- **EIP-6963**: 多注入 Provider 發現標準

## Package Structure

SDK 採用 monorepo 結構，每個套件可獨立引用。依賴關係設計為最小化，確保開發者只需引入所需模組。

### 依賴層級圖

```
Level 0 (無依賴):
  └── core/                      # 核心工具（地址、BigInt、編碼、RLP）

Level 1 (僅依賴 core):
  ├── crypto/                    # 密碼學模組（secp256k1、keccak、BIP）
  └── abi/                       # ABI 編碼/解碼

Level 2 (依賴 Level 0-1):
  ├── provider/                  # RPC Provider（HTTP/WebSocket）
  ├── signer/                    # 簽名器抽象與實現
  └── chains/                    # 鏈配置

Level 3 (依賴 Level 0-2):
  ├── client/                    # PublicClient/WalletClient
  ├── contract/                  # 合約抽象
  └── events/                    # 事件訂閱

Level 4 (獨立服務模組，可選依賴):
  ├── multicall/                 # Multicall 支援
  ├── ens/                       # ENS 域名解析
  ├── history/                   # 交易歷史服務
  └── price/                     # 價格服務

Level 5 (進階功能模組，可選依賴):
  ├── aa/                        # ERC-4337 Account Abstraction
  ├── reown/                     # Reown/WalletConnect 整合
  ├── swap/                      # DEX 聚合與 Swap
  ├── bridge/                    # 跨鏈橋接
  ├── nft/                       # NFT 服務
  ├── staking/                   # Staking 服務
  ├── dapp/                      # DApp 瀏覽器
  ├── debug/                     # 交易模擬與調試 API
  └── mev/                       # MEV 保護與 Flashbots

Level 6 (硬體錢包，獨立模組):
  └── hardware/
      ├── bc_ur/                 # BC-UR 協議（無其他依賴）
      ├── keystone/              # Keystone QR 通訊
      ├── ledger/                # Ledger USB/BLE
      ├── trezor/                # Trezor WebUSB
      └── mpc/                   # MPC 錢包支援

Level 7 (鏈擴展，獨立模組):
  └── extensions/
      ├── solana/                # Solana 擴展
      ├── polkadot/              # Polkadot/Substrate 擴展
      ├── tron/                  # Tron 擴展
      ├── ton/                   # TON 擴展
      └── bitcoin/               # Bitcoin 擴展
          └── inscriptions/      # Ordinals/BRC-20/Runes
```

### 目錄結構

```
dart_web3/
├── packages/
│   ├── core/                    # 核心工具（地址、BigInt、編碼）
│   ├── crypto/                  # 密碼學模組（secp256k1、keccak、BIP）
│   ├── abi/                     # ABI 編碼/解碼
│   ├── provider/                # RPC Provider（HTTP/WebSocket）
│   ├── signer/                  # 簽名器抽象與實現
│   ├── client/                  # PublicClient/WalletClient
│   ├── contract/                # 合約抽象與代碼生成
│   ├── chains/                  # 鏈配置
│   ├── multicall/               # Multicall 支援
│   ├── events/                  # 事件訂閱
│   ├── reown/                   # Reown/WalletConnect 整合
│   ├── aa/                      # ERC-4337 Account Abstraction
│   ├── hardware/                # 硬體錢包整合（Keystone、Ledger、Trezor）
│   │   ├── bc_ur/               # BC-UR 協議編碼/解碼
│   │   ├── keystone/            # Keystone QR 通訊
│   │   ├── ledger/              # Ledger USB/BLE 通訊
│   │   ├── trezor/              # Trezor WebUSB 通訊
│   │   └── mpc/                 # MPC 錢包支援
│   ├── swap/                    # DEX 聚合與 Swap 服務
│   ├── bridge/                  # 跨鏈橋接服務
│   ├── nft/                     # NFT 服務
│   ├── staking/                 # Staking 服務
│   ├── ens/                     # ENS 與域名解析
│   ├── history/                 # 交易歷史服務
│   ├── price/                   # 價格服務與市場數據
│   ├── dapp/                    # DApp 瀏覽器支援
│   ├── debug/                   # 交易模擬與調試 API
│   ├── mev/                     # MEV 保護與 Flashbots
│   └── extensions/              # 非 EVM 鏈擴展
│       ├── solana/
│       ├── polkadot/
│       ├── tron/
│       ├── ton/
│       └── bitcoin/
│           └── inscriptions/    # Ordinals/BRC-20/Runes
├── dart_web3/                   # Meta-package（重新導出所有模組）
└── example/                     # 範例應用
```

### 使用範例

```dart
// 只需要核心功能
import 'package:dart_web3_core/dart_web3_core.dart';

// 只需要密碼學
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

// 只需要 ABI 編碼
import 'package:dart_web3_abi/dart_web3_abi.dart';

// 需要完整 EVM 功能
import 'package:dart_web3_client/dart_web3_client.dart';

// 只需要 Swap 功能
import 'package:dart_web3_swap/dart_web3_swap.dart';

// 只需要 Keystone 硬體錢包
import 'package:dart_web3_keystone/dart_web3_keystone.dart';

// 需要所有功能（meta-package）
import 'package:dart_web3/dart_web3.dart';
```

## Reference Packages Analysis

以下是可借鑑的純 Dart 套件分析：

| 套件 | 功能範圍 | 純 Dart | 授權 | 借鑑價值 |
|------|----------|---------|------|----------|
| `blockchain_utils` | 密碼學、編碼、BIP 標準 | ✅ | BSD-3-Clause | ⭐⭐⭐⭐⭐ |
| `bitcoin_base` | Bitcoin 系列交易 | ✅ | BSD-3-Clause | ⭐⭐⭐⭐⭐ |
| `polkadot_dart` | Substrate 完整支援 | ✅ | BSD-3-Clause | ⭐⭐⭐⭐⭐ |
| `on_chain` | 多鏈（ETH/Tron/Solana/Cardano） | ✅ | BSD-3-Clause | ⭐⭐⭐⭐⭐ |
| `webthree` | EVM 基礎功能 | ✅ | MIT | ⭐⭐⭐⭐ |
| `solana` | Solana 專用 | ✅ | Apache-2.0 | ⭐⭐⭐⭐ |
| `polkadart` | Polkadot 官方推薦 | ✅ | Apache-2.0 | ⭐⭐⭐⭐ |

**借鑑策略：**
1. **密碼學模組**：參考 `blockchain_utils` 的純 Dart 實現
2. **EVM 交易**：參考 `on_chain` 的 EIP-1559/EIP-712 實現
3. **Bitcoin 系列**：參考 `bitcoin_base` 的交易構建
4. **Substrate**：參考 `polkadot_dart` 的 SCALE 編碼和 SR25519
5. **Solana**：參考 `solana` 套件的 Program 交互

## Cloned Reference Projects

已 clone 到 `references/` 目錄的參考專案：

### 純 Dart 參考（references/dart/）
| 專案 | 路徑 | 用途 |
|------|------|------|
| blockchain_utils | `references/dart/blockchain_utils` | 密碼學、編碼、BIP 標準 |
| bitcoin_base | `references/dart/bitcoin_base` | Bitcoin 系列交易 |
| on_chain | `references/dart/on_chain` | ETH/Tron/Solana/Cardano 多鏈 |
| polkadot_dart | `references/dart/polkadot_dart` | Substrate 完整支援 |
| polkadart | `references/dart/polkadart` | Polkadot 官方推薦 SDK |
| solana | `references/dart/solana` | Solana (Espresso Cash) |
| webthree | `references/dart/webthree` | EVM 基礎功能 |

### TypeScript 參考（references/typescript/）- Dart 生態缺少的功能
| 專案 | 路徑 | 用途 |
|------|------|------|
| viem | `references/typescript/viem` | 現代 EVM 庫架構參考 |
| ethers | `references/typescript/ethers` | 經典 EVM 庫參考 |
| walletconnect | `references/typescript/walletconnect` | WalletConnect v2 協議 |
| reown-appkit | `references/typescript/reown-appkit` | Reown AppKit 實現 |
| account-abstraction-4337 | `references/typescript/account-abstraction-4337` | ERC-4337 官方實現 |
| permissionless | `references/typescript/permissionless` | ERC-4337 SDK |
| permit2 | `references/typescript/permit2` | Uniswap Permit2 |
| multicall | `references/typescript/multicall` | Multicall 合約 |

### Rust 參考（references/rust/）- 高性能實現參考
| 專案 | 路徑 | 用途 |
|------|------|------|
| alloy | `references/rust/alloy` | 現代 Rust Ethereum SDK |
| alloy-core | `references/rust/alloy-core` | Alloy 核心類型和編碼 |
| reth | `references/rust/reth` | Rust Ethereum 客戶端（Trace/Debug API） |

### Python 參考（references/python/）- MEV 和 Flashbots
| 專案 | 路徑 | 用途 |
|------|------|------|
| web3py | `references/python/web3py` | 官方 Python SDK |
| web3-flashbots | `references/python/web3-flashbots` | Flashbots 整合 |

### Go 參考（references/go/）- 調試和追蹤 API
| 專案 | 路徑 | 用途 |
|------|------|------|
| go-ethereum | `references/go/go-ethereum` | 官方 Go 客戶端（Debug/Trace Namespace） |

### TypeScript 參考（references/typescript/）- Dart 生態缺少的功能
| 專案 | 路徑 | 用途 |
|------|------|------|
| viem | `references/typescript/viem` | 現代 EVM 庫架構參考 |
| ethers | `references/typescript/ethers` | 經典 EVM 庫參考 |
| walletconnect | `references/typescript/walletconnect` | WalletConnect v2 協議 |
| reown-appkit | `references/typescript/reown-appkit` | Reown AppKit 實現 |
| account-abstraction-4337 | `references/typescript/account-abstraction-4337` | ERC-4337 官方實現 |
| permissionless | `references/typescript/permissionless` | ERC-4337 SDK |
| permit2 | `references/typescript/permit2` | Uniswap Permit2 |
| multicall | `references/typescript/multicall` | Multicall 合約 |

## TypeScript 參考專案借鑑分析

以下是 Dart 生態系統缺少的功能，需要從 TypeScript 專案借鑑並翻譯成純 Dart 實現：

### viem（現代 EVM 庫架構）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| PublicClient/WalletClient 分離 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 4 |
| 類型安全的 Actions API | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 4, 5 |
| EIP-7702 支援 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 15 |
| EIP-4844 Blob 交易 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 2 |
| Chain 配置系統 | 部分 | ⭐⭐⭐⭐ | Req 7 |
| Transport 抽象 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 1 |
| Middleware 系統 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 1 |
| ENS 整合 | 部分 | ⭐⭐⭐⭐ | Req 22 |
| SIWE (Sign-In with Ethereum) | ❌ 缺少 | ⭐⭐⭐⭐ | Req 10 |

**借鑑重點：**
- `src/clients/` - PublicClient/WalletClient 架構
- `src/actions/` - 類型安全的區塊鏈操作
- `src/chains/` - 鏈配置系統
- `src/experimental/eip7702/` - EIP-7702 實現
- `src/experimental/eip4844/` - Blob 交易支援

### ethers.js（經典 EVM 庫）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| Provider 抽象 | 部分 | ⭐⭐⭐⭐ | Req 1 |
| Signer 抽象 | 部分 | ⭐⭐⭐⭐ | Req 2 |
| Contract 工廠 | 部分 | ⭐⭐⭐⭐ | Req 5 |
| ABI 編碼器 | ✅ 有 | ⭐⭐⭐ | Req 3 |
| HDNode (BIP-32/39/44) | ✅ 有 | ⭐⭐⭐ | Req 8 |

**借鑑重點：**
- `src/providers/` - Provider 架構設計
- `src/signers/` - Signer 抽象層
- `src/contract/` - Contract 工廠模式

### permissionless（ERC-4337 SDK）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| UserOperation 構建 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| Bundler 客戶端 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| Paymaster 整合 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| Smart Account 抽象 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| EntryPoint v0.6/v0.7 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| Gas 估算 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 11 |

**借鑑重點：**
- `packages/permissionless/src/accounts/` - Smart Account 實現
- `packages/permissionless/src/actions/` - UserOperation 操作
- `packages/permissionless/src/clients/` - Bundler/Paymaster 客戶端

### account-abstraction-4337（ERC-4337 官方實現）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| EntryPoint 合約 ABI | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| SimpleAccount 實現 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| UserOperation 結構 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |
| Bundler RPC 規範 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 11 |

**借鑑重點：**
- `contracts/` - EntryPoint 和 Account 合約 ABI
- `sdk/` - SDK 實現參考

### walletconnect / reown-appkit（WalletConnect v2）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| WalletConnect v2 協議 | 部分（已棄用） | ⭐⭐⭐⭐⭐ | Req 10 |
| Relay 協議 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 10 |
| Session 管理 | 部分 | ⭐⭐⭐⭐ | Req 10 |
| Namespace 配置 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 10 |
| One-Click Auth | ❌ 缺少 | ⭐⭐⭐⭐ | Req 10 |
| SIWE 整合 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 10 |

**借鑑重點：**
- `packages/core/` - 核心協議實現
- `packages/sign-client/` - 簽名客戶端
- `packages/auth-client/` - 認證客戶端

### multicall（Multicall 合約）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| Multicall2 支援 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 9 |
| Multicall3 支援 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 9 |
| 批次調用編碼 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 9 |
| 結果解碼 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 9 |

**借鑑重點：**
- `src/` - Multicall 合約 ABI 和調用邏輯

### permit2（Uniswap Permit2）
| 功能 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|-----------|----------|----------|
| Permit2 簽名 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 17 |
| 批量授權 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 17 |
| SignatureTransfer | ❌ 缺少 | ⭐⭐⭐⭐ | Req 17 |

**借鑑重點：**
- `src/` - Permit2 合約 ABI 和簽名邏輯

## 借鑑優先級

### P0 - 核心功能（必須從 TypeScript 借鑑）
1. **viem** - PublicClient/WalletClient 架構、EIP-7702、EIP-4844
2. **permissionless** - ERC-4337 完整實現
3. **walletconnect** - WalletConnect v2 協議

### P1 - 重要功能
4. **multicall** - Multicall2/3 支援
5. **account-abstraction-4337** - EntryPoint 合約 ABI
6. **ethers** - Provider/Signer 設計參考

### P2 - 增強功能
7. **permit2** - Permit2 簽名支援
8. **reown-appkit** - One-Click Auth、SIWE

## Dart 生態缺少但其他語言有優秀實現的功能

以下功能在 Rust、Go、Python 等語言有成熟實現，但 Dart 生態完全缺失，需要從這些語言借鑑：

### Rust 生態（alloy / ethers-rs）
| 功能 | 說明 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|------|-----------|----------|----------|
| **sol! 宏** | 編譯時 ABI 類型生成 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | Req 5 |
| **Trace API 支援** | debug_traceTransaction, debug_traceCall | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **State Override** | eth_call 狀態覆蓋 | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **Transaction Simulation** | eth_simulateV1 交易模擬 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | 新增 Req 26 |
| **YubiHSM2 支援** | 硬體安全模組簽名 | ❌ 缺少 | ⭐⭐⭐ | Req 16 |
| **Middleware 鏈** | 可組合的請求處理 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 1 |

**借鑑來源：**
- `alloy-rs/core` - 高性能 Ethereum 核心庫
- `alloy-rs/alloy` - 完整 Ethereum SDK
- `paradigmxyz/reth` - Rust Ethereum 客戶端

### Python 生態（web3.py）
| 功能 | 說明 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|------|-----------|----------|----------|
| **Flashbots 整合** | MEV 保護、Bundle 提交 | ❌ 缺少 | ⭐⭐⭐⭐⭐ | 新增 Req 27 |
| **Private Transaction** | 私密交易提交 | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 27 |
| **Bundle Simulation** | Bundle 模擬執行 | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 27 |
| **Async Provider** | 非同步 Provider 支援 | 部分 | ⭐⭐⭐ | Req 1 |
| **Middleware 系統** | 可插拔中間件 | ❌ 缺少 | ⭐⭐⭐⭐ | Req 1 |

**借鑑來源：**
- `ethereum/web3.py` - 官方 Python SDK
- `flashbots/web3-flashbots` - Flashbots 插件

### Go 生態（go-ethereum / geth）
| 功能 | 說明 | Dart 現狀 | 借鑑價值 | 對應需求 |
|------|------|-----------|----------|----------|
| **Debug Namespace** | 完整調試 API | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **Trace Namespace** | 交易追蹤 API | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **State Diff** | 狀態差異追蹤 | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **EVM Tracer** | 操作碼級別追蹤 | ❌ 缺少 | ⭐⭐⭐⭐ | 新增 Req 26 |
| **Fork Testing** | 本地分叉測試 | ❌ 缺少 | ⭐⭐⭐ | 新增 Req 26 |

**借鑑來源：**
- `ethereum/go-ethereum` - 官方 Go 客戶端
- Geth RPC 文檔

### 其他語言優秀功能
| 功能 | 來源語言 | 說明 | Dart 現狀 | 借鑑價值 |
|------|----------|------|-----------|----------|
| **ZK Proof 生成** | Rust/C++ | 零知識證明 | ❌ 缺少 | ⭐⭐⭐ |
| **MPC 錢包** | Rust/Go | 多方計算簽名 | ❌ 缺少 | ⭐⭐⭐⭐ |
| **Threshold Signatures** | Rust | 門限簽名 | ❌ 缺少 | ⭐⭐⭐ |
| **Account Abstraction SDK** | TypeScript | 完整 AA 工具鏈 | ❌ 缺少 | ⭐⭐⭐⭐⭐ |
| **Intent-Based Transactions** | TypeScript | 意圖交易 | ❌ 缺少 | ⭐⭐⭐ |

## Requirements

### Requirement 1: RPC Provider 實現

**User Story:** As a developer, I want to communicate with blockchain nodes through a reliable RPC provider, so that I can query chain data and send transactions.

#### Acceptance Criteria

1. WHEN a developer creates an RPC_Provider with an HTTP URL, THE RPC_Provider SHALL establish a connection and support JSON-RPC method calls
2. WHEN a developer creates an RPC_Provider with a WebSocket URL, THE RPC_Provider SHALL establish a persistent connection and support subscriptions
3. WHEN multiple RPC calls are batched together, THE RPC_Provider SHALL send them in a single HTTP request and return all results
4. WHEN a middleware is registered, THE RPC_Provider SHALL execute the middleware before and after each RPC call
5. WHEN an RPC call fails, THE RPC_Provider SHALL return an error containing the error code, message, and data from the node
6. WHEN a WebSocket connection is lost, THE RPC_Provider SHALL attempt automatic reconnection with configurable retry logic
7. WHEN a custom transport is provided, THE RPC_Provider SHALL use it for all communications

### Requirement 2: 交易簽名與 Signer 架構

**User Story:** As a developer, I want a unified signer interface for signing transactions and messages, so that I can support various signing methods consistently.

#### Acceptance Criteria

1. THE Signer SHALL provide a signTransaction method that accepts transaction parameters and returns a signed transaction
2. THE Signer SHALL provide a signMessage method that accepts a message and returns an Ethereum personal signature
3. THE Signer SHALL provide a signTypedData method that accepts EIP-712 TypedData and returns a signature
4. WHEN signing a Legacy transaction, THE Signer SHALL produce a valid signature with R, S, V values and chainId protection (EIP-155)
5. WHEN signing an EIP-1559 transaction, THE Signer SHALL correctly encode maxFeePerGas and maxPriorityFeePerGas fields
6. WHEN signing an EIP-2930 transaction, THE Signer SHALL correctly encode the access list
7. WHEN signing an EIP-4844 blob transaction, THE Signer SHALL correctly encode blobVersionedHashes, maxFeePerBlobGas, and blob sidecar data
8. WHEN signing an EIP-7702 transaction, THE Signer SHALL correctly encode the authorization list containing chainId, address, nonce, and signature (yParity, r, s)
9. WHEN a private key is provided, THE Signer SHALL create an EthPrivateKey credential for signing
10. WHEN a mnemonic phrase is provided, THE Signer SHALL derive the private key using BIP-39/BIP-44 standards

### Requirement 3: ABI 編碼與解碼

**User Story:** As a developer, I want to encode and decode smart contract data according to the ABI specification, so that I can interact with contracts correctly.

#### Acceptance Criteria

1. WHEN encoding function call data, THE ABI_Encoder SHALL produce correctly padded bytes according to the Solidity ABI specification
2. WHEN decoding function return data, THE ABI_Decoder SHALL parse the bytes into the correct Dart types
3. THE ABI_Encoder SHALL support all standard Solidity types: uint, int, address, bool, bytes, string, arrays, and tuples
4. WHEN encoding dynamic types (string, bytes, dynamic arrays), THE ABI_Encoder SHALL correctly calculate offsets and lengths
5. WHEN encoding nested structs and arrays, THE ABI_Encoder SHALL handle arbitrary nesting depth
6. WHEN encoding EIP-712 TypedData, THE ABI_Encoder SHALL produce the correct domain separator and struct hash
7. WHEN parsing an ABI JSON, THE ABI_Parser SHALL extract function signatures, event signatures, and error definitions
8. THE Pretty_Printer SHALL format ABI-encoded data back into human-readable representation
9. FOR ALL valid ABI-encoded data, decoding then encoding SHALL produce equivalent bytes (round-trip property)

### Requirement 4: Public/Wallet Client 架構

**User Story:** As a developer, I want separate interfaces for read and write operations, so that I can clearly distinguish between operations that require signing and those that don't.

#### Acceptance Criteria

1. THE PublicClient SHALL provide read-only methods for querying blockchain state without requiring a private key
2. THE PublicClient SHALL support getBalance, getBlock, getTransaction, getTransactionReceipt, call, and estimateGas methods
3. THE WalletClient SHALL extend PublicClient functionality and add transaction signing capabilities
4. WHEN a WalletClient is created, THE WalletClient SHALL require an account (Signer) to be associated
5. THE WalletClient SHALL provide sendTransaction, signMessage, and signTypedData methods
6. WHEN switching accounts, THE WalletClient SHALL allow changing the associated Signer without recreating the client
7. WHEN switching networks, THE PublicClient SHALL allow changing the RPC_Provider without recreating the client

### Requirement 5: 合約抽象工具

**User Story:** As a developer, I want to interact with smart contracts using type-safe interfaces, so that I can avoid manual ABI encoding errors.

#### Acceptance Criteria

1. WHEN a contract ABI is provided, THE Contract_Factory SHALL create a contract instance with typed methods
2. THE Contract instance SHALL provide methods matching each function in the ABI
3. WHEN calling a read-only contract method, THE Contract SHALL use the PublicClient to execute the call
4. WHEN calling a state-changing contract method, THE Contract SHALL use the WalletClient to send a transaction
5. WHEN a contract event is defined in the ABI, THE Contract SHALL provide a method to create event filters
6. WHEN decoding event logs, THE Contract SHALL parse indexed and non-indexed parameters correctly
7. IF a contract method call fails, THEN THE Contract SHALL return the decoded error message if available

### Requirement 6: 事件訂閱

**User Story:** As a developer, I want to subscribe to smart contract events, so that I can react to on-chain activities in real-time.

#### Acceptance Criteria

1. WHEN subscribing to events with a filter, THE Event_Subscriber SHALL return a Stream of matching events
2. THE Event_Subscriber SHALL support filtering by contract address, event topics, and block range
3. WHEN using WebSocket transport, THE Event_Subscriber SHALL receive events via eth_subscribe
4. WHEN using HTTP transport, THE Event_Subscriber SHALL poll for new events at a configurable interval
5. WHEN a chain reorganization occurs, THE Event_Subscriber SHALL emit events with a removed flag for invalidated logs
6. WHEN confirmation count is specified, THE Event_Subscriber SHALL only emit events after the specified number of block confirmations

### Requirement 7: Chain Config 管理

**User Story:** As a developer, I want pre-configured chain information for common networks, so that I can easily switch between networks without manual configuration.

#### Acceptance Criteria

1. THE ChainConfig SHALL provide pre-configured data for Ethereum Mainnet, Goerli, Sepolia, Polygon, BSC, Arbitrum, and Optimism
2. THE ChainConfig SHALL include chainId, network name, native currency symbol, and block explorer URL for each chain
3. THE ChainConfig SHALL provide default RPC URL templates for common providers (Infura, Alchemy)
4. WHEN a custom chain is needed, THE ChainConfig SHALL allow developers to register new chain configurations
5. WHEN querying chain config by chainId, THE ChainConfig SHALL return the matching configuration or null if not found

### Requirement 8: 基礎密碼學

**User Story:** As a developer, I want reliable cryptographic primitives for Ethereum operations, so that I can perform secure signing and hashing.

#### Acceptance Criteria

1. THE Crypto_Module SHALL provide secp256k1 elliptic curve operations for signing and public key recovery
2. THE Crypto_Module SHALL provide Keccak-256 hashing function for Ethereum address derivation and message hashing
3. THE Crypto_Module SHALL provide BIP-39 mnemonic generation and seed derivation
4. THE Crypto_Module SHALL provide BIP-32/BIP-44 hierarchical deterministic key derivation
5. WHEN generating random values, THE Crypto_Module SHALL use cryptographically secure random number generation
6. FOR ALL valid private keys, signing then recovering the public key SHALL return the original public key (round-trip property)

### Requirement 9: Multicall 支援

**User Story:** As a developer, I want to batch multiple contract read calls into a single RPC request, so that I can reduce latency and improve performance.

#### Acceptance Criteria

1. WHEN multiple contract calls are provided, THE Multicall SHALL encode them into a single multicall contract call
2. THE Multicall SHALL decode the aggregated results back into individual call results
3. WHEN a call in the batch fails, THE Multicall SHALL return the failure status for that specific call without failing the entire batch
4. THE Multicall SHALL support both Multicall2 and Multicall3 contract interfaces
5. WHEN the target chain has a deployed Multicall contract, THE Multicall SHALL use the correct contract address from ChainConfig

### Requirement 10: Reown (WalletConnect v2) 支援

**User Story:** As a Flutter developer, I want to connect my app to mobile wallets via Reown (formerly WalletConnect), so that users can sign transactions with their preferred wallet.

#### Acceptance Criteria

1. WHEN initiating a Reown session, THE Reown_Client SHALL generate a valid pairing URI for QR code display
2. THE Reown_Client SHALL handle the WalletConnect v2 relay protocol for session establishment
3. WHEN a session is established, THE Reown_Client SHALL provide a Signer implementation for transaction signing
4. THE Reown_Client SHALL support namespace configuration for specifying supported chains and methods
5. WHEN the wallet approves a signing request, THE Reown_Client SHALL return the signature to the application
6. WHEN the session is disconnected, THE Reown_Client SHALL emit a disconnect event and clean up resources
7. IF the relay connection is lost, THEN THE Reown_Client SHALL attempt automatic reconnection
8. THE Reown_Client SHALL support One-Click Auth for combined session proposal and SIWE authentication

### Requirement 11: ERC-4337 Account Abstraction 支援

**User Story:** As a developer, I want to support smart contract wallets using ERC-4337, so that users can benefit from gasless transactions and advanced wallet features.

#### Acceptance Criteria

1. THE AA_Client SHALL provide methods to construct UserOperation objects according to ERC-4337 specification
2. WHEN a UserOperation is created, THE AA_Client SHALL calculate the correct userOpHash
3. THE AA_Client SHALL support communication with Bundler nodes via JSON-RPC
4. WHEN a Paymaster is configured, THE AA_Client SHALL include paymaster data in the UserOperation
5. THE AA_Client SHALL support both SimpleAccount and LightAccount smart account types
6. WHEN estimating gas for a UserOperation, THE AA_Client SHALL call the bundler's estimation methods
7. THE AA_Client SHALL support EntryPoint v0.6 and v0.7 interfaces

### Requirement 12: 模組化套件架構

**User Story:** As a developer, I want to import only the modules I need, so that I can minimize my application's bundle size and dependencies.

#### Acceptance Criteria

1. THE SDK SHALL be organized as a monorepo with independently publishable packages
2. WHEN a developer imports a specific package, THE Package SHALL only bring in its direct dependencies
3. THE core package SHALL have zero external dependencies beyond Dart SDK
4. THE crypto package SHALL be usable independently for cryptographic operations
5. THE abi package SHALL be usable independently for ABI encoding/decoding
6. THE provider package SHALL depend only on core and standard HTTP/WebSocket libraries
7. WHEN a developer needs full functionality, THE SDK SHALL provide a meta-package that re-exports all modules
8. THE SDK SHALL follow semantic versioning for each package independently
9. THE hardware wallet packages (keystone, ledger, trezor) SHALL be independently importable
10. THE DeFi service packages (swap, bridge, staking) SHALL be independently importable without requiring other DeFi packages
11. THE NFT package SHALL be usable independently for NFT operations
12. THE ENS package SHALL be usable independently for domain resolution
13. THE history package SHALL be usable independently for transaction history
14. THE price package SHALL be usable independently for price data
15. THE dapp package SHALL be usable independently for DApp browser functionality
16. THE Bitcoin inscriptions package SHALL be usable independently within the bitcoin extension
17. EACH package SHALL define clear public API exports via a single entry point file
18. EACH package SHALL document its dependencies and peer dependencies in pubspec.yaml

### Requirement 13: 多鏈支援架構

**User Story:** As a developer, I want to interact with multiple blockchain networks using a consistent API, so that I can build cross-chain applications efficiently.

#### Acceptance Criteria

1. THE SDK SHALL define a Chain interface that abstracts chain-specific operations
2. THE ChainConfig SHALL support all major EVM-compatible chains: Ethereum, Polygon, BSC, Arbitrum, Optimism, Base, Avalanche
3. WHEN connecting to an EVM chain, THE SDK SHALL automatically configure the correct chainId and transaction format
4. THE SDK SHALL provide extension points for non-EVM chains through separate packages
5. WHEN a Solana extension is installed, THE SDK SHALL support Solana-specific transaction formats and programs
6. WHEN a Polkadot extension is installed, THE SDK SHALL support Substrate-based chains and SCALE encoding
7. THE Signer interface SHALL be chain-agnostic, allowing the same key management across different chains
8. THE SDK SHALL support multi-curve cryptography: secp256k1 (EVM/Bitcoin), ed25519 (Solana/Polkadot), sr25519 (Polkadot)

### Requirement 14: 核心工具模組

**User Story:** As a developer, I want reliable utility functions for common blockchain operations, so that I can avoid reimplementing basic functionality.

#### Acceptance Criteria

1. THE Core_Module SHALL provide EthereumAddress class with checksum validation (EIP-55)
2. THE Core_Module SHALL provide BigInt utilities for wei/gwei/ether conversions
3. THE Core_Module SHALL provide hex encoding/decoding with proper 0x prefix handling
4. THE Core_Module SHALL provide RLP (Recursive Length Prefix) encoding/decoding
5. THE Core_Module SHALL provide bytes utilities for concatenation, slicing, and comparison
6. THE Core_Module SHALL provide unit conversion utilities for all supported chains
7. WHEN validating an address, THE Core_Module SHALL support both checksummed and non-checksummed formats
8. FOR ALL encoding operations, encoding then decoding SHALL produce the original value (round-trip property)

### Requirement 15: EIP-7702 EOA 代碼委託支援

**User Story:** As a developer, I want to support EIP-7702 transactions, so that users can temporarily delegate their EOA to execute smart contract code for advanced wallet features like transaction batching and gasless transactions.

#### Acceptance Criteria

1. THE SDK SHALL support creating EIP-7702 Type 4 transactions with authorization lists
2. WHEN creating an authorization, THE SDK SHALL include chainId, contract address, nonce, and signature (yParity, r, s)
3. THE SDK SHALL provide methods to sign EIP-7702 authorizations using the EOA's private key
4. WHEN an authorization is signed, THE SDK SHALL produce a valid signature that can be verified on-chain
5. THE SDK SHALL support batch authorizations allowing multiple contract delegations in a single transaction
6. THE SDK SHALL provide utilities to verify authorization signatures before submission
7. WHEN interacting with an EIP-7702 enabled EOA, THE WalletClient SHALL support calling delegated contract methods
8. THE SDK SHALL support revoking delegations by setting the authorization address to zero
9. THE SDK SHALL provide clear documentation on security considerations for EIP-7702 usage

### Requirement 16: 硬體錢包整合

**User Story:** As a developer, I want to integrate hardware wallets for secure key management, so that users can sign transactions using their Keystone, Ledger, or Trezor devices.

#### Acceptance Criteria

1. THE SDK SHALL provide a HardwareWallet_Signer interface that implements the Signer abstraction
2. WHEN integrating Keystone hardware wallet, THE SDK SHALL support QR code based communication via BC-UR protocol
3. THE SDK SHALL provide BC-UR (Blockchain Commons Uniform Resources) encoding/decoding for QR code data exchange
4. WHEN signing with Keystone, THE SDK SHALL encode transaction data as animated QR codes and decode signed results
5. WHEN integrating Ledger hardware wallet, THE SDK SHALL support USB and Bluetooth communication
6. WHEN integrating Trezor hardware wallet, THE SDK SHALL support WebUSB communication
7. THE HardwareWallet_Signer SHALL support multi-chain signing for EVM, Bitcoin, Solana, and Polkadot
8. THE SDK SHALL provide clear error messages when hardware wallet communication fails

### Requirement 17: DEX 聚合與 Swap 服務

**User Story:** As a developer, I want to integrate DEX aggregators for token swaps, so that users can get the best exchange rates across multiple decentralized exchanges.

#### Acceptance Criteria

1. THE Swap_Service SHALL provide a unified interface for querying swap quotes from multiple aggregators
2. THE Swap_Service SHALL support integration with major aggregators: 1inch, 0x, Paraswap, and Rango
3. WHEN requesting a swap quote, THE Swap_Service SHALL return the best rate across all configured aggregators
4. THE Swap_Service SHALL support cross-chain swaps via bridge aggregators
5. THE Swap_Service SHALL provide MEV protection options for swap transactions
6. THE Swap_Service SHALL calculate and display dynamic slippage based on liquidity depth
7. WHEN executing a swap, THE Swap_Service SHALL handle token approvals automatically
8. THE Swap_Service SHALL support swap transaction tracking and status updates

### Requirement 18: NFT 服務

**User Story:** As a developer, I want to manage NFTs across multiple chains, so that users can view, transfer, and interact with their NFT collections.

#### Acceptance Criteria

1. THE NFT_Service SHALL provide methods to fetch NFT collections by wallet address
2. THE NFT_Service SHALL support ERC-721 and ERC-1155 token standards on EVM chains
3. THE NFT_Service SHALL support NFT metadata parsing including IPFS gateway resolution
4. WHEN fetching NFT images, THE NFT_Service SHALL handle multiple IPFS gateways with fallback
5. THE NFT_Service SHALL support NFT transfers with proper approval handling
6. THE NFT_Service SHALL provide caching for NFT metadata to improve performance
7. THE NFT_Service SHALL support cross-chain NFT display for Solana (Metaplex) and other chains
8. WHEN displaying NFT collections, THE NFT_Service SHALL support lazy loading and pagination

### Requirement 19: Staking 服務

**User Story:** As a developer, I want to integrate staking functionality, so that users can stake their assets and earn rewards across different protocols.

#### Acceptance Criteria

1. THE Staking_Service SHALL provide methods to query available staking opportunities
2. THE Staking_Service SHALL support native staking for Ethereum (via Lido, Rocket Pool), Solana, and Polkadot
3. WHEN staking assets, THE Staking_Service SHALL calculate expected APY and rewards
4. THE Staking_Service SHALL support liquid staking derivatives (stETH, rETH, etc.)
5. THE Staking_Service SHALL provide methods to unstake and claim rewards
6. THE Staking_Service SHALL integrate with DeFiLlama for yield data aggregation
7. WHEN displaying staking positions, THE Staking_Service SHALL show current value and accrued rewards
8. THE Staking_Service SHALL support validator selection for proof-of-stake chains

### Requirement 20: 跨鏈橋接服務

**User Story:** As a developer, I want to bridge assets between different blockchains, so that users can move their tokens across chains efficiently.

#### Acceptance Criteria

1. THE Bridge_Service SHALL provide a unified interface for cross-chain asset transfers
2. THE Bridge_Service SHALL support major bridge protocols: LayerZero, Wormhole, Stargate, and native L2 bridges
3. WHEN initiating a bridge transfer, THE Bridge_Service SHALL estimate fees and transfer time
4. THE Bridge_Service SHALL support bridge aggregation to find the optimal route
5. THE Bridge_Service SHALL provide transaction tracking across source and destination chains
6. THE Bridge_Service SHALL support bridging between EVM chains and non-EVM chains (Solana, etc.)
7. WHEN a bridge transfer is pending, THE Bridge_Service SHALL provide status updates
8. THE Bridge_Service SHALL handle bridge-specific token approvals and gas estimation

### Requirement 21: Bitcoin Inscriptions 與 BRC-20 支援

**User Story:** As a developer, I want to support Bitcoin Ordinals and BRC-20 tokens, so that users can interact with Bitcoin-native NFTs and tokens.

#### Acceptance Criteria

1. THE Inscription_Service SHALL support reading and displaying Bitcoin Ordinals inscriptions
2. THE Inscription_Service SHALL support BRC-20 token balance queries and transfers
3. THE Inscription_Service SHALL provide PSBT (Partially Signed Bitcoin Transaction) building for inscription transfers
4. WHEN transferring inscriptions, THE Inscription_Service SHALL handle UTXO selection to avoid spending inscribed sats
5. THE Inscription_Service SHALL support Runes protocol for fungible tokens on Bitcoin
6. THE Inscription_Service SHALL provide inscription indexing and search functionality
7. WHEN displaying inscriptions, THE Inscription_Service SHALL decode and render inscription content
8. THE Inscription_Service SHALL support inscription marketplace integration

### Requirement 22: ENS 與域名解析

**User Story:** As a developer, I want to resolve blockchain domain names, so that users can send to human-readable addresses instead of hex strings.

#### Acceptance Criteria

1. THE ENS_Service SHALL resolve ENS names to Ethereum addresses
2. THE ENS_Service SHALL support reverse resolution (address to ENS name)
3. THE ENS_Service SHALL support ENS avatar and text record resolution
4. THE ENS_Service SHALL support multi-chain address resolution via ENSIP-9
5. WHEN resolving names, THE ENS_Service SHALL support other naming services: Unstoppable Domains, SNS (Solana)
6. THE ENS_Service SHALL cache resolution results with appropriate TTL
7. WHEN displaying addresses, THE ENS_Service SHALL show resolved names when available
8. THE ENS_Service SHALL validate ENS name format before resolution

### Requirement 23: 交易歷史服務

**User Story:** As a developer, I want to fetch and display transaction history, so that users can review their past transactions across all chains.

#### Acceptance Criteria

1. THE Transaction_History_Service SHALL fetch transaction history for any wallet address
2. THE Transaction_History_Service SHALL support pagination and filtering by transaction type
3. THE Transaction_History_Service SHALL decode transaction data to show human-readable details
4. WHEN fetching history, THE Transaction_History_Service SHALL aggregate data from multiple providers (Etherscan, Moralis, etc.)
5. THE Transaction_History_Service SHALL support transaction status tracking (pending, confirmed, failed)
6. THE Transaction_History_Service SHALL provide transaction acceleration (speed up) and cancellation
7. THE Transaction_History_Service SHALL support multi-chain transaction history aggregation
8. WHEN displaying transactions, THE Transaction_History_Service SHALL show token transfers, NFT transfers, and contract interactions

### Requirement 24: DApp 瀏覽器支援

**User Story:** As a developer, I want to provide a DApp browser, so that users can interact with decentralized applications directly from the wallet.

#### Acceptance Criteria

1. THE DApp_Browser SHALL inject Web3 provider into loaded web pages
2. THE DApp_Browser SHALL support EIP-1193 provider interface for DApp communication
3. THE DApp_Browser SHALL support EIP-6963 multi-injected provider discovery
4. WHEN a DApp requests connection, THE DApp_Browser SHALL prompt user for approval
5. WHEN a DApp requests transaction signing, THE DApp_Browser SHALL display transaction details for user confirmation
6. THE DApp_Browser SHALL support chain switching requests (wallet_switchEthereumChain)
7. THE DApp_Browser SHALL support adding custom tokens (wallet_watchAsset)
8. THE DApp_Browser SHALL maintain session state across DApp interactions

### Requirement 25: 價格服務與市場數據

**User Story:** As a developer, I want to fetch real-time token prices and market data, so that users can see the value of their portfolio.

#### Acceptance Criteria

1. THE Price_Service SHALL fetch real-time token prices from multiple data providers
2. THE Price_Service SHALL support price aggregation from CoinGecko, CoinMarketCap, and DEX prices
3. THE Price_Service SHALL provide historical price data for charts
4. WHEN fetching prices, THE Price_Service SHALL implement caching with configurable TTL
5. THE Price_Service SHALL support fiat currency conversion (USD, EUR, TWD, etc.)
6. THE Price_Service SHALL provide price alerts and notifications
7. THE Price_Service SHALL calculate portfolio value across all chains and tokens
8. WHEN a token is not found in price feeds, THE Price_Service SHALL attempt DEX price discovery


### Requirement 26: 交易模擬與調試 API

**User Story:** As a developer, I want to simulate and debug transactions before sending them, so that I can verify transaction outcomes and troubleshoot issues.

#### Acceptance Criteria

1. THE Debug_Service SHALL support debug_traceTransaction for tracing executed transactions
2. THE Debug_Service SHALL support debug_traceCall for simulating calls with tracing
3. THE Debug_Service SHALL support eth_simulateV1 for multi-transaction simulation
4. WHEN simulating a transaction, THE Debug_Service SHALL support state overrides for testing scenarios
5. THE Debug_Service SHALL provide opcode-level execution traces with stack, memory, and storage data
6. THE Debug_Service SHALL support trace_block for tracing all transactions in a block
7. THE Debug_Service SHALL support trace_filter for filtering traces by address and topics
8. WHEN tracing fails, THE Debug_Service SHALL return detailed error information including revert reasons
9. THE Debug_Service SHALL support custom tracer configurations (callTracer, prestateTracer, etc.)

### Requirement 27: MEV 保護與 Flashbots 整合

**User Story:** As a developer, I want to protect transactions from MEV extraction and submit private transactions, so that users don't lose value to front-running or sandwich attacks.

#### Acceptance Criteria

1. THE MEV_Service SHALL support submitting transactions via Flashbots Protect RPC
2. THE MEV_Service SHALL support bundle submission to Flashbots relay
3. WHEN submitting a bundle, THE MEV_Service SHALL include target block number and transaction list
4. THE MEV_Service SHALL support bundle simulation before submission
5. THE MEV_Service SHALL provide MEV protection status tracking for submitted transactions
6. THE MEV_Service SHALL support private transaction submission that bypasses the public mempool
7. THE MEV_Service SHALL support multiple MEV protection providers (Flashbots, MEV Blocker, etc.)
8. WHEN a bundle fails, THE MEV_Service SHALL return detailed failure reasons
9. THE MEV_Service SHALL support bundle cancellation before inclusion

### Requirement 28: MPC 錢包支援

**User Story:** As a developer, I want to support MPC (Multi-Party Computation) wallets, so that users can have distributed key management without single points of failure.

#### Acceptance Criteria

1. THE MPC_Signer SHALL implement the Signer interface for MPC-based signing
2. THE MPC_Signer SHALL support threshold signature schemes (t-of-n)
3. WHEN signing a transaction, THE MPC_Signer SHALL coordinate with other key shares
4. THE MPC_Signer SHALL support key generation ceremonies for creating new MPC wallets
5. THE MPC_Signer SHALL support key refresh to rotate key shares without changing the public key
6. THE MPC_Signer SHALL support integration with popular MPC providers (Fireblocks, Fordefi, etc.)
7. WHEN a signing session fails, THE MPC_Signer SHALL provide detailed error information
8. THE MPC_Signer SHALL support both ECDSA and EdDSA threshold signatures
