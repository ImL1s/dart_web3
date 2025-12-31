# Implementation Plan: Dart Web3 SDK

## Overview

本實施計劃將 Dart Web3 SDK 的設計轉化為可執行的開發任務。採用自底向上的實施策略，從核心模組開始，逐層構建完整的 SDK。所有實現必須是純 Dart，無任何原生依賴。

## Tasks

- [x] 1. 設置專案結構和 Monorepo 配置
  - [x] 創建 `dart_web3/` 根目錄和 `packages/` 子目錄
  - [x] 配置 `melos.yaml` 用於 monorepo 管理
  - [x] 設置共用的 `analysis_options.yaml`
  - [x] 創建根目錄 `pubspec.yaml` 和 README.md
  - _Requirements: 12.1, 12.2_

- [x] 2. 實現 Core 模組 (dart_web3_core)
  - [x] 2.1 創建 core 套件基礎結構
    - [x] 創建 `packages/core/pubspec.yaml`（零外部依賴）
    - [x] 創建 `packages/core/lib/dart_web3_core.dart` 入口文件
    - _Requirements: 12.3, 12.17_

  - [x] 2.2 實現 EthereumAddress 類別
    - [x] 實現地址解析和驗證
    - [x] 實現 EIP-55 checksum 編碼/驗證
    - [x] 支援 checksummed 和 non-checksummed 格式
    - _Requirements: 14.1, 14.7_

  - [x] 2.3 實現 BigInt 工具類
    - [x] 實現 wei/gwei/ether 單位轉換
    - [x] 實現格式化輸出方法
    - _Requirements: 14.2_

  - [x] 2.4 實現 Hex 編碼工具
    - [x] 實現 hex 編碼/解碼
    - [x] 處理 0x 前綴
    - _Requirements: 14.3_

  - [x] 2.5 實現 RLP 編碼/解碼
    - [x] 實現 RLP 編碼器
    - [x] 實現 RLP 解碼器
    - [x] 支援嵌套結構
    - _Requirements: 14.4_

  - [x] 2.6 實現 Bytes 工具類
    - [x] 實現 concat、slice、equals 方法
    - [x] 實現 padding 方法
    - _Requirements: 14.5_

  - [x] 2.7 編寫 Core 模組屬性測試
    - **Property 24: Address Checksum Validation**
    - **Property 25: Unit Conversion Accuracy**
    - **Property 26: Hex Encoding Round Trip**
    - **Property 27: RLP Encoding Round Trip**
    - **Property 28: Core Encoding Round Trip**
    - **Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.8**

- [x] 3. Checkpoint - Core 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 4. 實現 Crypto 模組 (dart_web3_crypto)
  - [x] 4.1 創建 crypto 套件基礎結構
    - 創建 `packages/crypto/pubspec.yaml`（依賴 core）
    - 創建入口文件
    - _Requirements: 12.4_

  - [x] 4.2 實現 Keccak-256 哈希
    - 純 Dart 實現 Keccak-256 算法
    - 提供 hash 和 hashHex 方法
    - _Requirements: 8.2_

  - [x] 4.3 實現 secp256k1 橢圓曲線
    - 純 Dart 實現 secp256k1 曲線運算
    - 實現 sign、recover、getPublicKey、verify 方法
    - _Requirements: 8.1_

  - [x] 4.4 實現 BIP-39 助記詞
    - 實現助記詞生成
    - 實現種子派生
    - 實現驗證方法
    - _Requirements: 8.3_

  - [x] 4.5 實現 BIP-32/44 HD 錢包
    - 實現分層確定性密鑰派生
    - 支援標準派生路徑
    - _Requirements: 8.4_

  - [x] 4.6 實現多曲線支援
    - 實現 Ed25519（Solana/Polkadot）
    - 實現 Sr25519（Polkadot）
    - _Requirements: 13.8_

  - [x] 4.7 編寫 Crypto 模組屬性測試
    - **Property 20: Secp256k1 Sign-Recover Round Trip**
    - **Property 21: Keccak-256 Hash Consistency**
    - **Property 22: BIP-39 Mnemonic Validation**
    - **Property 23: HD Wallet Derivation Consistency**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**

