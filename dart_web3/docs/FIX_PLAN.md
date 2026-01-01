# dart_web3 正確性修復計劃

> 基於 Codex Review、Gemini 3 Pro Review、Context7 文檔查詢及手動代碼審查的綜合分析

## 修復狀態概覽

| 模組 | 嚴重度 | 問題數 | 狀態 |
|------|--------|--------|------|
| `crypto` (BIP-39/32) | CRITICAL | 6 | ✅ 已修復 |
| `abi` (編碼/解析) | HIGH/MEDIUM | 4 | ✅ 已修復 |
| `aa` (ERC-4337) | CRITICAL/HIGH | 6 | ✅ 全部修復 |

---

## 已完成修復

### ✅ crypto 模組 - BIP-39/32 加密演算法

**Commit:** `8f8d4bc` (2024-01-01)

| 問題 | 原實現 | 正確實現 | 權威來源 |
|------|--------|----------|----------|
| BIP-39 Checksum | Keccak-256 | SHA-256 | [BIP-39 Spec](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) |
| BIP-39 Seed | 錯誤的 PBKDF2 | PBKDF2-HMAC-SHA512 (2048 iterations) | RFC 2898, BIP-39 |
| BIP-32 Master Key | Keccak-256 | HMAC-SHA512 ("Bitcoin seed") | [BIP-32 Spec](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) |
| BIP-32 Child Key | Keccak-256 | HMAC-SHA512 | BIP-32 |
| BIP-32 Fingerprint | Keccak-256 | HASH160 (RIPEMD160(SHA256)) | BIP-32 |
| BIP-32 Checksum | Keccak-256 | Double SHA-256 | BIP-32 |

**新增文件：**
- `lib/src/sha2.dart` - SHA-256/512 (使用 `package:crypto`)
- `lib/src/hmac.dart` - HMAC-SHA256/512 (RFC 2104)
- `lib/src/pbkdf2.dart` - PBKDF2-HMAC-SHA512 (RFC 2898)
- `lib/src/ripemd160.dart` - RIPEMD-160 (純 Dart)
- `test/crypto_primitives_test.dart` - 官方測試向量

---

### ✅ abi 模組 - ABI 編碼/解析

**Commit:** `3f3e235` (2024-01-01)

#### 1.0 [CRITICAL] Tuple/Array 靜態大小計算錯誤 (Gemini 3 Pro 發現) ✅ 已修復

**問題描述：**
`AbiTuple.encode` 假設每個 component 佔用 32 bytes，但靜態 struct（如 `(uint256, uint256)`）實際佔用 64 bytes。

**受影響位置：**
- `types.dart:393` - `var currentOffset = components.length * 32;`
- `types.dart:291` - AbiArray 有相同問題

**權威來源（Solidity ABI Spec）：**
> For static types, the head contains the value directly. For tuples with static components, the components are encoded in-place.

**失敗案例：**
```dart
// 編碼 ((uint256, uint256), string)
// 當前: offset = 2 * 32 = 64 (錯誤！)
// 正確: offset = 64 + 32 = 96 (靜態 struct 64 + string offset 32)
```

**修復方案：**
```dart
// 1. 添加 getStaticSize() 方法到 AbiType
abstract class AbiType {
  int getStaticSize() => 32; // 默認 32 bytes
}

// 2. Override in AbiTuple
@override
int getStaticSize() {
  if (isDynamic) return 32; // 動態類型只是 offset pointer
  return components.fold(0, (sum, c) => sum + c.getStaticSize());
}

// 3. Override in AbiArray
@override
int getStaticSize() {
  if (isDynamic) return 32;
  return length! * elementType.getStaticSize();
}

// 4. 修正 AbiTuple.encode
var currentOffset = components.fold<int>(
  0, (sum, c) => sum + (c.isDynamic ? 32 : c.getStaticSize())
);
```

---

#### 1.1 [HIGH] UTF-16 vs UTF-8 字串編碼 ✅ 已修復

**問題描述：**
ABI 字串編碼使用 Dart 的 `codeUnits`（UTF-16），但 Solidity ABI 規範要求 UTF-8。

