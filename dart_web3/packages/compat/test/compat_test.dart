import 'package:test/test.dart';
import 'package:dart_web3_compat/dart_web3_compat.dart';
import 'dart:typed_data';

void main() {
  group('EtherAmount', () {
    test('conversions', () {
      final amount = EtherAmount.fromBigInt(EtherUnit.ether, BigInt.one);
      expect(amount.getInWei, BigInt.parse('1000000000000000000'));
      expect(amount.getValueInUnitBI(EtherUnit.gwei), BigInt.from(1000000000));
    });
  });

  group('ContractEvent', () {
    test('decodeResults', () {
      final abiJson =
          '[{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]';
      final abi = ContractAbi.fromJson(abiJson, 'ERC20');
      final event = abi.events.first;

      final topics = [
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef', // Transfer signature
        '0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045', // from
        '0x000000000000000000000000be0eb53f46cd79075025235600404c08ea7cc0e4', // to
      ];
      final data =
          '0x0000000000000000000000000000000000000000000000000de0b6b3a7640000'; // value (1 ETH)

      final results = event.decodeResults(topics, data);

      expect(
        results[0].toString(),
        '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
      );
      expect(
        results[1].toString(),
        '0xbe0eb53f46cd79075025235600404c08ea7cc0e4',
      );
      expect(results[2], BigInt.parse('1000000000000000000'));
    });
  });

  group('HexUtils', () {
    test('encoding/decoding', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final hex = HexUtils.bytesToHex(bytes, include0x: true);
      expect(hex, '0x010203');
      expect(HexUtils.hexToBytes(hex), bytes);
    });
  });

  group('Address Utils', () {
    test('publicKeyToAddress with compressed key', () {
      // Using a random private key for deterministic test:
      // PK: 1
      // Pub (compressed): 0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798
      // Address: 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf

      final compressed = HexUtils.hexToBytes(
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798');
      final address = publicKeyToAddress(compressed);
      expect(HexUtils.bytesToHex(address, include0x: true),
          '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf');
    });
  });

  group('Web3Client', () {
    test('Can be initialized with custom chain', () {
      final client = Web3Client(
        'https://rpc.example.com',
        null,
        chain: Web3ChainConfig(
          chainId: 137,
          name: 'Polygon',
          shortName: 'matic',
          nativeCurrency: 'MATIC',
          symbol: 'MATIC',
          decimals: 18,
          rpcUrls: ['https://rpc.example.com'],
          blockExplorerUrls: [],
        ),
      );
      // We can't easily test internal state without reflection or getters,
      // but successful instantiation confirms API compatibility.
      expect(client, isNotNull);
    });
  });
}