- [x] 5. Checkpoint - Crypto 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 6. 實現 ABI 模組 (dart_web3_abi)
  - [x] 6.1 創建 abi 套件基礎結構
    - [x] 創建 `packages/abi/pubspec.yaml`（依賴 core）
    - [x] 創建入口文件
    - _Requirements: 12.5_

  - [x] 6.2 實現 ABI 類型系統
    - [x] 實現 AbiType 抽象類別
    - [x] 實現 AbiUint、AbiInt、AbiAddress、AbiBool
    - [x] 實現 AbiBytes、AbiString
    - [x] 實現 AbiArray、AbiTuple
    - _Requirements: 3.3_

  - [x] 6.3 實現 ABI 編碼器
    - [x] 實現 encode 方法
    - [x] 實現 encodePacked 方法
    - [x] 實現 encodeFunction 方法
    - [x] 正確處理動態類型偏移量
    - _Requirements: 3.1, 3.4, 3.5_

  - [x] 6.4 實現 ABI 解碼器
    - [x] 實現 decode 方法
    - [x] 實現 decodeFunction 方法
    - [x] 實現 decodeEvent 方法
    - _Requirements: 3.2_

  - [x] 6.5 實現 EIP-712 TypedData
    - [x] 實現 TypedData 類別
    - [x] 實現 domain separator 計算
    - [x] 實現 struct hash 計算
    - _Requirements: 3.6_

  - [x] 6.6 實現 ABI JSON 解析器
    - [x] 實現 AbiParser 類別
    - [x] 解析 functions、events、errors
    - [x] 實現 AbiFunction、AbiEvent 類別
    - _Requirements: 3.7_

  - [x] 6.7 實現 Pretty Printer
    - [x] 實現 ABI 數據格式化輸出
    - _Requirements: 3.8_

  - [x] 6.8 編寫 ABI 模組屬性測試
    - **Property 12: ABI Encoding Round Trip**
    - **Property 13: Function Call Data Padding**
    - **Property 14: Dynamic Type Offset Calculation**
    - **Property 15: Nested Structure Encoding**
    - **Property 16: EIP-712 Domain Separator**
    - **Validates: Requirements 3.1, 3.4, 3.5, 3.6, 3.9**

- [x] 7. Checkpoint - ABI 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 8. 實現 Provider 模組 (dart_web3_provider)
  - [x] 8.1 創建 provider 套件基礎結構
    - [x] 創建 `packages/provider/pubspec.yaml`（依賴 core、http）
    - [x] 創建入口文件
    - _Requirements: 12.6_

  - [x] 8.2 實現 Transport 抽象
    - [x] 定義 Transport 介面
    - [x] 定義 RpcRequest 類別
    - _Requirements: 1.7_

  - [x] 8.3 實現 HttpTransport
    - [x] 實現 HTTP JSON-RPC 請求
    - [x] 實現批次請求支援
    - [x] 實現超時處理
    - _Requirements: 1.1, 1.3_

  - [x] 8.4 實現 WebSocketTransport
    - [x] 實現 WebSocket 連接
    - [x] 實現訂閱支援
    - [x] 實現自動重連
    - _Requirements: 1.2, 1.6_

  - [x] 8.5 實現 Middleware 系統
    - [x] 定義 Middleware 介面
    - [x] 實現 RetryMiddleware
    - [x] 實現 LoggingMiddleware
    - _Requirements: 1.4_

  - [x] 8.6 實現 RpcProvider
    - [x] 整合 Transport 和 Middleware
    - [x] 實現常用 RPC 方法
    - [x] 實現錯誤處理
    - _Requirements: 1.5_

  - [x] 8.7 編寫 Provider 模組屬性測試
    - **Property 1: HTTP RPC Connection Establishment**
    - **Property 2: WebSocket Persistent Connection**
    - **Property 3: Batch Request Consolidation**
    - **Property 4: Middleware Execution Order**
    - **Property 5: Error Response Structure**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

