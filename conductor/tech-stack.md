# 技術棧 (Technology Stack)

## 核心技術 (Core Technologies)
- **程式語言**：Dart (SDK ^3.10.7)
- **專案管理**：Monorepo 架構
- **依賴與工作區管理**：Melos (^6.0.0)

## 開發與測試工具 (Development & Testing)
- **靜態分析**：`lints` (^5.0.0) - 使用官方推薦的 Dart lint 規則。
- **單元測試**：`test` (^1.25.0) - 用於編寫和運行單元測試。
- **覆蓋率報告**：整合於 `melos` 腳本中。

## 架構分層與模組 (Architectural Layers & Modules)
專案採用嚴格的 Level 0-7 分層架構，主要模組包括但不限於：
- **Level 0 (Core)**: `dart_web3_core` (無依賴基礎工具)
- **Level 1 (Primitives)**: `dart_web3_crypto`, `dart_web3_abi`
- **Level 2 (Transport)**: `dart_web3_provider`, `dart_web3_signer`, `dart_web3_chains`
- **Level 3 (Clients)**: `dart_web3_client`, `dart_web3_contract`, `dart_web3_events`
- **Level 4 (Services)**: `dart_web3_multicall`, `dart_web3_ens` 等
- **Level 5 (Advanced)**: `dart_web3_aa` (ERC-4337), `dart_web3_reown` 等
- **Level 6 (Hardware)**: `dart_web3_keystone`, `dart_web3_ledger` 等
- **Level 7 (Extensions)**: `dart_web3_solana`, `dart_web3_bitcoin` 等

## 目標平台 (Target Platforms)
- **主要**：Flutter (Android, iOS)
- **支援**：Web, Windows, macOS, Linux (全平台支援)
