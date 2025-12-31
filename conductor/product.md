# 產品定義 (Product Guide)

## 初始構想 (Initial Concept)
建立一個全面的、純 Dart 實作的 Web3 SDK，支援 EVM 及其它多種區塊鏈，旨在為 Dart/Flutter 生態系統提供高品質的區塊鏈開發工具。該專案旨在填補 Dart 生態中現代化 Web3 開發工具的缺口，提供與 TypeScript (viem/ethers.js) 和 Rust (alloy) 生態相當的功能與體驗。

## 目標用戶 (Target Users)
- **Flutter 行動端 DApp 開發者**：需要高性能、無原生依賴 (No FFI) 的 SDK 來構建跨平台 (Android/iOS) 錢包與應用。
- **Dart 後端工程師**：需要可靠工具進行區塊鏈索引、自動化交易、交易所集成或 MEV 機器人開發。
- **協議與工具開發者**：需要純 Dart 實現的 Web3 標準 (如 EIP-712, ERC-4337) 以構建更上層的協議或開發工具。

## 核心目標 (Core Goals)
1.  **純 Dart 實作 (Pure Dart Implementation)**：零原生依賴 (No FFI/C++/Rust bindings)，確保在所有 Dart 支援平台 (Mobile, Web, Desktop) 上的完美可移植性。
2.  **模組化分層架構 (Modular Layered Architecture)**：採用 Level 0 至 Level 7 的嚴格分層設計，確保無循環依賴，開發者可按需引用最小化套件。
3.  **極致開發者體驗 (Superior DX)**：借鑑 `viem` 架構，分離 PublicClient 與 WalletClient，提供型別安全的 Actions API 與完整的錯誤處理體系。
4.  **統一的多鏈支援 (Unified Multi-chain)**：以 EVM 為核心，並透過擴展模組統一支援 Solana, Polkadot, Tron, TON 與 Bitcoin (含 Ordinals/Runes)。

## 參考標竿 (References & Inspiration)
- **架構參考**：`viem` (TS) - Client 分離與 Actions API；`alloy` (Rust) - 模組化結構與型別安全。
- **密碼學參考**：`blockchain_utils` (Dart) - 純 Dart 密碼學實作。
- **功能參考**：`permissionless` (AA), `reown-appkit` (WalletConnect), `web3.py` (Flashbots/MEV).

## 關鍵功能 (Key Features)

### 核心與標準 (Core & Standards)
- **現代以太坊標準**：完整支援 EIP-1559 (Fee Market), EIP-4844 (Blob Transactions), EIP-712 (Typed Data), EIP-7702 (EOA Code Delegation)。
- **智能合約交互**：型別安全的合約工廠、ABI 編解碼 (支援複雜嵌套與動態類型)、Multicall 2/3 批次查詢。
- **事件訂閱**：支援 WebSocket 訂閱與 HTTP 輪詢，具備鏈重組處理與確認數過濾機制。

### 帳戶與安全 (Accounts & Security)
- **帳戶抽象 (ERC-4337)**：內建 Bundler 與 Paymaster 客戶端，支援 UserOperation 構建、SimpleAccount/LightAccount 及 EntryPoint v0.6/v0.7。
- **硬體錢包整合**：支援 Keystone (BC-UR 動態 QR 碼)、Ledger (USB/BLE)、Trezor (WebUSB)。
- **MPC 錢包**：支援多方計算 (Multi-Party Computation) 簽名與門限簽名 (Threshold Signatures)。
- **連接標準**：整合 Reown (WalletConnect v2)，支援 One-Click Auth 與 SIWE (Sign-In with Ethereum)。

### 多鏈擴展 (Multi-Chain Extensions)
- **Solana**：支援 Program 交互與 Ed25519 簽名。
- **Bitcoin**：支援原生交易、PSBT、**Ordinals 銘文**、**BRC-20** 代幣與 **Runes** 協議。
- **Polkadot**：支援 Substrate 交易、SCALE 編碼與 Sr25519 簽名。
- **其他鏈**：Tron (TRC-20), TON (Jettons).

### 高級服務與工具 (Advanced Services & Tools)
- **DeFi 聚合**：內建 Swap (1inch/0x) 與 Bridge (LayerZero/Wormhole) 聚合介面。
- **NFT 與 ENS**：跨鏈 NFT 管理 (ERC-721/1155) 與多鏈域名解析 (ENS/Unstoppable/SNS)。
- **MEV 保護**：Flashbots Bundle 提交、私密交易 (Private Transactions) 與 Bundle 模擬。
- **調試與追蹤**：支援 `debug_traceTransaction`, `trace_call`, `eth_simulateV1` 及 State Overrides。
- **DApp 瀏覽器**：支援 EIP-1193 與 EIP-6963 Provider 注入與發現。

## 架構設計 (Architecture)
專案採用 Monorepo 管理，分為 8 個層級：
- **Level 0 (Core)**: 基礎工具 (Address, BigInt, RLP, Hex)。
- **Level 1 (Primitives)**: 純 Dart 密碼學 (Crypto) 與 ABI 編解碼。
- **Level 2 (Transport)**: RPC Provider (HTTP/WS, Middleware), Signer 抽象, Chains 配置。
- **Level 3 (Clients)**: Public/Wallet Clients, Contract 抽象, Events 系統。
- **Level 4 (Services)**: Multicall, ENS, History, Price。
- **Level 5 (Advanced)**: AA (4337), Reown, Swap, Bridge, NFT, Staking, DApp, Debug, MEV。
- **Level 6 (Hardware)**: BC-UR, Keystone, Ledger, Trezor, MPC。
- **Level 7 (Extensions)**: Solana, Polkadot, Tron, TON, Bitcoin (Inscriptions)。