- [x] 9. Checkpoint - Provider 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 10. 實現 Signer 模組 (dart_web3_signer)
  - [x] 10.1 創建 signer 套件基礎結構
    - [x] 創建 `packages/signer/pubspec.yaml`（依賴 core、crypto、abi）
    - [x] 創建入口文件
    - _Requirements: 12.2_

  - [x] 10.2 定義 Signer 抽象介面
    - [x] 定義 signTransaction、signMessage、signTypedData 方法
    - [x] 定義 signAuthorization 方法（EIP-7702）
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 10.3 實現交易類型定義
    - [x] 實現 TransactionRequest 類別
    - [x] 實現 TransactionType 枚舉
    - [x] 實現 AccessListEntry、Authorization 類別
    - _Requirements: 2.4, 2.5, 2.6, 2.7, 2.8_

  - [x] 10.4 實現 PrivateKeySigner
    - [x] 實現私鑰簽名
    - [x] 支援所有交易類型（Legacy、EIP-1559、EIP-2930、EIP-4844、EIP-7702）
    - [x] 實現 EIP-155 chainId 保護
    - _Requirements: 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

  - [x] 10.5 實現助記詞簽名器
    - [x] 從助記詞派生私鑰
    - [x] 支援自定義派生路徑
    - _Requirements: 2.10_

  - [x] 10.6 定義 HardwareWalletSigner 抽象
    - [x] 定義硬體錢包簽名器介面
    - _Requirements: 16.1_

  - [x] 10.7 定義 MpcSigner 抽象
    - [x] 定義 MPC 簽名器介面
    - _Requirements: 28.1_

  - [x] 10.8 編寫 Signer 模組屬性測試
    - **Property 6: Transaction Signing Interface**
    - **Property 7: Message Signing Consistency**
    - **Property 8: EIP-712 Typed Data Signing**
    - **Property 9: Legacy Transaction EIP-155 Protection**
    - **Property 10: EIP-1559 Fee Field Encoding**
    - **Property 11: Mnemonic to Private Key Derivation**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.10**

- [x] 11. Checkpoint - Signer 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 12. 實現 Chains 模組 (dart_web3_chains)
  - [x] 12.1 創建 chains 套件基礎結構
    - 創建 `packages/chains/pubspec.yaml`（依賴 core）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 12.2 實現 ChainConfig 類別
    - 定義鏈配置數據結構
    - 包含 chainId、name、rpcUrls、blockExplorerUrls 等
    - _Requirements: 7.2_

  - [x] 12.3 實現預定義鏈配置
    - Ethereum Mainnet、Goerli、Sepolia
    - Polygon、BSC、Arbitrum、Optimism、Base、Avalanche
    - _Requirements: 7.1, 13.2_

  - [x] 12.4 實現鏈配置管理
    - 實現 getById 方法
    - 實現 registerChain 方法
    - _Requirements: 7.4, 7.5_

  - [x] 12.5 編寫 Chains 模組單元測試
    - 測試預定義鏈配置正確性
    - 測試自定義鏈註冊
    - _Requirements: 7.1, 7.4, 7.5_

- [x] 13. 實現 Client 模組 (dart_web3_client)
  - [x] 13.1 創建 client 套件基礎結構
    - 創建 `packages/client/pubspec.yaml`（依賴 core、provider、signer、chains）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 13.2 實現 PublicClient
    - 實現 getBalance、getBlock、getTransaction 等方法
    - 實現 call、estimateGas 方法
    - 實現 getLogs 方法
    - _Requirements: 4.1, 4.2_

  - [x] 13.3 實現 WalletClient
    - 繼承 PublicClient
    - 實現 sendTransaction、signMessage、signTypedData 方法
    - 實現帳戶切換功能
    - _Requirements: 4.3, 4.4, 4.5, 4.6_

  - [x] 13.4 實現 ClientFactory
    - 實現 createPublicClient 方法
    - 實現 createWalletClient 方法
    - _Requirements: 4.7_

  - [x] 13.5 實現數據模型
    - 實現 Block、Transaction、TransactionReceipt 類別
    - 實現 Log、FeeData 類別
    - _Requirements: 4.2_

  - [x] 13.6 編寫 Client 模組屬性測試
    - **Property 17: PublicClient Read-Only Operations**
    - **Property 18: WalletClient Inheritance**
    - **Property 19: Account Switching Persistence**
    - **Validates: Requirements 4.1, 4.3, 4.6**

