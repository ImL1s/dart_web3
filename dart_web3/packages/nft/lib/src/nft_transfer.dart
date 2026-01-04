import 'dart:async';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'nft_types.dart';

/// NFT transfer manager for handling NFT transfers with approval management
class NftTransferManager {
  NftTransferManager({
    required WalletClient client,
  }) : _client = client;
  final WalletClient _client;

  /// Transfer NFT with automatic approval handling
  Future<String> transferNft(NftTransferParams params) async {
    // Check and handle approvals first
    if (params.requireApproval) {
      await _ensureApproval(params);
    }

    // Execute the transfer
    return _executeTransfer(params);
  }

  /// Check if approval is needed for NFT transfer
  Future<bool> needsApproval(NftTransferParams params) async {
    try {
      if (params.standard == NftStandard.erc721) {
        return await _needsErc721Approval(params);
      } else if (params.standard == NftStandard.erc1155) {
        return await _needsErc1155Approval(params);
      }
      return false;
    } on Exception catch (_) {
      return true; // Assume approval needed on error
    }
  }

  /// Approve NFT for transfer
  Future<String> approveNft(NftTransferParams params) async {
    if (params.standard == NftStandard.erc721) {
      return _approveErc721(params);
    } else if (params.standard == NftStandard.erc1155) {
      return _approveErc1155(params);
    } else {
      throw Exception('Unsupported NFT standard: ${params.standard}');
    }
  }

