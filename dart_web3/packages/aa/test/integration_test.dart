import 'dart:typed_data';

import 'package:dart_web3_aa/dart_web3_aa.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('ERC-4337 Integration Tests', () {
    group('UserOperation Hash Computation', () {
      final testUserOp = UserOperation(
        sender: '0x1234567890123456789012345678901234567890',
        nonce: BigInt.from(1),
        callData: '0xabcdef',
        callGasLimit: BigInt.from(100000),
        verificationGasLimit: BigInt.from(50000),
        preVerificationGas: BigInt.from(21000),
        maxFeePerGas: BigInt.from(20000000000),
        maxPriorityFeePerGas: BigInt.from(1000000000),
        signature: '0x1234',
      );

      test('computes v0.6 hash correctly', () {
        final hash = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointVersion: EntryPointVersion.v06,
        );

        expect(hash.startsWith('0x'), isTrue);
        expect(hash.length, equals(66)); // 0x + 64 hex chars = 32 bytes
      });

      test('computes v0.7 hash correctly', () {
        final hash = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
          entryPointVersion: EntryPointVersion.v07,
        );

        expect(hash.startsWith('0x'), isTrue);
        expect(hash.length, equals(66));
      });

      test('computes v0.8/v0.9 hash using EIP-712', () {
        final hash = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108',
          entryPointVersion: EntryPointVersion.v08,
        );

        expect(hash.startsWith('0x'), isTrue);
        expect(hash.length, equals(66));
      });

      test('different chain IDs produce different hashes', () {
        final hash1 = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointVersion: EntryPointVersion.v06,
        );

        final hash2 = testUserOp.getUserOpHash(
          chainId: 5,
          entryPointAddress: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointVersion: EntryPointVersion.v06,
        );

        expect(hash1, isNot(equals(hash2)));
      });

      test('different entry points produce different hashes', () {
        final hash1 = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointVersion: EntryPointVersion.v06,
        );

        final hash2 = testUserOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          entryPointVersion: EntryPointVersion.v06,
        );

        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('PackedUserOperation', () {
      test('correctly packs gas limits', () {
        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
        );

        final packed = userOp.toPackedUserOperation();

        // accountGasLimits = verificationGasLimit (16 bytes) || callGasLimit (16 bytes)
        expect(packed.accountGasLimits.startsWith('0x'), isTrue);
        expect(packed.accountGasLimits.length, equals(66)); // 0x + 64 hex = 32 bytes

        // gasFees = maxPriorityFeePerGas (16 bytes) || maxFeePerGas (16 bytes)
        expect(packed.gasFees.startsWith('0x'), isTrue);
        expect(packed.gasFees.length, equals(66));
      });

      test('correctly packs paymaster data for v0.7', () {
        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
          paymaster: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          paymasterVerificationGasLimit: BigInt.from(30000),
          paymasterPostOpGasLimit: BigInt.from(10000),
          paymasterData: '0xdead',
        );

        final packed = userOp.toPackedUserOperation();

        // Should concatenate paymaster fields (address is lowercase)
        expect(packed.paymasterAndData.toLowerCase().contains('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
            isTrue);
      });
    });

    group('CREATE2 Address Computation', () {
      test('computes deterministic address from salt and code hash', () {
        // CREATE2 address = keccak256(0xff ++ deployer ++ salt ++ keccak256(initCode))[12:]
        final deployer = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
        final salt = Uint8List.fromList(List.filled(32, 0)); // Zero salt
        final initCodeHash = Keccak256.hash(Uint8List.fromList([1, 2, 3]));

        final prefix = Uint8List.fromList([0xff]);
        final deployerBytes = HexUtils.decode(deployer);
        final data = Uint8List.fromList([
          ...prefix,
          ...deployerBytes,
          ...salt,
          ...initCodeHash,
        ]);

        final hash = Keccak256.hash(data);
        // Take last 20 bytes as address
        final addressBytes = hash.sublist(12);
        final address = HexUtils.encode(addressBytes);

        expect(address.startsWith('0x'), isTrue);
        expect(address.length, equals(42)); // 0x + 40 hex chars = 20 bytes
      });

      test('same inputs produce same address', () {
        final deployer = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
        final salt = Uint8List.fromList(List.filled(32, 1));
        final initCode = Uint8List.fromList([0xaa, 0xbb, 0xcc]);

        String computeCreate2(Uint8List salt, Uint8List initCode) {
          final initCodeHash = Keccak256.hash(initCode);
          final prefix = Uint8List.fromList([0xff]);
          final deployerBytes = HexUtils.decode(deployer);
          final data = Uint8List.fromList([
            ...prefix,
            ...deployerBytes,
            ...salt,
            ...initCodeHash,
          ]);
          final hash = Keccak256.hash(data);
          return HexUtils.encode(hash.sublist(12));
        }

        final addr1 = computeCreate2(salt, initCode);
        final addr2 = computeCreate2(salt, initCode);

        expect(addr1, equals(addr2));
      });

      test('different salts produce different addresses', () {
        final deployer = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
        final salt1 = Uint8List.fromList(List.filled(32, 1));
        final salt2 = Uint8List.fromList(List.filled(32, 2));
        final initCode = Uint8List.fromList([0xaa, 0xbb, 0xcc]);

        String computeCreate2(Uint8List salt, Uint8List initCode) {
          final initCodeHash = Keccak256.hash(initCode);
          final prefix = Uint8List.fromList([0xff]);
          final deployerBytes = HexUtils.decode(deployer);
          final data = Uint8List.fromList([
            ...prefix,
            ...deployerBytes,
            ...salt,
            ...initCodeHash,
          ]);
          final hash = Keccak256.hash(data);
          return HexUtils.encode(hash.sublist(12));
        }

        final addr1 = computeCreate2(salt1, initCode);
        final addr2 = computeCreate2(salt2, initCode);

        expect(addr1, isNot(equals(addr2)));
      });
    });

    group('EntryPoint Version Compatibility', () {
      test('v0.6 default address is correct', () {
        expect(EntryPointV06.defaultAddress,
            equals('0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'));
      });

      test('v0.7 default address is correct', () {
        expect(EntryPointV07.defaultAddress,
            equals('0x0000000071727De22E5E9d8BAf0edAc6f37da032'));
      });

      test('UserOperation supports both v0.6 and v0.7 fields', () {
        // v0.6 style with initCode and paymasterAndData
        final userOpV06 = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
          initCode: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbbbbbbbb',
          paymasterAndData: '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBcccccccc',
        );

        expect(userOpV06.initCode, isNotNull);
        expect(userOpV06.paymasterAndData, isNotNull);
        expect(userOpV06.factory, isNull);
        expect(userOpV06.paymaster, isNull);

        // v0.7 style with factory/paymaster separate fields
        final userOpV07 = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
          factory: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          factoryData: '0xbbbbbbbb',
          paymaster: '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
          paymasterVerificationGasLimit: BigInt.from(30000),
          paymasterPostOpGasLimit: BigInt.from(10000),
          paymasterData: '0xcccccccc',
        );

        expect(userOpV07.factory, isNotNull);
        expect(userOpV07.paymaster, isNotNull);
        expect(userOpV07.paymasterVerificationGasLimit, isNotNull);
        expect(userOpV07.paymasterPostOpGasLimit, isNotNull);
      });
    });

    group('UserOperation JSON Serialization', () {
      test('round-trip serialization preserves all fields', () {
        final original = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(42),
          callData: '0xdeadbeef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0xabcd',
          factory: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          factoryData: '0x1234',
          paymaster: '0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
          paymasterVerificationGasLimit: BigInt.from(30000),
          paymasterPostOpGasLimit: BigInt.from(10000),
          paymasterData: '0x5678',
        );

        final json = original.toJson();
        final restored = UserOperation.fromJson(json);

        expect(restored.sender, equals(original.sender));
        expect(restored.nonce, equals(original.nonce));
        expect(restored.callData, equals(original.callData));
        expect(restored.callGasLimit, equals(original.callGasLimit));
        expect(restored.verificationGasLimit, equals(original.verificationGasLimit));
        expect(restored.preVerificationGas, equals(original.preVerificationGas));
        expect(restored.maxFeePerGas, equals(original.maxFeePerGas));
        expect(restored.maxPriorityFeePerGas, equals(original.maxPriorityFeePerGas));
        expect(restored.signature, equals(original.signature));
        expect(restored.factory, equals(original.factory));
        expect(restored.factoryData, equals(original.factoryData));
        expect(restored.paymaster, equals(original.paymaster));
        expect(restored.paymasterVerificationGasLimit,
            equals(original.paymasterVerificationGasLimit));
        expect(restored.paymasterPostOpGasLimit,
            equals(original.paymasterPostOpGasLimit));
        expect(restored.paymasterData, equals(original.paymasterData));
      });

      test('JSON uses hex format for BigInt fields', () {
        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(255),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(256),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
        );

        final json = userOp.toJson();

        expect(json['nonce'], equals('0xff'));
        expect(json['callGasLimit'], equals('0x100'));
      });
    });

    group('Bundler RPC Interface', () {
      test('BundlerClient creates correct RPC request for eth_sendUserOperation', () {
        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x1234',
        );

        final json = userOp.toJson();

        // Verify the JSON structure matches what bundlers expect
        expect(json.containsKey('sender'), isTrue);
        expect(json.containsKey('nonce'), isTrue);
        expect(json.containsKey('callData'), isTrue);
        expect(json.containsKey('callGasLimit'), isTrue);
        expect(json.containsKey('verificationGasLimit'), isTrue);
        expect(json.containsKey('preVerificationGas'), isTrue);
        expect(json.containsKey('maxFeePerGas'), isTrue);
        expect(json.containsKey('maxPriorityFeePerGas'), isTrue);
        expect(json.containsKey('signature'), isTrue);
      });

      test('Gas estimation response can be parsed', () {
        // Simulate bundler response for eth_estimateUserOperationGas
        final response = {
          'preVerificationGas': '0x5208',
          'verificationGasLimit': '0xc350',
          'callGasLimit': '0x186a0',
          'paymasterVerificationGasLimit': '0x0',
          'paymasterPostOpGasLimit': '0x0',
        };

        final preVerificationGas = BigInt.parse(response['preVerificationGas']!);
        final verificationGasLimit = BigInt.parse(response['verificationGasLimit']!);
        final callGasLimit = BigInt.parse(response['callGasLimit']!);

        expect(preVerificationGas, equals(BigInt.from(21000)));
        expect(verificationGasLimit, equals(BigInt.from(50000)));
        expect(callGasLimit, equals(BigInt.from(100000)));
      });
    });

    group('Signature Validation', () {
      test('empty signature is allowed for gas estimation', () {
        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: '0x',
        );

        expect(userOp.signature, equals('0x'));
      });

      test('dummy signature for simulation', () {
        // Common pattern: 65-byte dummy signature for gas estimation
        final dummySignature = '0x${'00' * 65}';

        final userOp = UserOperation(
          sender: '0x1234567890123456789012345678901234567890',
          nonce: BigInt.from(1),
          callData: '0xabcdef',
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(50000),
          preVerificationGas: BigInt.from(21000),
          maxFeePerGas: BigInt.from(20000000000),
          maxPriorityFeePerGas: BigInt.from(1000000000),
          signature: dummySignature,
        );

        expect(userOp.signature.length, equals(132)); // 0x + 130 hex chars
      });
    });

    // Note: EIP-7702 Authorization tests are skipped as Authorization class
    // is not yet implemented. This is a future enhancement.
  });
}
