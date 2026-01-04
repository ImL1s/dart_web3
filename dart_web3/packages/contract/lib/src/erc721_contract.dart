import 'contract.dart';
import 'event_filter.dart';

/// ERC-721 NFT contract implementation.
class ERC721Contract extends Contract {
  ERC721Contract({
    required super.address,
    required super.publicClient,
    super.walletClient,
  }) : super(
          abi: _erc721Abi,
        );

  static const String _erc721Abi = '''
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
      "name": "tokenURI",
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [{"name": "owner", "type": "address"}],
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "ownerOf",
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getApproved",
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isApprovedForAll",
      "inputs": [
        {"name": "owner", "type": "address"},
        {"name": "operator", "type": "address"}
      ],
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "approve",
      "inputs": [
        {"name": "to", "type": "address"},
        {"name": "tokenId", "type": "uint256"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
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
      "name": "transferFrom",
      "inputs": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "tokenId", "type": "uint256"}
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
        {"name": "tokenId", "type": "uint256"}
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
        {"name": "tokenId", "type": "uint256"},
        {"name": "data", "type": "bytes"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "Transfer",
      "inputs": [
        {"name": "from", "type": "address", "indexed": true},
        {"name": "to", "type": "address", "indexed": true},
        {"name": "tokenId", "type": "uint256", "indexed": true}
      ]
    },
    {
      "type": "event",
      "name": "Approval",
      "inputs": [
        {"name": "owner", "type": "address", "indexed": true},
        {"name": "approved", "type": "address", "indexed": true},
        {"name": "tokenId", "type": "uint256", "indexed": true}
      ]
    },
    {
      "type": "event",
      "name": "ApprovalForAll",
      "inputs": [
        {"name": "owner", "type": "address", "indexed": true},
        {"name": "operator", "type": "address", "indexed": true},
        {"name": "approved", "type": "bool", "indexed": false}
      ]
    }
  ]''';

  // Type-safe methods

  /// Gets the collection name.
  Future<String> name() async {
    final result = await read('name', []);
    return result[0] as String;
  }

  /// Gets the collection symbol.
  Future<String> symbol() async {
    final result = await read('symbol', []);
    return result[0] as String;
  }

  /// Gets the token URI for metadata.
  Future<String> tokenURI(BigInt tokenId) async {
    final result = await read('tokenURI', [tokenId]);
    return result[0] as String;
  }

  /// Gets the balance (number of tokens) of an owner.
  Future<BigInt> balanceOf(String owner) async {
    final result = await read('balanceOf', [owner]);
    return result[0] as BigInt;
  }

  /// Gets the owner of a token.
  Future<String> ownerOf(BigInt tokenId) async {
    final result = await read('ownerOf', [tokenId]);
    return result[0] as String;
  }

  /// Gets the approved address for a token.
  Future<String> getApproved(BigInt tokenId) async {
    final result = await read('getApproved', [tokenId]);
    return result[0] as String;
  }

  /// Checks if an operator is approved for all tokens of an owner.
  Future<bool> isApprovedForAll(String owner, String operator) async {
    final result = await read('isApprovedForAll', [owner, operator]);
    return result[0] as bool;
  }

  /// Approves an address to transfer a specific token.
  Future<String> approve(String to, BigInt tokenId) async {
    return write('approve', [to, tokenId]);
  }

  /// Sets approval for all tokens.
  Future<String> setApprovalForAll(String operator, bool approved) async {
    return write('setApprovalForAll', [operator, approved]);
  }

  /// Transfers a token from one address to another.
  Future<String> transferFrom(String from, String to, BigInt tokenId) async {
    return write('transferFrom', [from, to, tokenId]);
  }

  /// Safely transfers a token (checks if recipient can receive NFTs).
  Future<String> safeTransferFrom(String from, String to, BigInt tokenId,
      [String? data]) async {
    if (data != null) {
      return write('safeTransferFrom', [from, to, tokenId, data]);
    } else {
      return write('safeTransferFrom', [from, to, tokenId]);
    }
  }

  // Event filters

  /// Creates a filter for Transfer events.
  EventFilter transferFilter({String? from, String? to, BigInt? tokenId}) {
    return createEventFilter(
      'Transfer',
      indexedArgs: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (tokenId != null) 'tokenId': tokenId,
      },
    );
  }

  /// Creates a filter for Approval events.
  EventFilter approvalFilter(
      {String? owner, String? approved, BigInt? tokenId}) {
    return createEventFilter(
      'Approval',
      indexedArgs: {
        if (owner != null) 'owner': owner,
        if (approved != null) 'approved': approved,
        if (tokenId != null) 'tokenId': tokenId,
      },
    );
  }

  /// Creates a filter for ApprovalForAll events.
  EventFilter approvalForAllFilter({String? owner, String? operator}) {
    return createEventFilter(
      'ApprovalForAll',
      indexedArgs: {
        if (owner != null) 'owner': owner,
        if (operator != null) 'operator': operator,
      },
    );
  }
}