  /// Get approval status for NFT
  Future<bool> isApproved(NftTransferParams params) async {
    try {
      if (params.standard == NftStandard.erc721) {
        return await _isErc721Approved(params);
      } else if (params.standard == NftStandard.erc1155) {
        return await _isErc1155Approved(params);
      }
      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Estimate gas for NFT transfer
  Future<BigInt> estimateTransferGas(NftTransferParams params) async {
    if (params.standard == NftStandard.erc721) {
      final contract = Contract(
        address: params.contractAddress.hex,
        abi: _erc721AbiJson,
        publicClient: _client,
      );

      return contract.estimateGas(
        'safeTransferFrom',
        [params.from.hex, params.to.hex, params.tokenId],
        from: params.from.hex,
      );
    } else if (params.standard == NftStandard.erc1155) {
      final contract = Contract(
        address: params.contractAddress.hex,
        abi: _erc1155AbiJson,
        publicClient: _client,
      );

      final amount = params.amount ?? BigInt.one;
      return contract.estimateGas(
        'safeTransferFrom',
        [params.from.hex, params.to.hex, params.tokenId, amount, '0x'],
        from: params.from.hex,
      );
    } else {
      throw Exception('Unsupported NFT standard: ${params.standard}');
    }
  }

  /// Batch transfer multiple NFTs
  Future<List<String>> batchTransferNfts(
      List<NftTransferParams> transfers) async {
    final results = <String>[];

    for (final transfer in transfers) {
      try {
        final txHash = await transferNft(transfer);
        results.add(txHash);
      } catch (e) {
        rethrow; // Stop on first error
      }
    }

    return results;
  }

  /// Ensure approval is granted for transfer
  Future<void> _ensureApproval(NftTransferParams params) async {
    final needsApproval = await this.needsApproval(params);
    if (needsApproval) {
      await approveNft(params);
    }
  }

  /// Execute the actual NFT transfer
  Future<String> _executeTransfer(NftTransferParams params) async {
    if (params.standard == NftStandard.erc721) {
      final contract = Contract(
        address: params.contractAddress.hex,
        abi: _erc721AbiJson,
        publicClient: _client,
        walletClient: _client,
      );

      return contract.write(
        'safeTransferFrom',
        [params.from.hex, params.to.hex, params.tokenId],
      );
    } else if (params.standard == NftStandard.erc1155) {
      final contract = Contract(
        address: params.contractAddress.hex,
        abi: _erc1155AbiJson,
        publicClient: _client,
        walletClient: _client,
      );

      final amount = params.amount ?? BigInt.one;
      return contract.write(
        'safeTransferFrom',
        [params.from.hex, params.to.hex, params.tokenId, amount, '0x'],
      );
    } else {
      throw Exception('Unsupported NFT standard: ${params.standard}');
    }
  }

  /// Check if ERC-721 needs approval
  Future<bool> _needsErc721Approval(NftTransferParams params) async {
    final contract = Contract(
      address: params.contractAddress.hex,
      abi: _erc721AbiJson,
      publicClient: _client,
    );

    // Check if approved for all
    final isApprovedForAll = await contract.read('isApprovedForAll', [
      params.from.hex,
      params.to.hex,
    ]) as bool;

    if (isApprovedForAll) return false;

    // Check specific token approval
    final approvedAddress = await contract.read('getApproved', [
      params.tokenId,
    ]) as String;

    return EthereumAddress.fromHex(approvedAddress) != params.to;
  }

  /// Check if ERC-1155 needs approval
  Future<bool> _needsErc1155Approval(NftTransferParams params) async {
    final contract = Contract(
      address: params.contractAddress.hex,
      abi: _erc1155AbiJson,
      publicClient: _client,
    );

    final isApprovedForAll = await contract.read('isApprovedForAll', [
      params.from.hex,
      params.to.hex,
    ]) as bool;

    return !isApprovedForAll;
  }

  /// Approve ERC-721 token
  Future<String> _approveErc721(NftTransferParams params) async {
    final contract = Contract(
      address: params.contractAddress.hex,
      abi: _erc721AbiJson,
      publicClient: _client,
      walletClient: _client,
    );

    return contract.write(
      'approve',
      [params.to.hex, params.tokenId],
    );
  }

  /// Approve ERC-1155 tokens
  Future<String> _approveErc1155(NftTransferParams params) async {
    final contract = Contract(
      address: params.contractAddress.hex,
      abi: _erc1155AbiJson,
      publicClient: _client,
      walletClient: _client,
    );

    return contract.write(
      'setApprovalForAll',
      [params.to.hex, true],
    );
  }

  /// Check if ERC-721 is approved
  Future<bool> _isErc721Approved(NftTransferParams params) async {
    return !(await _needsErc721Approval(params));
  }

  /// Check if ERC-1155 is approved
  Future<bool> _isErc1155Approved(NftTransferParams params) async {
    return !(await _needsErc1155Approval(params));
  }

  // ABI definitions for NFT contracts
  static const _erc721AbiJson = '''
[
    {
      "inputs": [
        {"internalType": "address", "name": "to", "type": "address"},
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"}
      ],
      "name": "approve",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"}
      ],
      "name": "getApproved",
      "outputs": [
        {"internalType": "address", "name": "", "type": "address"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "owner", "type": "address"},
        {"internalType": "address", "name": "operator", "type": "address"}
      ],
      "name": "isApprovedForAll",
      "outputs": [
        {"internalType": "bool", "name": "", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "from", "type": "address"},
        {"internalType": "address", "name": "to", "type": "address"},
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"}
      ],
      "name": "safeTransferFrom",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "operator", "type": "address"},
        {"internalType": "bool", "name": "approved", "type": "bool"}
      ],
      "name": "setApprovalForAll",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';

  static const _erc1155AbiJson = '''
[
    {
      "inputs": [
        {"internalType": "address", "name": "account", "type": "address"},
        {"internalType": "address", "name": "operator", "type": "address"}
      ],
      "name": "isApprovedForAll",
      "outputs": [
        {"internalType": "bool", "name": "", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "from", "type": "address"},
        {"internalType": "address", "name": "to", "type": "address"},
        {"internalType": "uint256", "name": "id", "type": "uint256"},
        {"internalType": "uint256", "name": "amount", "type": "uint256"},
        {"internalType": "bytes", "name": "data", "type": "bytes"}
      ],
      "name": "safeTransferFrom",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "address", "name": "operator", "type": "address"},
        {"internalType": "bool", "name": "approved", "type": "bool"}
      ],
      "name": "setApprovalForAll",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';
}
