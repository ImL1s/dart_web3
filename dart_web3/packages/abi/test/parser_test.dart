import 'dart:convert';

import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:test/test.dart';

void main() {
  group('AbiParser Tests', () {
    final erc20Abi = json.encode([
      {
        'type': 'function',
        'name': 'transfer',
        'inputs': [
          {'name': 'to', 'type': 'address'},
          {'name': 'amount', 'type': 'uint256'},
        ],
        'outputs': [
          {'name': '', 'type': 'bool'},
        ],
        'stateMutability': 'nonpayable',
      },
      {
        'type': 'function',
        'name': 'balanceOf',
        'inputs': [
          {'name': 'account', 'type': 'address'},
        ],
        'outputs': [
          {'name': '', 'type': 'uint256'},
        ],
        'stateMutability': 'view',
      },
      {
        'type': 'event',
        'name': 'Transfer',
        'inputs': [
          {'name': 'from', 'type': 'address', 'indexed': true},
          {'name': 'to', 'type': 'address', 'indexed': true},
          {'name': 'value', 'type': 'uint256', 'indexed': false},
        ],
        'anonymous': false,
      },
      {
        'type': 'error',
        'name': 'InsufficientBalance',
        'inputs': [
          {'name': 'available', 'type': 'uint256'},
          {'name': 'required', 'type': 'uint256'},
        ],
      },
    ]);

    group('parseFunctions', () {
      test('parses functions correctly', () {
        final functions = AbiParser.parseFunctions(erc20Abi);

        expect(functions.length, equals(2));
        expect(functions[0].name, equals('transfer'));
        expect(functions[1].name, equals('balanceOf'));
      });

      test('parses function inputs correctly', () {
        final functions = AbiParser.parseFunctions(erc20Abi);
        final transfer = functions[0];

        expect(transfer.inputs.length, equals(2));
        expect(transfer.inputs[0].name, equals('address'));
        expect(transfer.inputs[1].name, equals('uint256'));
        expect(transfer.inputNames[0], equals('to'));
        expect(transfer.inputNames[1], equals('amount'));
      });

      test('parses function outputs correctly', () {
        final functions = AbiParser.parseFunctions(erc20Abi);
        final transfer = functions[0];

        expect(transfer.outputs.length, equals(1));
        expect(transfer.outputs[0].name, equals('bool'));
      });

      test('parses stateMutability correctly', () {
        final functions = AbiParser.parseFunctions(erc20Abi);

        expect(functions[0].stateMutability, equals('nonpayable'));
        expect(functions[1].stateMutability, equals('view'));
        expect(functions[0].isReadOnly, isFalse);
        expect(functions[1].isReadOnly, isTrue);
      });

      test('generates correct signature', () {
        final functions = AbiParser.parseFunctions(erc20Abi);

        expect(functions[0].signature, equals('transfer(address,uint256)'));
        expect(functions[1].signature, equals('balanceOf(address)'));
      });
    });

    group('parseEvents', () {
      test('parses events correctly', () {
        final events = AbiParser.parseEvents(erc20Abi);

        expect(events.length, equals(1));
        expect(events[0].name, equals('Transfer'));
      });

      test('parses event inputs correctly', () {
        final events = AbiParser.parseEvents(erc20Abi);
        final transfer = events[0];

        expect(transfer.inputs.length, equals(3));
        expect(transfer.indexed[0], isTrue);
        expect(transfer.indexed[1], isTrue);
        expect(transfer.indexed[2], isFalse);
      });

      test('parses anonymous flag correctly', () {
        final events = AbiParser.parseEvents(erc20Abi);

        expect(events[0].anonymous, isFalse);
      });

      test('generates correct signature', () {
        final events = AbiParser.parseEvents(erc20Abi);

        expect(events[0].signature, equals('Transfer(address,address,uint256)'));
      });
    });

    group('parseErrors', () {
      test('parses errors correctly', () {
        final errors = AbiParser.parseErrors(erc20Abi);

        expect(errors.length, equals(1));
        expect(errors[0].name, equals('InsufficientBalance'));
      });

      test('parses error inputs correctly', () {
        final errors = AbiParser.parseErrors(erc20Abi);
        final error = errors[0];

        expect(error.inputs.length, equals(2));
        expect(error.inputNames[0], equals('available'));
        expect(error.inputNames[1], equals('required'));
      });

      test('generates correct signature', () {
        final errors = AbiParser.parseErrors(erc20Abi);

        expect(errors[0].signature, equals('InsufficientBalance(uint256,uint256)'));
      });
    });

    group('parseType', () {
      test('parses basic types', () {
        expect(AbiParser.parseType('uint256').name, equals('uint256'));
        expect(AbiParser.parseType('int128').name, equals('int128'));
        expect(AbiParser.parseType('address').name, equals('address'));
        expect(AbiParser.parseType('bool').name, equals('bool'));
        expect(AbiParser.parseType('string').name, equals('string'));
        expect(AbiParser.parseType('bytes').name, equals('bytes'));
        expect(AbiParser.parseType('bytes32').name, equals('bytes32'));
      });

      test('parses array types', () {
        final dynamicArray = AbiParser.parseType('uint256[]');
        expect(dynamicArray.name, equals('uint256[]'));
        expect(dynamicArray.isDynamic, isTrue);

        final fixedArray = AbiParser.parseType('uint256[3]');
        expect(fixedArray.name, equals('uint256[3]'));
      });

      test('parses tuple types', () {
        final tuple = AbiParser.parseType('(uint256,address)');
        expect(tuple.name, equals('(uint256,address)'));
        expect((tuple as AbiTuple).components.length, equals(2));
      });
    });

    group('tuple parsing in functions', () {
      test('parses tuple inputs correctly', () {
        final abiWithTuple = json.encode([
          {
            'type': 'function',
            'name': 'execute',
            'inputs': [
              {
                'name': 'params',
                'type': 'tuple',
                'components': [
                  {'name': 'target', 'type': 'address'},
                  {'name': 'value', 'type': 'uint256'},
                  {'name': 'data', 'type': 'bytes'},
                ],
              },
            ],
            'outputs': <Map<String, dynamic>>[],
            'stateMutability': 'nonpayable',
          },
        ]);

        final functions = AbiParser.parseFunctions(abiWithTuple);
        expect(functions.length, equals(1));

        final input = functions[0].inputs[0];
        expect(input, isA<AbiTuple>());
        expect((input as AbiTuple).components.length, equals(3));
      });
    });
  });
}
