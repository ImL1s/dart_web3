# Plan: Implement Remaining SDK Modules

## Phase 1: DeFi Services (Remaining) [checkpoint: 27dd811]
- [x] Task: 27.3 實現 NFT 模組 (dart_web3_nft) 1bf7d07
  - [x] Subtask: 創建套件基礎結構
  - [x] Subtask: 實現 NFT 集合查詢與 ERC-721/1155 支援
  - [x] Subtask: 實現 metadata 解析與 IPFS 網關
- [x] Task: 27.4 實現 Staking 模組 (dart_web3_staking) 1bf7d07
  - [x] Subtask: 實現質押機會查詢與協議整合 (Lido, Rocket Pool)
  - [x] Subtask: 實現質押/解質押操作與 APY 計算
- [x] Task: 27.5 編寫 DeFi 模組單元測試 1bf7d07
- [x] Task: Conductor - User Manual Verification 'Phase 1: DeFi Services' (Protocol in workflow.md) 27dd811

## Phase 2: User Services [checkpoint: 2f78de6]
- [x] Task: 28.1 實現 History 模組 (dart_web3_history) d832027
  - [x] Subtask: 實現交易歷史查詢與多鏈聚合
  - [x] Subtask: 實現分頁、過濾與交易解碼
- [x] Task: 28.2 實現 Price 模組 (dart_web3_price) d832027
  - [x] Subtask: 整合價格數據源 (CoinGecko, CoinMarketCap)
  - [x] Subtask: 實現緩存與法幣轉換
- [x] Task: 28.3 實現 DApp 模組 (dart_web3_dapp) d832027
  - [x] Subtask: 實現 Web3 Provider 注入與 EIP-1193/6963 支援
- [x] Task: 28.4 編寫用戶服務模組單元測試 d832027
- [x] Task: Conductor - User Manual Verification 'Phase 2: User Services' (Protocol in workflow.md) 2f78de6

## Phase 3: Advanced Modules [checkpoint: 19241d9]
- [x] Task: 29.1 實現 Debug 模組 (dart_web3_debug) 1a7470e
  - [x] Subtask: 實現交易追蹤與模擬 (traceTransaction, simulateV1)
  - [x] Subtask: 實現 State Override 支援
- [x] Task: 29.2 實現 MEV 模組 (dart_web3_mev) 1a7470e
  - [x] Subtask: 實現 Flashbots Protect 與 Bundle 提交
- [x] Task: 29.3 編寫進階功能模組單元測試 1a7470e
- [x] Task: 30. Checkpoint - Level 5 模組完成 1a7470e
- [x] Task: Conductor - User Manual Verification 'Phase 3: Advanced Modules' (Protocol in workflow.md) 19241d9

## Phase 4: Chain Extensions
- [ ] Task: 31.1 實現 Solana 擴展 (dart_web3_solana)
- [ ] Task: 31.2 實現 Polkadot 擴展 (dart_web3_polkadot)
- [ ] Task: 31.3 實現 Tron 擴展 (dart_web3_tron)
- [ ] Task: 31.4 實現 TON 擴展 (dart_web3_ton)
- [ ] Task: 31.5 實現 Bitcoin 擴展 (dart_web3_bitcoin)
  - [ ] Subtask: 31.6 實現 Bitcoin Inscriptions (Ordinals, BRC-20, Runes)
- [ ] Task: 31.7 編寫鏈擴展模組屬性測試 (Property 29, 30)
- [ ] Task: 32. Checkpoint - 鏈擴展模組完成
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Chain Extensions' (Protocol in workflow.md)

## Phase 5: Final Integration & QA
- [ ] Task: 33.1 實現 Meta-Package (dart_web3) 整合
- [ ] Task: 33.2 版本管理與 Changelog
- [ ] Task: 33.3 創建範例應用 (example/)
- [ ] Task: 33.4 編寫完整 API 文檔與指南
- [ ] Task: 34. 整合測試、壓力測試與安全審查 (34.1 - 34.4)
- [ ] Task: 35. Final Checkpoint - 專案完成
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Final Integration & QA' (Protocol in workflow.md)