- [x] 14. Checkpoint - Client 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 15. 實現 Contract 模組 (dart_web3_contract)
  - [x] 15.1 創建 contract 套件基礎結構
    - 創建 `packages/contract/pubspec.yaml`（依賴 client、abi）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 15.2 實現 Contract 類別
    - 實現 read 方法（只讀調用）
    - 實現 write 方法（狀態變更）
    - 實現 simulate 方法
    - 實現 estimateGas 方法
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 15.3 實現事件處理
    - 實現 createEventFilter 方法
    - 實現 decodeEventLog 方法
    - _Requirements: 5.5, 5.6_

  - [x] 15.4 實現錯誤解碼
    - 實現 decodeError 方法
    - _Requirements: 5.7_

  - [x] 15.5 實現 ContractFactory
    - 實現合約部署功能
    - _Requirements: 5.1_

  - [x] 15.6 實現預定義合約類別
    - 實現 ERC20Contract
    - 實現 ERC721Contract
    - 實現 ERC1155Contract
    - _Requirements: 5.2_

  - [x] 15.7 編寫 Contract 模組單元測試
    - 測試合約讀取和寫入
    - 測試事件解碼
    - _Requirements: 5.1, 5.3, 5.4, 5.6_

- [x] 16. 實現 Events 模組 (dart_web3_events)
  - [x] 16.1 創建 events 套件基礎結構
    - 創建 `packages/events/pubspec.yaml`（依賴 client）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 16.2 實現 EventFilter 類別
    - 定義過濾器數據結構
    - _Requirements: 6.2_

  - [x] 16.3 實現 EventSubscriber
    - 實現 WebSocket 訂閱
    - 實現 HTTP 輪詢
    - _Requirements: 6.1, 6.3, 6.4_

  - [x] 16.4 實現 EventListener
    - 實現合約事件監聽
    - 實現監聽管理
    - _Requirements: 6.1_

  - [x] 16.5 實現鏈重組處理
    - 處理 removed 標誌
    - _Requirements: 6.5_

  - [x] 16.6 實現確認數過濾
    - 實現區塊確認數檢查
    - _Requirements: 6.6_

  - [x] 16.7 編寫 Events 模組單元測試
    - 測試事件訂閱和過濾
    - _Requirements: 6.1, 6.2_

- [x] 17. Checkpoint - Level 3 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 18. 實現 Multicall 模組 (dart_web3_multicall)
  - [x] 18.1 創建 multicall 套件基礎結構
    - 創建 `packages/multicall/pubspec.yaml`（依賴 client、contract）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 18.2 實現 Multicall 類別
    - 實現批次調用編碼
    - 實現結果解碼
    - 支援 Multicall2 和 Multicall3
    - _Requirements: 9.1, 9.2, 9.4_

  - [x] 18.3 實現錯誤處理
    - 處理單個調用失敗
    - _Requirements: 9.3_

  - [x] 18.4 實現鏈配置整合
    - 從 ChainConfig 獲取 Multicall 合約地址
    - _Requirements: 9.5_

  - [x] 18.5 編寫 Multicall 模組單元測試
    - 測試批次調用
    - 測試錯誤處理
    - _Requirements: 9.1, 9.3_

