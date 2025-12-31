# Spec: Client Module Verification & Completion

## 目標
根據 `.kiro/specs/dart-web3-sdk/tasks.md`，完成並驗證 Task 13 (Client 模組) 的實作，特別是補全缺失的屬性測試 (Task 13.6)。

## 範疇
- **Task 13.6: 屬性測試**：實作並執行 `dart_web3_client` 的屬性測試，涵蓋 Property 17 (PublicClient 只讀操作)、Property 18 (WalletClient 繼承) 與 Property 19 (帳戶切換持久性)。
- **Task 13 整合驗證**：確保 `PublicClient`, `WalletClient`, `ClientFactory` 與相關數據模型實作正確並通過測試。

## 成功標準
- Task 13.6 的屬性測試通過並符合設計文檔要求。
- `tasks.md` 中的 Task 13 標記為完全已完成 `[x]`。
- `dart_web3_client` 套件的單元測試與屬性測試全部通過。