**權威來源（Solidity ABI Spec）：**
> `enc(X) = enc(enc_utf8(X))`, i.e. X is UTF-8 encoded and this value is interpreted as of bytes type and encoded further.

**受影響位置：**

| 文件 | 行號 | 問題代碼 |
|------|------|----------|
| `types.dart` | 247 | `Uint8List.fromList(str.codeUnits)` |
| `types.dart` | 254 | `String.fromCharCodes(bytes)` |
| `encoder.dart` | 51, 57 | `signature.codeUnits` (函數選擇器) |
| `encoder.dart` | 88 | `(value as String).codeUnits` (packed) |
| `typed_data.dart` | 116, 128 | `value.codeUnits` (EIP-712) |

**修復方案：**
```dart
// 錯誤：
Uint8List.fromList(str.codeUnits)

// 正確：
import 'dart:convert';
Uint8List.fromList(utf8.encode(str))
```

**影響：**
- 函數選擇器計算錯誤（非 ASCII 字符）
- 事件主題計算錯誤
- 字串編解碼錯誤
- EIP-712 簽名錯誤
- **與以太坊合約完全不相容**

---

#### 1.2 [MEDIUM] Event/Error Tuple 解析失敗 ✅ 已修復

**問題描述：**
`AbiEvent.fromJson` 和 `AbiError.fromJson` 直接調用 `parseType("tuple")`，但 JSON ABI 格式將 components 分開提供。

**受影響位置：**

| 文件 | 行號 | 方法 |
|------|------|------|
| `parser.dart` | 215-225 | `AbiEvent.fromJson` |
| `parser.dart` | 260-268 | `AbiError.fromJson` |

**JSON ABI 格式：**
```json
{
  "type": "tuple",
  "components": [
    {"name": "field1", "type": "uint256"},
    {"name": "field2", "type": "address"}
  ]
}
```

**修復方案：**
複用 `AbiFunction._parseInput` helper 方法，該方法已正確處理 tuple：

```dart
// AbiEvent.fromJson 應改為：
for (final input in (json['inputs'] as List?) ?? []) {
  inputs.add(AbiFunction._parseInput(input as Map<String, dynamic>));
}
```

---

#### 1.3 [MEDIUM] 簽名類型解析無法處理嵌套 Tuple ✅ 已修復

**問題描述：**
`_parseSignatureTypes` 使用 `split(',')` 拆分參數，無法正確處理嵌套括號。

**受影響位置：**
- `encoder.dart:108` - `typesStr.split(',').map(_parseType).toList()`

**失敗案例：**
```
簽名: batchCall((address,uint256)[],bool)
錯誤拆分: ['(address', 'uint256)', '[]', 'bool']
正確拆分: ['(address,uint256)[]', 'bool']
```

**修復方案：**
使用深度追蹤算法（參考 `AbiParser._splitTupleComponents`）：

```dart
static List<String> _splitSignatureTypes(String typesStr) {
  final types = <String>[];
  var depth = 0;
  var start = 0;

  for (var i = 0; i < typesStr.length; i++) {
    final char = typesStr[i];
    if (char == '(' || char == '[') depth++;
    else if (char == ')' || char == ']') depth--;
    else if (char == ',' && depth == 0) {
      types.add(typesStr.substring(start, i).trim());
      start = i + 1;
    }
  }
  if (start < typesStr.length) {
    types.add(typesStr.substring(start).trim());
  }
  return types;
}
```

---

### ✅ aa 模組 - ERC-4337 Account Abstraction

**Commit:** 待提交 (2024-01-01)

#### 2.1 [CRITICAL] UserOpHash 編碼未實現 ✅ 已修復

**問題描述：**
所有版本的 userOpHash 計算都拋出 `UnimplementedError`。

**權威來源（EIP-4337）：**
```solidity
bytes32 constant PACKED_USEROP_TYPEHASH = keccak256(
    "PackedUserOperation(address sender,uint256 nonce,bytes initCode,bytes callData,bytes32 accountGasLimits,uint256 preVerificationGas,bytes32 gasFees,bytes paymasterAndData)"
);
```

**受影響位置：**