- [x] 19. 實現 ENS 模組 (dart_web3_ens)
  - [x] 19.1 創建 ens 套件基礎結構
    - 創建 `packages/ens/pubspec.yaml`（依賴 client、contract）
    - 創建入口文件
    - _Requirements: 12.12_

  - [x] 19.2 實現 ENS 解析
    - 實現 name → address 解析
    - 實現 address → name 反向解析
    - _Requirements: 22.1, 22.2_

  - [x] 19.3 實現 ENS 記錄查詢
    - 實現 avatar 解析
    - 實現 text record 解析
    - _Requirements: 22.3_

  - [x] 19.4 實現多鏈地址解析
    - 實現 ENSIP-9 支援
    - _Requirements: 22.4_

  - [x] 19.5 實現緩存機制
    - 實現解析結果緩存
    - _Requirements: 22.6_

  - [x] 19.6 實現名稱驗證
    - 實現 ENS 名稱格式驗證
    - _Requirements: 22.8_

  - [x] 19.7 編寫 ENS 模組單元測試
    - 測試 ENS 解析
    - 測試緩存機制
    - _Requirements: 22.1, 22.2, 22.6_

- [-] 20. 實現 AA 模組 (dart_web3_aa)
  - [x] 20.1 創建 aa 套件基礎結構
    - 創建 `packages/aa/pubspec.yaml`（依賴 client、signer、contract）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 20.2 實現 UserOperation 類別
    - 實現 UserOperation 數據結構
    - 實現 userOpHash 計算
    - _Requirements: 11.1, 11.2_

  - [x] 20.3 實現 Bundler 客戶端
    - 實現 Bundler JSON-RPC 通訊
    - 實現 gas 估算
    - _Requirements: 11.3, 11.6_

  - [x] 20.4 實現 Paymaster 整合
    - 實現 Paymaster 數據處理
    - _Requirements: 11.4_

  - [x] 20.5 實現 SmartAccount 抽象
    - 實現 SmartAccount 介面
    - 實現 SimpleAccount
    - 實現 LightAccount
    - _Requirements: 11.5_

  - [x] 20.6 實現 EntryPoint 支援
    - 支援 EntryPoint v0.6
    - 支援 EntryPoint v0.7
    - _Requirements: 11.7_

  - [x] 20.7 編寫 AA 模組單元測試
    - 測試 UserOperation 構建
    - 測試 userOpHash 計算
    - _Requirements: 11.1, 11.2_

- [x] 21. 實現 EIP-7702 支援
  - [x] 21.1 實現 Authorization 類別
    - 實現授權數據結構
    - 實現授權簽名
    - _Requirements: 15.1, 15.2, 15.3_

  - [x] 21.2 實現授權驗證
    - 實現簽名驗證
    - _Requirements: 15.4, 15.6_

  - [x] 21.3 實現批次授權
    - 支援多個合約委託
    - _Requirements: 15.5_

  - [x] 21.4 實現授權撤銷
    - 實現設置零地址撤銷
    - _Requirements: 15.8_

  - [x] 21.5 實現 WalletClient 整合
    - 支援調用委託合約方法
    - _Requirements: 15.7_

  - [x] 21.6 編寫 EIP-7702 單元測試
    - 測試授權簽名
    - 測試授權驗證
    - _Requirements: 15.1, 15.4_

- [x] 22. Checkpoint - Level 4-5 核心模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [x] 23. 實現 Reown 模組 (dart_web3_reown)
  - [x] 23.1 創建 reown 套件基礎結構
    - 創建 `packages/reown/pubspec.yaml`（依賴 client、signer）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 23.2 實現 Reown 客戶端
    - 實現 pairing URI 生成
    - 實現 relay 協議通訊
    - _Requirements: 10.1, 10.2_

  - [x] 23.3 實現 Session 管理
    - 實現 session 建立
    - 實現 session 斷開
    - _Requirements: 10.3, 10.6_

  - [x] 23.4 實現 Namespace 配置
    - 支援鏈和方法配置
    - _Requirements: 10.4_

  - [x] 23.5 實現 ReownSigner
    - 實現 Signer 介面
    - 處理簽名請求和響應
    - _Requirements: 10.3, 10.5_

  - [x] 23.6 實現自動重連
    - 實現 relay 連接重連
    - _Requirements: 10.7_

  - [x] 23.7 實現 One-Click Auth
    - 實現 SIWE 整合
    - _Requirements: 10.8_

  - [x] 23.8 編寫 Reown 模組單元測試
    - 測試 session 管理
    - 測試簽名流程
    - _Requirements: 10.1, 10.3_

