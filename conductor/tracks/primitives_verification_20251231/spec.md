# Spec: Core PRIMITIVES Module Integrity Verification

## 目標
根據 `.kiro/specs/dart-web3-sdk/tasks.md`，驗證並完成 Task 4 (Crypto) 和 Task 6 (ABI) 的所有子任務，確保密碼學原語與 ABI 編解碼功能的完整性與正確性。

## 範疇
- **Task 4: Crypto 模組**：驗證 `dart_web3_crypto` 的實作 (Keccak, Secp256k1, BIP-39/32/44, Multi-curve) 與屬性測試 (Property 20-23)。
- **Task 6: ABI 模組**：驗證 `dart_web3_abi` 的實作 (Encoder, Decoder, EIP-712, Parser) 與屬性測試 (Property 12-16)。

## 成功標準
- 所有 Task 4 與 Task 6 的子任務在 `tasks.md` 中標記為已完成。
- `dart_web3_crypto` 與 `dart_web3_abi` 的所有單元測試與屬性測試通過。
- 確保無任何原生依賴 (Pure Dart)。