| 文件 | 行號 | 方法 | 版本 |
|------|------|------|------|
| `user_operation.dart` | 191-195 | `_getTypedDataHash` | v0.8/v0.9 |
| `user_operation.dart` | 342-357 | `_encodeUserOpV06` | v0.6 |
| `user_operation.dart` | 360-373 | `_encodeUserOpV07` | v0.7 |
| `user_operation.dart` | 376-380 | `_encodeFinalHash` | All |

**修復方案：**

**v0.6/v0.7 (ABI 編碼)：**
```dart
String _encodeFinalHash(String packedUserOp, String entryPoint, int chainId) {
  // keccak256(abi.encode(keccak256(packed), entryPoint, chainId))
  final packed = AbiEncoder.encode(
    [AbiBytes(32), AbiAddress(), AbiUint(256)],
    [Keccak256.hash(HexUtils.decode(packedUserOp)), entryPoint, chainId],
  );
  return HexUtils.encode(Keccak256.hash(packed));
}
```

**v0.8/v0.9 (EIP-712)：**
```dart
String _getTypedDataHash(int chainId, String entryPointAddress) {
  final domain = EIP712Domain(
    name: 'EntryPoint',
    version: '0.8.0',
    chainId: chainId,
    verifyingContract: entryPointAddress,
  );
  return TypedData.hashTypedData(domain, PACKED_USEROP_TYPEHASH, userOpData);
}
```

---

#### 2.2 [CRITICAL] EntryPoint Calldata 僅返回 Selector ✅ 已修復

**問題描述：**
`handleOps` 和 `simulateValidation` 只返回函數選擇器，沒有參數編碼。

**權威來源（EIP-4337）：**
```solidity
function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary);
```

**受影響位置：**

| 文件 | 行號 | 方法 | 返回值 |
|------|------|------|--------|
| `entry_point.dart` | 144-151 | `_encodeHandleOpsCall` (v0.6) | `0x1fad948c` only |
| `entry_point.dart` | 301-307 | `_encodeHandleOpsCall` (v0.7) | `0x765e827f` only |
| `entry_point.dart` | 332-338 | `_encodeSimulateValidationCall` | `0xee219423` only |

**修復方案：**
```dart
String _encodeHandleOpsCall(List<PackedUserOperation> ops, String beneficiary) {
  const selector = '765e827f';

  // 編碼 UserOperation[] 數組
  final opsEncoded = AbiEncoder.encodeArray(
    ops.map((op) => op.toAbiTuple()).toList(),
  );

  // 編碼 address 參數
  final beneficiaryEncoded = AbiEncoder.encode(
    [AbiAddress()],
    [beneficiary],
  );

  return '0x$selector${HexUtils.encode(opsEncoded)}${HexUtils.encode(beneficiaryEncoded)}';
}
```

---

#### 2.3 [HIGH] CREATE2 地址計算返回全零 ✅ 已修復

**問題描述：**
`_calculateCreate2Address` 返回 `0x0000...0000`，完全忽略輸入參數。

**權威來源（EIP-1014）：**
```
address = keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
```

**受影響位置：**

| 文件 | 行號 | 問題 |
|------|------|------|
| `smart_account.dart` | 199-204 | 返回全零地址 |
| `simple_account.dart` | 110-124 | 使用 owner 截斷 |
| `light_account.dart` | 105-119 | 使用 owner 截斷 |

**修復方案：**
```dart
String _calculateCreate2Address(String factory, String salt, String initCode) {
  // CREATE2: keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
  final factoryBytes = HexUtils.decode(factory);
  final saltBytes = HexUtils.decode(salt).padLeft(32);
  final initCodeHash = Keccak256.hash(HexUtils.decode(initCode));

  final data = Uint8List(1 + 20 + 32 + 32);
  data[0] = 0xff;
  data.setRange(1, 21, factoryBytes);
  data.setRange(21, 53, saltBytes);
  data.setRange(53, 85, initCodeHash);

  final hash = Keccak256.hash(data);
  return '0x${HexUtils.encode(hash.sublist(12))}';
}
```

---

#### 2.4 [MEDIUM] signUserOperation 使用錯誤簽名方案 ✅ 已修復

**問題描述：**
使用 EIP-191 `signMessage`（添加前綴），但 ERC-4337 要求直接簽名原始 hash。