- [-] 24. 實現 Hardware 模組
  - [x] 24.1 實現 BC-UR 模組 (dart_web3_bc_ur)
    - 創建 `packages/hardware/bc_ur/pubspec.yaml`
    - 實現 BC-UR 編碼/解碼
    - 支援動畫 QR 碼分片
    - _Requirements: 16.3_

  - [x] 24.2 實現 Keystone 模組 (dart_web3_keystone)
    - 創建 `packages/hardware/keystone/pubspec.yaml`（依賴 bc_ur、signer）
    - 實現 KeystoneSigner
    - 實現 QR 碼通訊
    - _Requirements: 16.2, 16.4_

  - [x] 24.3 實現 Ledger 模組 (dart_web3_ledger)
    - 創建 `packages/hardware/ledger/pubspec.yaml`（依賴 signer）
    - 實現 LedgerSigner
    - 支援 USB 和 BLE 通訊
    - _Requirements: 16.5_

  - [x] 24.4 實現 Trezor 模組 (dart_web3_trezor)
    - 創建 `packages/hardware/trezor/pubspec.yaml`（依賴 signer）
    - 實現 TrezorSigner
    - 支援 WebUSB 通訊
    - _Requirements: 16.6_

  - [x] 24.5 實現多鏈簽名支援
    - 支援 EVM、Bitcoin、Solana、Polkadot
    - _Requirements: 16.7_

  - [x] 24.6 編寫 Hardware 模組單元測試
    - 測試 BC-UR 編碼/解碼
    - 測試簽名器介面
    - _Requirements: 16.3_

- [-] 25. 實現 MPC 模組 (dart_web3_mpc)
  - [x] 25.1 創建 mpc 套件基礎結構
    - 創建 `packages/hardware/mpc/pubspec.yaml`（依賴 signer、crypto）
    - 創建入口文件
    - _Requirements: 12.2_

  - [x] 25.2 實現 MpcSigner
    - 實現 Signer 介面
    - 支援門限簽名（t-of-n）
    - _Requirements: 28.1, 28.2_

  - [x] 25.3 實現簽名協調
    - 實現多方簽名協調
    - _Requirements: 28.3_

  - [x] 25.4 實現密鑰生成
    - 實現密鑰生成儀式
    - _Requirements: 28.4_

  - [x] 25.5 實現密鑰刷新
    - 實現密鑰份額輪換
    - _Requirements: 28.5_

  - [x] 25.6 實現 Provider 整合
    - 支援 Fireblocks、Fordefi 等
    - _Requirements: 28.6_

  - [x] 25.7 實現多曲線支援
    - 支援 ECDSA 和 EdDSA 門限簽名
    - _Requirements: 28.8_

  - [x] 25.8 編寫 MPC 模組單元測試
    - 測試簽名流程
    - _Requirements: 28.1, 28.2_

