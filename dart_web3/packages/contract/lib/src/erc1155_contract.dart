import 'package:dart_web3_client/dart_web3_client.dart';

import 'contract.dart';
import 'event_filter.dart';

/// ERC-1155 multi-token contract implementation.
class ERC1155Contract extends Contract {
  ERC1155Contract({
    required String address,
    required PublicClient publicClient,
    WalletClient? walletClient,
  }) : super(
          address: address,
          abi: _erc1155Abi,
          publicClient: publicClient,
          walletClient: walletClient,
        );

  static const String _erc1155Abi = '''[
    {
      "type": "function",
      "name": "uri",
      "inputs": [{"name": "id", "type": "uint256"}],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [
        {"name": "account", "type": "address"},
        {"name": "id", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "balanceOfBatch",
      "inputs": [
        {"name": "accounts", "type": "address[]"},
        {"name": "ids", "type": "uint256[]"}
      ],
      "outputs": [{"name": "", "type": "uint256[]"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isApprovedForAll",
      "inputs": [
        {"name": "account", "type": "address"},
        {"name": "operator", "type": "address"}
      ],
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "setApprovalForAll",
      "inputs": [
        {"name": "operator", "type": "address"},
        {"name": "approved", "type": "bool"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "safeTransferFrom",
      "inputs": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "id", "type": "uint256"},
        {"name": "amount", "type": "uint256"},
        {"name": "data", "type": "bytes"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "safeBatchTransferFrom",
      "inputs": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "ids", "type": "uint256[]"},
        {"name": "amounts", "type": "uint256[]"},
        {"name": "data", "type": "bytes"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "TransferSingle",
      "inputs": [
        {"name": "operator", "type": "address", "indexed": true},
        {"name": "from", "type": "address", "indexed": true},
        {"name": "to", "type": "address", "indexed": true},
        {"name": "id", "type": "uint256", "indexed": false},
        {"name": "value", "type": "uint256", "indexed": false}
      ]
    },
    {
      "type": "event",
      "name": "TransferBatch",
      "inputs": [
        {"name": "operator", "type": "address", "indexed": true},
        {"name": "from", "type": "address", "indexed": true},
        {"name": "to", "type": "address", "indexed": true},
        {"name": "ids", "type": "uint256[]", "indexed": false},
        {"name": "values", "type": "uint256[]", "indexed": false}
      ]
    },
    {
      "type": "event",
      "name": "ApprovalForAll",
      "inputs": [
        {"name": "account", "type": "address", "indexed": true},
        {"name": "operator", "type": "address", "indexed": true},
        {"name": "approved", "type": "bool", "indexed": false}
      ]
    },
    {
      "type": "event",
      "name": "URI",
      "inputs": [
        {"name": "value", "type": "string", "indexed": false},
        {"name": "id", "type": "uint256", "indexed": true}
      ]
    }
  ]''';

  // Type-safe methods

  /// Gets the URI for a token type.
  Future<String> uri(BigInt id) async {
    final result = await read('uri', [id]);
    return result[0] as String;
  }

  /// Gets the balance of a token type for an account.
  Future<BigInt> balanceOf(String account, BigInt id) async {
    final result = await read('balanceOf', [account, id]);
    return result[0] as BigInt;
  }

  /// Gets the balances of multiple token types for multiple accounts.
  Future<List<BigInt>> balanceOfBatch(List<String> accounts, List<BigInt> ids) async {
    final result = await read('balanceOfBatch', [accounts, ids]);
    return (result[0] as List).cast<BigInt>();
  }

  /// Checks if an operator is approved for all tokens of an account.
  Future<bool> isApprovedForAll(String account, String operator) async {
    final result = await read('isApprovedForAll', [account, operator]);
    return result[0] as bool;
  }

  /// Sets approval for all tokens.
  Future<String> setApprovalForAll(String operator, bool approved) async {
    return await write('setApprovalForAll', [operator, approved]);
  }

  /// Safely transfers a single token type.
  Future<String> safeTransferFrom(
    String from,
    String to,
    BigInt id,
    BigInt amount, [
    String data = '0x',
  ]) async {
    return await write('safeTransferFrom', [from, to, id, amount, data]);
  }

  /// Safely transfers multiple token types in batch.
  Future<String> safeBatchTransferFrom(
    String from,
    String to,
    List<BigInt> ids,
    List<BigInt> amounts, [
    String data = '0x',
  ]) async {
    return await write('safeBatchTransferFrom', [from, to, ids, amounts, data]);
  }

  // Event filters

  /// Creates a filter for TransferSingle events.
  EventFilter transferSingleFilter({
    String? operator,
    String? from,
    String? to,
  }) {
    return createEventFilter('TransferSingle', indexedArgs: {
      if (operator != null) 'operator': operator,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
  }

  /// Creates a filter for TransferBatch events.
  EventFilter transferBatchFilter({
    String? operator,
    String? from,
    String? to,
  }) {
    return createEventFilter('TransferBatch', indexedArgs: {
      if (operator != null) 'operator': operator,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
  }

  /// Creates a filter for ApprovalForAll events.
  EventFilter approvalForAllFilter({String? account, String? operator}) {
    return createEventFilter('ApprovalForAll', indexedArgs: {
      if (account != null) 'account': account,
      if (operator != null) 'operator': operator,
    });
  }

  /// Creates a filter for URI events.
  EventFilter uriFilter({BigInt? id}) {
    return createEventFilter('URI', indexedArgs: {
      if (id != null) 'id': id,
    });
  }
}