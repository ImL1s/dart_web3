import 'package:test/test.dart';
import 'package:dart_web3_aa/dart_web3_aa.dart';

void main() {
  group('BundlerClient', () {
    late BundlerClient bundlerClient;
    late UserOperation testUserOp;

    setUp(() {
      bundlerClient = BundlerClient(
        bundlerUrl: 'https://api.stackup.sh/v1/node/test-bundler-key',
      );

      testUserOp = UserOperation(
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

    tearDown(() {
      bundlerClient.dispose();
    });

    test('should create BundlerClient with correct URL', () {
      expect(bundlerClient.bundlerUrl, equals('https://api.stackup.sh/v1/node/test-bundler-key'));
    });

    test('should have default EntryPoint address', () {
      final entryPointAddress = bundlerClient.getEntryPointAddress();
      expect(entryPointAddress, equals('0x0000000071727De22E5E9d8BAf0edAc6f37da032'));
    });

    // Note: The following tests would require a mock RPC provider
    // or actual bundler service to test properly. For now, we test
    // the structure and basic functionality.

    group('UserOperationByHashResult', () {
      test('should create from JSON correctly', () {
        final json = {
          'blockHash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          'blockNumber': '0x123456',
          'entryPoint': '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          'transactionHash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'userOperation': {
            'sender': '0x1234567890123456789012345678901234567890',
            'nonce': '0x1',
            'callData': '0xabcdef',
            'callGasLimit': '0x186a0',
            'verificationGasLimit': '0xc350',
            'preVerificationGas': '0x5208',
            'maxFeePerGas': '0x4a817c800',
            'maxPriorityFeePerGas': '0x3b9aca00',
            'signature': '0x1234',
          },
        };

        final result = UserOperationByHashResult.fromJson(json);

        expect(result.blockHash, equals('0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'));
        expect(result.blockNumber, equals(BigInt.parse('0x123456')));
        expect(result.entryPoint, equals('0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'));
        expect(result.transactionHash, equals('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'));
        expect(result.userOperation, isA<UserOperation>());
        expect(result.userOperation.sender, equals('0x1234567890123456789012345678901234567890'));
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

        final result = UserOperationByHashResult(
          blockHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          blockNumber: BigInt.parse('0x123456'),
          entryPoint: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          transactionHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          userOperation: userOp,
        );

        final json = result.toJson();

        expect(json['blockHash'], equals('0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'));
        expect(json['blockNumber'], equals('0x123456'));
        expect(json['entryPoint'], equals('0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'));
        expect(json['transactionHash'], equals('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'));
        expect(json['userOperation'], isA<Map<String, dynamic>>());
      });
    });

    group('BundlerException', () {
      test('should create from RPC error', () {
        final rpcError = {
          'code': -32602,
          'message': 'UserOperation validation failed',
          'data': {
            'reason': 'Invalid signature',
          },
        };

        final exception = BundlerException.fromRpcError(rpcError);

        expect(exception.errorCode, equals(BundlerErrorCode.validationFailed));
        expect(exception.message, equals('UserOperation validation failed'));
        expect(exception.data, equals({'reason': 'Invalid signature'}));
      });

      test('should handle unknown error codes', () {
        final rpcError = {
          'code': -99999,
          'message': 'Unknown error',
        };

        final exception = BundlerException.fromRpcError(rpcError);

        expect(exception.errorCode, equals(BundlerErrorCode.validationFailed));
        expect(exception.message, equals('Unknown error'));
        expect(exception.data, isNull);
      });

      test('should format toString correctly', () {
        final exception = BundlerException(
          errorCode: BundlerErrorCode.simulationFailed,
          message: 'Simulation failed',
          data: {'reason': 'Out of gas'},
        );

        final string = exception.toString();

        expect(string, contains('BundlerException'));
        expect(string, contains('simulationFailed'));
        expect(string, contains('Simulation failed'));
        expect(string, contains('Data: {reason: Out of gas}'));
      });
    });

    group('TimeoutException', () {
      test('should create with message and timeout', () {
        final timeout = Duration(minutes: 2);
        final exception = TimeoutException('Operation timed out', timeout);

        expect(exception.message, equals('Operation timed out'));
        expect(exception.timeout, equals(timeout));
      });

      test('should format toString correctly', () {
        final timeout = Duration(seconds: 30);
        final exception = TimeoutException('Test timeout', timeout);

        final string = exception.toString();

        expect(string, contains('TimeoutException'));
        expect(string, contains('Test timeout'));
        expect(string, contains('timeout: 0:00:30.000000'));
      });
    });

    group('BundlerErrorCode', () {
      test('should have correct error codes', () {
        expect(BundlerErrorCode.validationFailed.code, equals(-32602));
        expect(BundlerErrorCode.simulationFailed.code, equals(-32500));
        expect(BundlerErrorCode.paymasterRejected.code, equals(-32501));
        expect(BundlerErrorCode.opcodeValidationFailed.code, equals(-32502));
        expect(BundlerErrorCode.timeRangeValidationFailed.code, equals(-32503));
        expect(BundlerErrorCode.paymasterValidationFailed.code, equals(-32504));
        expect(BundlerErrorCode.paymasterDepositTooLow.code, equals(-32505));
        expect(BundlerErrorCode.unsupportedSignatureAggregator.code, equals(-32506));
        expect(BundlerErrorCode.invalidSignatureAggregator.code, equals(-32507));
      });

      test('should have correct names', () {
        expect(BundlerErrorCode.validationFailed.name, equals('validationFailed'));
        expect(BundlerErrorCode.simulationFailed.name, equals('simulationFailed'));
        expect(BundlerErrorCode.paymasterRejected.name, equals('paymasterRejected'));
      });
    });
  });
}