- [x] 26. Checkpoint - 硬體錢包模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [-] 27. 實現 DeFi 服務模組
  - [x] 27.1 實現 Swap 模組 (dart_web3_swap)
    - 創建 `packages/swap/pubspec.yaml`（依賴 client、contract）
    - 實現 DEX 聚合器整合（1inch、0x、Paraswap）
    - 實現報價查詢和最佳路徑選擇
    - 實現 MEV 保護選項
    - 實現代幣授權處理
    - _Requirements: 17.1, 17.2, 17.3, 17.5, 17.7_

  - [x] 27.2 實現 Bridge 模組 (dart_web3_bridge)
    - 創建 `packages/bridge/pubspec.yaml`（依賴 client、contract）
    - 實現跨鏈橋接整合（LayerZero、Wormhole、Stargate）
    - 實現費用和時間估算
    - 實現交易追蹤
    - _Requirements: 20.1, 20.2, 20.3, 20.5_

  - [ ] 27.3 實現 NFT 模組 (dart_web3_nft)
    - 創建 `packages/nft/pubspec.yaml`（依賴 client、contract）
    - 實現 NFT 集合查詢
    - 實現 ERC-721/ERC-1155 支援
    - 實現 metadata 解析和 IPFS 網關
    - 實現 NFT 轉移
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [ ] 27.4 實現 Staking 模組 (dart_web3_staking)
    - 創建 `packages/staking/pubspec.yaml`（依賴 client、contract）
    - 實現質押機會查詢
    - 實現 Lido、Rocket Pool 整合
    - 實現 APY 計算
    - 實現質押/解質押操作
    - _Requirements: 19.1, 19.2, 19.3, 19.5_

  - [ ] 27.5 編寫 DeFi 模組單元測試
    - 測試報價查詢
    - 測試 NFT metadata 解析
    - _Requirements: 17.1, 18.3_

- [ ] 28. 實現用戶服務模組
  - [ ] 28.1 實現 History 模組 (dart_web3_history)
    - 創建 `packages/history/pubspec.yaml`（依賴 client）
    - 實現交易歷史查詢
    - 實現分頁和過濾
    - 實現交易解碼
    - 實現多鏈聚合
    - _Requirements: 23.1, 23.2, 23.3, 23.7_

  - [ ] 28.2 實現 Price 模組 (dart_web3_price)
    - 創建 `packages/price/pubspec.yaml`（依賴 core）
    - 實現價格查詢（CoinGecko、CoinMarketCap）
    - 實現歷史價格數據
    - 實現緩存機制
    - 實現法幣轉換
    - _Requirements: 25.1, 25.2, 25.3, 25.4, 25.5_

  - [ ] 28.3 實現 DApp 模組 (dart_web3_dapp)
    - 創建 `packages/dapp/pubspec.yaml`（依賴 client、signer）
    - 實現 Web3 Provider 注入
    - 實現 EIP-1193 介面
    - 實現 EIP-6963 多 Provider 發現
    - 實現鏈切換和代幣添加
    - _Requirements: 24.1, 24.2, 24.3, 24.6, 24.7_

  - [ ] 28.4 編寫用戶服務模組單元測試
    - 測試交易歷史查詢
    - 測試價格緩存
    - _Requirements: 23.1, 25.4_

- [ ] 29. 實現進階功能模組
  - [ ] 29.1 實現 Debug 模組 (dart_web3_debug)
    - 創建 `packages/debug/pubspec.yaml`（依賴 provider）
    - 實現 debug_traceTransaction
    - 實現 debug_traceCall
    - 實現 eth_simulateV1
    - 實現 state override 支援
    - 實現 trace_block、trace_filter
    - _Requirements: 26.1, 26.2, 26.3, 26.4, 26.6, 26.7_

  - [ ] 29.2 實現 MEV 模組 (dart_web3_mev)
    - 創建 `packages/mev/pubspec.yaml`（依賴 provider、signer）
    - 實現 Flashbots Protect RPC
    - 實現 bundle 提交
    - 實現 bundle 模擬
    - 實現私密交易提交
    - _Requirements: 27.1, 27.2, 27.4, 27.6_

  - [ ] 29.3 編寫進階功能模組單元測試
    - 測試交易追蹤
    - 測試 bundle 構建
    - _Requirements: 26.1, 27.2_