**受影響位置：**
- `smart_account.dart:158-168`

**當前代碼：**
```dart
final signature = await _owner.signMessage(userOpHash);  // 添加 EIP-191 前綴
```

**修復方案：**
```dart
final signature = await _owner.signHash(userOpHash);  // 直接簽名 hash

// 或在 PrivateKeySigner 中添加：
Future<Uint8List> signHash(String hash) async {
  final hashBytes = HexUtils.decode(hash);
  return Secp256k1.sign(hashBytes, privateKey);  // 不添加前綴
}
```

---

## 修復狀態總結

| 優先級 | 模組 | 問題 | 嚴重度 | 狀態 | 發現來源 |
|--------|------|------|--------|------|----------|
| **P0** | ABI | Tuple 靜態大小計算 | CRITICAL | ✅ 已修復 | Gemini 3 Pro |
| **P0** | ABI | UTF-8 編碼 | HIGH | ✅ 已修復 | Codex Review |
| **P1** | ABI | Tuple 解析 (Event/Error) | MEDIUM | ✅ 已修復 | Codex Review |
| **P1** | ABI | 簽名解析 (嵌套括號) | MEDIUM | ✅ 已修復 | Codex Review |
| **P2** | AA | CREATE2 地址 | HIGH | ✅ 已修復 | Codex Review |
| **P2** | AA | signUserOperation | MEDIUM | ✅ 已修復 | Codex Review |
| **P3** | AA | UserOpHash 編碼 (v0.6/v0.7) | CRITICAL | ✅ 已修復 | Codex Review |
| **P3** | AA | UserOpHash 編碼 (v0.8/v0.9 EIP-712) | CRITICAL | ✅ 已修復 | Codex Review |
| **P3** | AA | EntryPoint calldata | CRITICAL | ✅ 已修復 | Codex Review |

**修復進度：**
- ✅ ABI 模組：4/4 問題已修復（100%）
- ✅ AA 模組：6/6 問題已修復（100%）
- ✅ crypto 模組：6/6 問題已修復（100%）

**所有核心模組問題已完全修復！**

---

## 審查來源

| 來源 | 發現問題數 | 關鍵發現 |
|------|------------|----------|
| Claude (手動審查) | 6 | BIP-39/32 加密演算法 (已修復) |
| Codex Review | 9 | ABI UTF-8, AA ERC-4337 |
| Gemini 3 Pro | 1 | **Tuple 靜態大小計算 (CRITICAL)** |
| Context7 | - | 權威文檔驗證 |

---

## 測試驗證計劃

### ABI 模組測試

```dart
// UTF-8 測試
test('encodes non-ASCII strings correctly', () {
  final encoded = AbiString().encode('你好世界');
  // 驗證與 ethers.js / web3.js 輸出一致
});

// Tuple 解析測試
test('parses event with tuple input', () {
  final event = AbiEvent.fromJson({
    'name': 'Transfer',
    'inputs': [
      {'name': 'data', 'type': 'tuple', 'components': [...]}
    ]
  });
  expect(event.inputs.first, isA<AbiTuple>());
});
```

### AA 模組測試

```dart
// CREATE2 測試向量
test('calculates CREATE2 address correctly', () {
  // 使用 eth-infinitism/account-abstraction 測試向量
  final address = _calculateCreate2Address(
    '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
    '0x0000...0000',
    initCode,
  );
  expect(address, equals(expectedAddress));
});

// UserOpHash 測試
test('computes v0.7 userOpHash correctly', () {
  // 對比鏈上驗證結果
});
```

---

## 參考文檔

- [Solidity ABI Specification](https://docs.soliditylang.org/en/latest/abi-spec.html)
- [EIP-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [EIP-1014: CREATE2](https://eips.ethereum.org/EIPS/eip-1014)
- [EIP-712: Typed Data Hashing](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-191: Signed Data Standard](https://eips.ethereum.org/EIPS/eip-191)
- [BIP-32: HD Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- [BIP-39: Mnemonic Code](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [RFC 2898: PBKDF2](https://datatracker.ietf.org/doc/html/rfc2898)
- [RFC 4231: HMAC-SHA Test Vectors](https://datatracker.ietf.org/doc/html/rfc4231)
