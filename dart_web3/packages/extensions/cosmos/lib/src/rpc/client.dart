import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

class CosmosClient {
  CosmosClient(this.baseUrl, {http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  /// Gets the balance of an account.
  Future<List<Coin>> getBalances(String address) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/cosmos/bank/v1beta1/balances/$address'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get balances: ${response.body}');
    }

    final data = json.decode(response.body);
    final balances = data['balances'] as List;
    return balances.map((b) => Coin(
        denom: b['denom'] as String,
        amount: b['amount'] as String,
    )).toList();
  }

  /// Gets account details (account number, sequence).
  Future<CosmosAccount> getAccount(String address) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/cosmos/auth/v1beta1/accounts/$address'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get account: ${response.body}');
    }

    final data = json.decode(response.body);
    final account = data['account'];
    
    // Cosmos supports different account types, usually BaseAccount
    if (account['@type'] != '/cosmos.auth.v1beta1.BaseAccount') {
         // handle other types if needed, for now assume base
    }

    return CosmosAccount(
      address: account['address'] as String,
      accountNumber: int.parse(account['account_number'].toString()),
      sequence: int.parse(account['sequence'].toString()),
    );
  }

  /// Broadcasts a signed transaction.
  Future<String> broadcastTx(CosmosTx tx) async {
    // Cosmos REST API expects tx_bytes as base64 in a wrapper
    final txBytes = tx.serialize();
    final body = {
        'tx_bytes': base64.encode(txBytes),
        'mode': 'BROADCAST_MODE_SYNC',
    };

    final response = await _httpClient.post(
      Uri.parse('$baseUrl/cosmos/tx/v1beta1/txs'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to broadcast tx: ${response.body}');
    }

    final data = json.decode(response.body);
    return data['tx_response']['txhash'] as String;
  }
}

class CosmosAccount {
    CosmosAccount({
        required this.address,
        required this.accountNumber,
        required this.sequence,
    });
    final String address;
    final int accountNumber;
    final int sequence;
}