- [ ] 30. Checkpoint - Level 5 模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [ ] 31. 實現鏈擴展模組
  - [ ] 31.1 實現 Solana 擴展 (dart_web3_solana)
    - 創建 `packages/extensions/solana/pubspec.yaml`
    - 實現 Solana 交易格式
    - 實現 Program 交互
    - 實現 Ed25519 簽名整合
    - _Requirements: 13.5_

  - [ ] 31.2 實現 Polkadot 擴展 (dart_web3_polkadot)
    - 創建 `packages/extensions/polkadot/pubspec.yaml`
    - 實現 SCALE 編碼
    - 實現 Substrate 交易
    - 實現 Sr25519 簽名整合
    - _Requirements: 13.6_

  - [ ] 31.3 實現 Tron 擴展 (dart_web3_tron)
    - 創建 `packages/extensions/tron/pubspec.yaml`
    - 實現 Tron 交易格式
    - 實現 TRC-20 支援
    - _Requirements: 13.4_

  - [ ] 31.4 實現 TON 擴展 (dart_web3_ton)
    - 創建 `packages/extensions/ton/pubspec.yaml`
    - 實現 TON 交易格式
    - 實現 Jetton 支援
    - _Requirements: 13.4_

  - [ ] 31.5 實現 Bitcoin 擴展 (dart_web3_bitcoin)
    - 創建 `packages/extensions/bitcoin/pubspec.yaml`
    - 實現 Bitcoin 交易格式
    - 實現 PSBT 支援
    - _Requirements: 13.4_

  - [ ] 31.6 實現 Bitcoin Inscriptions 子模組
    - 創建 `packages/extensions/bitcoin/inscriptions/pubspec.yaml`
    - 實現 Ordinals 銘文讀取
    - 實現 BRC-20 代幣支援
    - 實現 Runes 協議支援
    - 實現 UTXO 選擇（避免花費銘文）
    - _Requirements: 21.1, 21.2, 21.4, 21.5_

  - [ ] 31.7 編寫鏈擴展模組屬性測試
    - **Property 29: Chain-Agnostic Signer Interface**
    - **Property 30: Multi-Curve Cryptography Support**
    - **Validates: Requirements 13.7, 13.8**

- [ ] 32. Checkpoint - 鏈擴展模組完成
  - 確保所有測試通過，如有問題請詢問用戶

- [ ] 33. 實現 Meta-Package 和整合
  - [ ] 33.1 創建 Meta-Package (dart_web3)
    - 創建 `dart_web3/pubspec.yaml`
    - 重新導出所有核心模組
    - _Requirements: 12.7_

  - [ ] 33.2 實現版本管理
    - 配置語義化版本
    - 設置 changelog 生成
    - _Requirements: 12.8_

  - [ ] 33.3 創建範例應用
    - 創建 `example/` 目錄
    - 實現基本使用範例
    - 實現進階功能範例
    - _Requirements: 12.2_

  - [ ] 33.4 編寫文檔
    - 編寫 API 文檔
    - 編寫使用指南
    - 編寫遷移指南
    - _Requirements: 12.17, 12.18_

- [ ] 34. 整合測試和品質保證
  - [ ] 34.1 執行跨模組整合測試
    - 測試完整工作流程
    - 測試模組間互操作性
    - _Requirements: 12.2_

  - [ ] 34.2 執行測試網測試
    - 在 Sepolia 測試網測試
    - 在 Polygon Mumbai 測試
    - _Requirements: 4.2_

  - [ ] 34.3 執行性能測試
    - 測試 RPC 請求延遲
    - 測試批次請求性能
    - 測試記憶體使用量
    - _Requirements: 1.3_

  - [ ] 34.4 執行安全審查
    - 審查密碼學實現
    - 審查私鑰處理
    - _Requirements: 8.5_

- [ ] 35. Final Checkpoint - 專案完成
  - 確保所有測試通過
  - 確保文檔完整
  - 準備發布

## Notes

- 每個任務都引用了具體的需求以確保可追溯性
- Checkpoint 任務用於確保增量驗證
- 屬性測試驗證通用正確性屬性
- 單元測試驗證具體範例和邊界情況
- 所有實現必須是純 Dart，無任何原生依賴
- 所有測試任務都是必需的，確保全面的測試覆蓋