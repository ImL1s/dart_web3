import 'package:dart_web3_contract/dart_web3_contract.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() {
  group('ContractFactory', () {
    late MockPublicClient mockPublicClient;
    late MockWalletClient mockWalletClient;

    const contractAddress = '0x1234567890123456789012345678901234567890';
    const simpleAbi = '''
[
      {
        "type": "function",
        "name": "getValue",
        "inputs": [],
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view"
      }
    ]''';

    setUp(() {
      mockPublicClient = MockPublicClient();
      mockWalletClient = MockWalletClient();
    });

    group('create', () {
      test('should create contract instance', () {
        // Act
        final contract = ContractFactory.create(
          address: contractAddress,
          abi: simpleAbi,
          publicClient: mockPublicClient,
          walletClient: mockWalletClient,
        );

        // Assert
        expect(contract.address, equals(contractAddress));
        expect(contract.publicClient, equals(mockPublicClient));
        expect(contract.walletClient, equals(mockWalletClient));
        expect(contract.functions, hasLength(1));
        expect(contract.functions[0].name, equals('getValue'));
      });

      test('should create contract without wallet client', () {
        // Act
        final contract = ContractFactory.create(
          address: contractAddress,
          abi: simpleAbi,
          publicClient: mockPublicClient,
        );

        // Assert
        expect(contract.address, equals(contractAddress));
        expect(contract.publicClient, equals(mockPublicClient));
        expect(contract.walletClient, isNull);
      });
    });

    group('estimateDeployGas', () {
      test('should estimate gas for deployment', () async {
        // Arrange
        const bytecode = '0x608060405234801561001057600080fd5b50';
        final expectedGas = BigInt.from(100000);
        mockPublicClient.mockEstimateGas(expectedGas);

        // Act
        final gas = await ContractFactory.estimateDeployGas(
          bytecode: bytecode,
          publicClient: mockPublicClient,
          from: '0xdeployer',
        );

        // Assert
        expect(gas, equals(expectedGas));
      });

      test('should estimate gas for deployment with constructor args', () async {
        // Arrange
        const bytecode = '0x608060405234801561001057600080fd5b50';
        final expectedGas = BigInt.from(120000);
        mockPublicClient.mockEstimateGas(expectedGas);

        // Act & Assert - should throw for now since constructor args not supported
        expect(
          () => ContractFactory.estimateDeployGas(
            bytecode: bytecode,
            publicClient: mockPublicClient,
            from: '0xdeployer',
            constructorArgs: [BigInt.from(42)],
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });
  });
}
