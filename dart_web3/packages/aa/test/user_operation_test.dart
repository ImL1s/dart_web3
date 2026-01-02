import 'package:dart_web3_aa/dart_web3_aa.dart';
import 'package:test/test.dart';

void main() {
  group('UserOperation', () {
    test('should create UserOperation with required fields', () {
      final userOp = UserOperation(
        sender: '0x1234567890123456789012345678901234567890',
        nonce: BigInt.from(1),
        callData: '0xabcdef',
        callGasLimit: BigInt.from(100000),
        verificationGasLimit: BigInt.from(50000),
        preVerificationGas: BigInt.from(21000),
        maxFeePerGas: BigInt.from(20000000000), // 20 gwei
        maxPriorityFeePerGas: BigInt.from(1000000000), // 1 gwei
        signature: '0x1234',
      );

      expect(userOp.sender, equals('0x1234567890123456789012345678901234567890'));
      expect(userOp.nonce, equals(BigInt.from(1)));
      expect(userOp.callData, equals('0xabcdef'));
      expect(userOp.callGasLimit, equals(BigInt.from(100000)));
      expect(userOp.verificationGasLimit, equals(BigInt.from(50000)));
      expect(userOp.preVerificationGas, equals(BigInt.from(21000)));
      expect(userOp.maxFeePerGas, equals(BigInt.from(20000000000)));
      expect(userOp.maxPriorityFeePerGas, equals(BigInt.from(1000000000)));
      expect(userOp.signature, equals('0x1234'));
    });

    test('should serialize to JSON correctly', () {
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

      expect(json['sender'], equals('0x1234567890123456789012345678901234567890'));
      expect(json['nonce'], equals('0x1'));
      expect(json['callData'], equals('0xabcdef'));
      expect(json['callGasLimit'], equals('0x186a0'));
      expect(json['verificationGasLimit'], equals('0xc350'));
      expect(json['preVerificationGas'], equals('0x5208'));
      expect(json['maxFeePerGas'], equals('0x4a817c800'));
      expect(json['maxPriorityFeePerGas'], equals('0x3b9aca00'));
      expect(json['signature'], equals('0x1234'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'sender': '0x1234567890123456789012345678901234567890',
        'nonce': '0x1',
        'callData': '0xabcdef',
        'callGasLimit': '0x186a0',
        'verificationGasLimit': '0xc350',
        'preVerificationGas': '0x5208',
        'maxFeePerGas': '0x4a817c800',
        'maxPriorityFeePerGas': '0x3b9aca00',
        'signature': '0x1234',
      };

      final userOp = UserOperation.fromJson(json);

      expect(userOp.sender, equals('0x1234567890123456789012345678901234567890'));
      expect(userOp.nonce, equals(BigInt.from(1)));
      expect(userOp.callData, equals('0xabcdef'));
      expect(userOp.callGasLimit, equals(BigInt.from(100000)));
      expect(userOp.verificationGasLimit, equals(BigInt.from(50000)));
      expect(userOp.preVerificationGas, equals(BigInt.from(21000)));
      expect(userOp.maxFeePerGas, equals(BigInt.from(20000000000)));
      expect(userOp.maxPriorityFeePerGas, equals(BigInt.from(1000000000)));
      expect(userOp.signature, equals('0x1234'));
    });

    test('should handle EntryPoint v0.6 fields', () {
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
        initCode: '0x5678',
        paymasterAndData: '0x9abc',
      );

      expect(userOp.initCode, equals('0x5678'));
      expect(userOp.paymasterAndData, equals('0x9abc'));
      expect(userOp.factory, isNull);
      expect(userOp.paymaster, isNull);
    });

    test('should handle EntryPoint v0.7+ fields', () {
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
        factory: '0x5678901234567890123456789012345678901234',
        factoryData: '0xdef0',
        paymaster: '0xabcdef0123456789012345678901234567890123',
        paymasterData: '0x4567',
        paymasterVerificationGasLimit: BigInt.from(30000),
        paymasterPostOpGasLimit: BigInt.from(20000),
      );

      expect(userOp.factory, equals('0x5678901234567890123456789012345678901234'));
      expect(userOp.factoryData, equals('0xdef0'));
      expect(userOp.paymaster, equals('0xabcdef0123456789012345678901234567890123'));
      expect(userOp.paymasterData, equals('0x4567'));
      expect(userOp.paymasterVerificationGasLimit, equals(BigInt.from(30000)));
      expect(userOp.paymasterPostOpGasLimit, equals(BigInt.from(20000)));
      expect(userOp.initCode, isNull);
      expect(userOp.paymasterAndData, isNull);
    });

    test('should create copy with updated fields', () {
      final originalUserOp = UserOperation(
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

      final updatedUserOp = originalUserOp.copyWith(
        nonce: BigInt.from(2),
        signature: '0x5678',
      );

      expect(updatedUserOp.sender, equals(originalUserOp.sender));
      expect(updatedUserOp.nonce, equals(BigInt.from(2)));
      expect(updatedUserOp.callData, equals(originalUserOp.callData));
      expect(updatedUserOp.signature, equals('0x5678'));
      
      // Original should be unchanged
      expect(originalUserOp.nonce, equals(BigInt.from(1)));
      expect(originalUserOp.signature, equals('0x1234'));
    });

    group('userOpHash calculation', () {
      late UserOperation userOp;

      setUp(() {
        userOp = UserOperation(
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
      });

      test('should calculate EIP-712 userOpHash for v0.8/v0.9', () {
        // v0.8 EIP-712 hash calculation
        final v08Hash = userOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108',
          entryPointVersion: EntryPointVersion.v08,
        );
        expect(v08Hash, isNotEmpty);
        expect(v08Hash.startsWith('0x'), isTrue);
        expect(v08Hash.length, equals(66)); // 0x + 64 hex chars

        // v0.9 EIP-712 hash calculation (uses same algorithm)
        final v09Hash = userOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x433709009B8330FDa32311DF1C2AFA402eD8D009',
          entryPointVersion: EntryPointVersion.v09,
        );
        expect(v09Hash, isNotEmpty);
        expect(v09Hash.startsWith('0x'), isTrue);
        expect(v09Hash.length, equals(66)); // 0x + 64 hex chars

        // Different EntryPoint addresses should produce different hashes
        expect(v08Hash, isNot(equals(v09Hash)));
      });

      test('should calculate userOpHash for v0.6 and v0.7', () {
        // v0.6 hash calculation
        final v06Hash = userOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointVersion: EntryPointVersion.v06,
        );
        expect(v06Hash, isNotEmpty);
        expect(v06Hash.startsWith('0x'), isTrue);
        expect(v06Hash.length, equals(66)); // 0x + 64 hex chars

        // v0.7 hash calculation
        final v07Hash = userOp.getUserOpHash(
          chainId: 1,
          entryPointAddress: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
          entryPointVersion: EntryPointVersion.v07,
        );
        expect(v07Hash, isNotEmpty);
        expect(v07Hash.startsWith('0x'), isTrue);
        expect(v07Hash.length, equals(66)); // 0x + 64 hex chars

        // Different EntryPoint addresses should produce different hashes
        expect(v06Hash, isNot(equals(v07Hash)));
      });
    });

    test('should handle equality correctly', () {
      final userOp1 = UserOperation(
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

      final userOp2 = UserOperation(
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

      final userOp3 = UserOperation(
        sender: '0x1234567890123456789012345678901234567890',
        nonce: BigInt.from(2), // Different nonce
        callData: '0xabcdef',
        callGasLimit: BigInt.from(100000),
        verificationGasLimit: BigInt.from(50000),
        preVerificationGas: BigInt.from(21000),
        maxFeePerGas: BigInt.from(20000000000),
        maxPriorityFeePerGas: BigInt.from(1000000000),
        signature: '0x1234',
      );

      expect(userOp1, equals(userOp2));
      expect(userOp1.hashCode, equals(userOp2.hashCode));
      expect(userOp1, isNot(equals(userOp3)));
    });
  });

  group('UserOperationGasEstimate', () {
    test('should create from JSON correctly', () {
      final json = {
        'preVerificationGas': '0x5208',
        'verificationGasLimit': '0xc350',
        'callGasLimit': '0x186a0',
        'paymasterVerificationGasLimit': '0x7530',
        'paymasterPostOpGasLimit': '0x4e20',
      };

      final estimate = UserOperationGasEstimate.fromJson(json);

      expect(estimate.preVerificationGas, equals(BigInt.from(21000)));
      expect(estimate.verificationGasLimit, equals(BigInt.from(50000)));
      expect(estimate.callGasLimit, equals(BigInt.from(100000)));
      expect(estimate.paymasterVerificationGasLimit, equals(BigInt.from(30000)));
      expect(estimate.paymasterPostOpGasLimit, equals(BigInt.from(20000)));
    });

    test('should handle optional paymaster fields', () {
      final json = {
        'preVerificationGas': '0x5208',
        'verificationGasLimit': '0xc350',
        'callGasLimit': '0x186a0',
      };

      final estimate = UserOperationGasEstimate.fromJson(json);

      expect(estimate.preVerificationGas, equals(BigInt.from(21000)));
      expect(estimate.verificationGasLimit, equals(BigInt.from(50000)));
      expect(estimate.callGasLimit, equals(BigInt.from(100000)));
      expect(estimate.paymasterVerificationGasLimit, isNull);
      expect(estimate.paymasterPostOpGasLimit, isNull);
    });
  });

  group('UserOperationReceipt', () {
    test('should create from JSON correctly', () {
      final json = {
        'userOpHash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'sender': '0x1234567890123456789012345678901234567890',
        'nonce': '0x1',
        'paymaster': '0xabcdef0123456789012345678901234567890123',
        'actualGasCost': '0x5208',
        'actualGasUsed': '0xc350',
        'success': true,
        'entryPoint': '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
        'receipt': {
          'transactionHash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'blockNumber': '0x123456',
        },
      };

      final receipt = UserOperationReceipt.fromJson(json);

      expect(receipt.userOpHash, equals('0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'));
      expect(receipt.sender, equals('0x1234567890123456789012345678901234567890'));
      expect(receipt.nonce, equals(BigInt.from(1)));
      expect(receipt.paymaster, equals('0xabcdef0123456789012345678901234567890123'));
      expect(receipt.actualGasCost, equals(BigInt.from(21000)));
      expect(receipt.actualGasUsed, equals(BigInt.from(50000)));
      expect(receipt.success, isTrue);
      expect(receipt.entryPoint, equals('0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'));
      expect(receipt.receipt, isA<Map<String, dynamic>>());
    });

    test('should handle optional fields', () {
      final json = {
        'userOpHash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'sender': '0x1234567890123456789012345678901234567890',
        'nonce': '0x1',
        'actualGasCost': '0x5208',
        'actualGasUsed': '0xc350',
        'success': false,
        'reason': 'execution reverted',
        'entryPoint': '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
        'receipt': <String, dynamic>{},
      };

      final receipt = UserOperationReceipt.fromJson(json);

      expect(receipt.paymaster, isNull);
      expect(receipt.success, isFalse);
      expect(receipt.reason, equals('execution reverted'));
    });
  });

  group('EntryPointVersion', () {
    test('should have correct version strings', () {
      expect(EntryPointVersion.v06.version, equals('0.6'));
      expect(EntryPointVersion.v07.version, equals('0.7'));
      expect(EntryPointVersion.v08.version, equals('0.8'));
      expect(EntryPointVersion.v09.version, equals('0.9'));
    });
  });
}
