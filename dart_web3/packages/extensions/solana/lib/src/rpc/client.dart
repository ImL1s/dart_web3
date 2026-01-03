import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_web3_provider/dart_web3_provider.dart';

import 'package:http/http.dart' as http;

import '../models/public_key.dart';
import '../models/transaction.dart';

/// Solana JSON-RPC Client.
class SolanaClient {
  SolanaClient(String url, {List<Middleware> middlewares = const [], http.Client? httpClient})
      : provider = RpcProvider(HttpTransport(url, client: httpClient), middlewares: middlewares);

  final RpcProvider provider;

  /// Gets the balance of an account in lamports.
  Future<int> getBalance(PublicKey pubKey) async {
    final response = await provider.call<Map<String, dynamic>>('getBalance', [pubKey.toBase58()]);
    return response['value'] as int;
  }

  /// Gets account info.
  Future<AccountInfo?> getAccountInfo(PublicKey pubKey) async {
    final response = await provider.call<Map<String, dynamic>?>('getAccountInfo', [
      pubKey.toBase58(),
      {'encoding': 'base64'},
    ]);
    
    if (response == null || response['value'] == null) return null;
    
    final value = response['value'] as Map<String, dynamic>;
    return AccountInfo.fromJson(value);
  }

  /// Gets a recent blockhash.
  Future<String> getRecentBlockhash() async {
    final response = await provider.call<Map<String, dynamic>>('getLatestBlockhash', [
      {'commitment': 'finalized'},
    ]);
    final value = response['value'] as Map<String, dynamic>;
    return value['blockhash'] as String;
  }
  
  /// Sends a signed transaction.
  Future<String> sendTransaction(SolanaTransaction transaction) async {
    final serialized = transaction.serialize();
    final base64Tx = base64Encode(serialized);
    
    return provider.call<String>('sendTransaction', [
      base64Tx,
      {'encoding': 'base64'},
    ]);
  }
  
  /// Request airdrop (devnet/testnet only).
  Future<String> requestAirdrop(PublicKey pubKey, int lamports) async {
    return provider.call<String>('requestAirdrop', [
      pubKey.toBase58(),
      lamports,
    ]);
  }

  void dispose() {
    provider.dispose();
  }
}

class AccountInfo {
  AccountInfo({
    required this.lamports,
    required this.owner,
    required this.data,
    required this.executable,
    required this.rentEpoch,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List;
    Uint8List data;
    if (dataList[0] is String && dataList[1] == 'base64') {
        data = base64Decode(dataList[0] as String);
    } else {
        // Handle other encodings or empty
        data = Uint8List(0);
    }

    return AccountInfo(
      lamports: json['lamports'] as int,
      owner: PublicKey.fromString(json['owner'] as String),
      data: data,
      executable: json['executable'] as bool,
      rentEpoch: json['rentEpoch'] is int ? json['rentEpoch'] as int : 0,
    );
  }

  final int lamports;
  final PublicKey owner;
  final Uint8List data;
  final bool executable;
  final int rentEpoch;
}
