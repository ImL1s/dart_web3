import 'dart:typed_data';

import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_contract/dart_web3_contract.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() {
  group('Contract', () {
    late MockPublicClient mockPublicClient;
    late MockWalletClient mockWalletClient;
    late Contract contract;

    const contractAddress = '0x1234567890123456789012345678901234567890';
    const erc20Abi = '''
[
      {
        "type": "function",
        "name": "balanceOf",
        "inputs": [{"name": "account", "type": "address"}],
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "nonpayable"
      },
      {
        "type": "event",
        "name": "Transfer",
        "inputs": [
          {"name": "from", "type": "address", "indexed": true},
          {"name": "to", "type": "address", "indexed": true},
          {"name": "value", "type": "uint256", "indexed": false}
        ]
      }
    ]''';

    setUp(() {
      mockPublicClient = MockPublicClient();
      mockWalletClient = MockWalletClient();
      contract = Contract(
        address: contractAddress,
        abi: erc20Abi,
        publicClient: mockPublicClient,
        walletClient: mockWalletClient,
      );
    });

    group('read operations', () {
      test('should call read-only function', () async {
        // Arrange
        final expectedBalance = BigInt.from(1000);
        final encodedBalance = AbiEncoder.encode([AbiUint(256)], [expectedBalance]);
        mockPublicClient.mockCall(encodedBalance);

        // Act
        final result = await contract.read('balanceOf', ['0x000000000000000000000000000000000000abcd']);

        // Assert
        expect(result, hasLength(1));
        expect(result[0], equals(expectedBalance));
        expect(mockPublicClient.lastCallRequest?.to, equals(contractAddress));
      });

      test('should throw for non-read-only function', () async {
        // Act & Assert
        expect(
          () => contract.read('transfer', ['0xabcd', BigInt.from(100)]),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('write operations', () {
      test('should send transaction for state-changing function', () async {
        // Arrange
        const expectedTxHash = '0xabcdef';
        mockWalletClient.mockSendTransaction(expectedTxHash);

        // Act
        final txHash = await contract.write('transfer', ['0x000000000000000000000000000000000000abcd', BigInt.from(100)]);

        // Assert
        expect(txHash, equals(expectedTxHash));
        expect(mockWalletClient.lastTransactionRequest?.to, equals(contractAddress));
      });

      test('should throw when no wallet client provided', () async {
        // Arrange
        final contractWithoutWallet = Contract(
          address: contractAddress,
          abi: erc20Abi,
          publicClient: mockPublicClient,
        );

        // Act & Assert
        expect(
          () => contractWithoutWallet.write('transfer', ['0xabcd', BigInt.from(100)]),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('gas estimation', () {
      test('should estimate gas for function call', () async {
        // Arrange
        final expectedGas = BigInt.from(21000);
        mockPublicClient.mockEstimateGas(expectedGas);

        // Act
        final gas = await contract.estimateGas('transfer', ['0x000000000000000000000000000000000000abcd', BigInt.from(100)]);

        // Assert
        expect(gas, equals(expectedGas));
      });
    });

    group('simulation', () {
      test('should simulate successful function call', () async {
        // Arrange
        final returnValue = AbiEncoder.encode([AbiBool()], [true]);
        final expectedGas = BigInt.from(21000);
        mockPublicClient.mockCall(returnValue);
        mockPublicClient.mockEstimateGas(expectedGas);

        // Act
        final result = await contract.simulate('transfer', ['0x000000000000000000000000000000000000abcd', BigInt.from(100)]);

        // Assert
        expect(result.success, isTrue);
        expect(result.result, hasLength(1));
        expect(result.result[0], isTrue);
        expect(result.gasUsed, equals(expectedGas));
        expect(result.revertReason, isNull);
      });

      test('should handle simulation failure', () async {
        // Arrange
        mockPublicClient.mockCallThrow('execution reverted: insufficient balance');

        // Act
        final result = await contract.simulate('transfer', ['0x000000000000000000000000000000000000abcd', BigInt.from(100)]);

        // Assert
        expect(result.success, isFalse);
        expect(result.result, isEmpty);
        expect(result.gasUsed, equals(BigInt.zero));
        expect(result.revertReason, isNotNull);
      });
    });

    group('event handling', () {
      test('should create event filter', () {
        // Act
        final filter = contract.createEventFilter('Transfer', indexedArgs: {
          'from': '0x0000000000000000000000000000000000001111',
          'to': '0x0000000000000000000000000000000000002222',
        },);

        // Assert
        expect(filter.address, equals(contractAddress));
        expect(filter.topics, hasLength(3));
        expect(filter.topics![0], isNotNull); // Event signature
        expect(filter.event?.name, equals('Transfer'));
      });

      test('should decode event log', () {
        // Arrange
        final eventTopic = HexUtils.encode(AbiEncoder.getEventTopic('Transfer(address,address,uint256)'));
        final log = Log(
          address: contractAddress,
          topics: [
            eventTopic,
            '0x0000000000000000000000001111111111111111111111111111111111111111',
            '0x0000000000000000000000002222222222222222222222222222222222222222',
          ],
          data: AbiEncoder.encode([AbiUint(256)], [BigInt.from(1000)]),
          blockHash: '0xblock',
          blockNumber: BigInt.from(123),
          transactionHash: '0xtx',
          transactionIndex: 0,
          logIndex: 0,
          removed: false,
        );

        // Act
        final decoded = contract.decodeEventLog(log);

        // Assert
        expect(decoded, isNotNull);
        expect(decoded!['from'], contains('1111'));
        expect(decoded['to'], contains('2222'));
        expect(decoded['value'], equals(BigInt.from(1000)));
      });

      test('should return null for unrelated log', () {
        // Arrange
        final log = Log(
          address: '0x9999999999999999999999999999999999999999',
          topics: ['0xunknown'],
          data: Uint8List(0),
          blockHash: '0xblock',
          blockNumber: BigInt.from(123),
          transactionHash: '0xtx',
          transactionIndex: 0,
          logIndex: 0,
          removed: false,
        );

        // Act
        final decoded = contract.decodeEventLog(log);

        // Assert
        expect(decoded, isNull);
      });
    });

    group('error decoding', () {
      test('should decode standard Error(string)', () {
        // Arrange - Error(string) selector + encoded string
        final errorData = BytesUtils.concat([
          Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]), // Error(string) selector
          AbiEncoder.encode([AbiString()], ['insufficient balance']),
        ]);

        // Act
        final decoded = contract.decodeError(errorData);

        // Assert
        expect(decoded, equals('insufficient balance'));
      });

      test('should return null for unknown error', () {
        // Arrange
        final errorData = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);

        // Act
        final decoded = contract.decodeError(errorData);

        // Assert
        expect(decoded, isNull);
      });
    });
  });
}
