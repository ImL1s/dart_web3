
import 'contract.dart';
import 'event_filter.dart';

/// ERC-20 token contract implementation.
class ERC20Contract extends Contract {
  ERC20Contract({
    required super.address,
    required super.publicClient,
    super.walletClient,
  }) : super(
          abi: _erc20Abi,
        );

  static const String _erc20Abi = '''
[
    {
      "type": "function",
      "name": "name",
      "inputs": [],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "symbol",
      "inputs": [],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "decimals",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint8"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "totalSupply",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [{"name": "account", "type": "address"}],
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "allowance",
      "inputs": [
        {"name": "owner", "type": "address"},
        {"name": "spender", "type": "address"}
      ],
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
      "type": "function",
      "name": "approve",
      "inputs": [
        {"name": "spender", "type": "address"},
        {"name": "amount", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "transferFrom",
      "inputs": [
        {"name": "from", "type": "address"},
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
    },
    {
      "type": "event",
      "name": "Approval",
      "inputs": [
        {"name": "owner", "type": "address", "indexed": true},
        {"name": "spender", "type": "address", "indexed": true},
        {"name": "value", "type": "uint256", "indexed": false}
      ]
    }
  ]''';

  // Type-safe methods

  /// Gets the token name.
  Future<String> name() async {
    final result = await read('name', []);
    return result[0] as String;
  }

  /// Gets the token symbol.
  Future<String> symbol() async {
    final result = await read('symbol', []);
    return result[0] as String;
  }

  /// Gets the token decimals.
  Future<int> decimals() async {
    final result = await read('decimals', []);
    return (result[0] as BigInt).toInt();
  }

  /// Gets the total supply.
  Future<BigInt> totalSupply() async {
    final result = await read('totalSupply', []);
    return result[0] as BigInt;
  }

  /// Gets the balance of an account.
  Future<BigInt> balanceOf(String account) async {
    final result = await read('balanceOf', [account]);
    return result[0] as BigInt;
  }

  /// Gets the allowance from owner to spender.
  Future<BigInt> allowance(String owner, String spender) async {
    final result = await read('allowance', [owner, spender]);
    return result[0] as BigInt;
  }

  /// Transfers tokens to another account.
  Future<String> transfer(String to, BigInt amount) async {
    return write('transfer', [to, amount]);
  }

  /// Approves a spender to spend tokens.
  Future<String> approve(String spender, BigInt amount) async {
    return write('approve', [spender, amount]);
  }

  /// Transfers tokens from one account to another (requires allowance).
  Future<String> transferFrom(String from, String to, BigInt amount) async {
    return write('transferFrom', [from, to, amount]);
  }

  // Event filters

  /// Creates a filter for Transfer events.
  EventFilter transferFilter({String? from, String? to}) {
    return createEventFilter('Transfer', indexedArgs: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    },);
  }

  /// Creates a filter for Approval events.
  EventFilter approvalFilter({String? owner, String? spender}) {
    return createEventFilter('Approval', indexedArgs: {
      if (owner != null) 'owner': owner,
      if (spender != null) 'spender': spender,
    },);
  }
}
