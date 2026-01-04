import 'package:test/test.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';

import 'mock_client.dart';

void main() {
  group('ERC20Contract', () {
    late MockPublicClient mockPublicClient;
    late MockWalletClient mockWalletClient;
    late ERC20Contract contract;

    const contractAddress = '0x1234567890123456789012345678901234567890';

    setUp(() {
      mockPublicClient = MockPublicClient();
      mockWalletClient = MockWalletClient();
      contract = ERC20Contract(
        address: contractAddress,
        publicClient: mockPublicClient,
        walletClient: mockWalletClient,
      );
    });

    group('read methods', () {
      test('should get token name', () async {
        // Arrange
        final encodedName = AbiEncoder.encode([AbiString()], ['Test Token']);
        mockPublicClient.mockCall(encodedName);

        // Act
        final name = await contract.name();

        // Assert
        expect(name, equals('Test Token'));
      });

      test('should get token symbol', () async {
        // Arrange
        final encodedSymbol = AbiEncoder.encode([AbiString()], ['TEST']);
        mockPublicClient.mockCall(encodedSymbol);

        // Act
        final symbol = await contract.symbol();

        // Assert
        expect(symbol, equals('TEST'));
      });

      test('should get token decimals', () async {
        // Arrange
        final encodedDecimals =
            AbiEncoder.encode([AbiUint(8)], [BigInt.from(18)]);
        mockPublicClient.mockCall(encodedDecimals);

        // Act
        final decimals = await contract.decimals();

        // Assert
        expect(decimals, equals(18));
      });

      test('should get total supply', () async {
        // Arrange
        final totalSupply =
            BigInt.parse('1000000000000000000000000'); // 1M tokens
        final encodedSupply = AbiEncoder.encode([AbiUint(256)], [totalSupply]);
        mockPublicClient.mockCall(encodedSupply);

        // Act
        final supply = await contract.totalSupply();

        // Assert
        expect(supply, equals(totalSupply));
      });

      test('should get balance of account', () async {
        // Arrange
        final balance = BigInt.parse('1000000000000000000000'); // 1000 tokens
        final encodedBalance = AbiEncoder.encode([AbiUint(256)], [balance]);
        mockPublicClient.mockCall(encodedBalance);

        // Act
        final result = await contract
            .balanceOf('0x1111111111111111111111111111111111111111');

        // Assert
        expect(result, equals(balance));
      });

      test('should get allowance', () async {
        // Arrange
        final allowance = BigInt.parse('500000000000000000000'); // 500 tokens
        final encodedAllowance = AbiEncoder.encode([AbiUint(256)], [allowance]);
        mockPublicClient.mockCall(encodedAllowance);

        // Act
        final result = await contract.allowance(
            '0x1111111111111111111111111111111111111111',
            '0x2222222222222222222222222222222222222222');

        // Assert
        expect(result, equals(allowance));
      });
    });

    group('write methods', () {
      test('should transfer tokens', () async {
        // Arrange
        const expectedTxHash = '0xabcdef';
        mockWalletClient.mockSendTransaction(expectedTxHash);

        // Act
        final txHash = await contract.transfer(
            '0x1111111111111111111111111111111111111111', BigInt.from(1000));

        // Assert
        expect(txHash, equals(expectedTxHash));
        expect(mockWalletClient.lastTransactionRequest?.to,
            equals(contractAddress));
      });

      test('should approve spender', () async {
        // Arrange
        const expectedTxHash = '0xabcdef';
        mockWalletClient.mockSendTransaction(expectedTxHash);

        // Act
        final txHash = await contract.approve(
            '0x2222222222222222222222222222222222222222', BigInt.from(1000));

        // Assert
        expect(txHash, equals(expectedTxHash));
      });

      test('should transfer from approved account', () async {
        // Arrange
        const expectedTxHash = '0xabcdef';
        mockWalletClient.mockSendTransaction(expectedTxHash);

        // Act
        final txHash = await contract.transferFrom(
            '0x1111111111111111111111111111111111111111',
            '0x2222222222222222222222222222222222222222',
            BigInt.from(1000));

        // Assert
        expect(txHash, equals(expectedTxHash));
      });
    });

    group('event filters', () {
      test('should create transfer filter', () {
        // Act
        final filter = contract.transferFilter(
            from: '0x1111111111111111111111111111111111111111',
            to: '0x2222222222222222222222222222222222222222');

        // Assert
        expect(filter.address, equals(contractAddress));
        expect(filter.event?.name, equals('Transfer'));
      });

      test('should create approval filter', () {
        // Act
        final filter = contract.approvalFilter(
            owner: '0x1111111111111111111111111111111111111111',
            spender: '0x2222222222222222222222222222222222222222');

        // Assert
        expect(filter.address, equals(contractAddress));
        expect(filter.event?.name, equals('Approval'));
      });
    });
  });
}
