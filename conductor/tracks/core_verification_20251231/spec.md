# Spec: Infrastructure & Core Integrity Verification

## 目標
根據 `.kiro/specs/dart-web3-sdk/tasks.md`，驗證並完成 Task 1 和 Task 2 的所有子任務，確保專案基礎結構與核心模組 (dart_web3_core) 的完整性與正確性。

## 範疇
- **Task 1: 專案結構**：驗證 `dart_web3/` 根目錄、`packages/` 子目錄、`melos.yaml`、`analysis_options.yaml`、`pubspec.yaml` 與 `README.md` 的存在與配置正確性。
- **Task 2: Core 模組**：驗證 `dart_web3_core` 的實作 (Address, BigInt, Hex, RLP, Bytes) 與屬性測試 (Property 24-28)。

## 成功標準
- 所有 Task 1 與 Task 2 的子任務在 `tasks.md` 中標記為已完成。
- `dart_web3_core` 的所有單元測試與屬性測試通過。
- 專案結構符合 Monorepo 規範。
