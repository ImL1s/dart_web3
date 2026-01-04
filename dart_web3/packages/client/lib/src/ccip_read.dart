import 'dart:convert';
import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'public_client.dart';

/// Handler for EIP-3668 (CCIP-Read) off-chain lookups.
/// 
/// When a contract call results in an OffchainLookup error, this handler
/// fetches data from the specified URLs and executes the callback.
class CCIPReadHandler {

  CCIPReadHandler(this.client, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();
  final PublicClient client;
  final http.Client _httpClient;

  /// Selector for OffchainLookup(address,string[],bytes,bytes4,bytes)
  /// calculated as keccak256("OffchainLookup(address,string[],bytes,bytes4,bytes)")
  static final offchainLookupSelector = Uint8List.fromList([0x55, 0x6f, 0x6e, 0x30]);

  /// Handles an OffchainLookup revert.
  Future<Uint8List> handle(String sender, Uint8List errorData, [String block = 'latest']) async {
    // 1. Verify selector
    if (errorData.length < 4 || !BytesUtils.equals(errorData.sublist(0, 4), offchainLookupSelector)) {
      throw Exception('Invalid OffchainLookup selector');
    }

    // 2. Decode parameters
    // sender: address
    // urls: string[]
    // callData: bytes
    // callbackFunction: bytes4
    // extraData: bytes
    final types = [
      AbiAddress(),
      AbiArray(AbiString()),
      AbiBytes(),
      AbiFixedBytes(4),
      AbiBytes(),
    ];
    
    final decoded = AbiDecoder.decode(types, errorData.sublist(4));

    final revertSender = decoded[0] as String;
    final urls = (decoded[1] as List).cast<String>();
    final callData = decoded[2] as Uint8List;
    final callbackFunction = decoded[3] as Uint8List;
    final extraData = decoded[4] as Uint8List;

    // 3. Verify sender
    // EIP-3668: "The client MUST verify that the sender parameter matches the address of the contract that was called."
    if (revertSender.toLowerCase() != sender.toLowerCase()) {
       // While EIP-3668 says MUST, some implementations might deviate. 
       // We should follow the spec but maybe allow it if sender matches some criteria?
       // For now, let's keep it strict.
       throw Exception('CCIP-Read: Revert sender ($revertSender) does not match call target ($sender)');
    }

    // 4. Try URLs
    Exception? lastError;
    for (final url in urls) {
      try {
        final responseData = await _fetchOffchainData(url, revertSender, callData);
        if (responseData == null) continue;

        // 5. Call callback
        // selector + abi.encode(responseData, extraData)
        final callbackCallData = BytesUtils.concat([
          callbackFunction,
          AbiEncoder.encode([AbiBytes(), AbiBytes()], [responseData, extraData])
        ]);

        return await client.call(CallRequest(
          to: revertSender,
          data: callbackCallData,
        ), block);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Try next URL
        continue;
      }
    }

    throw lastError ?? Exception('Failed to resolve off-chain data from all URLs');
  }

  Future<Uint8List?> _fetchOffchainData(String url, String sender, Uint8List data) async {
    final hexData = HexUtils.encode(data, prefix: false);
    
    // Check if URL uses placeholders
    final hasSender = url.contains('{sender}');
    final hasData = url.contains('{data}');

    if (hasSender || hasData) {
      // GET request
      var finalUrl = url;
      if (hasSender) finalUrl = finalUrl.replaceAll('{sender}', sender);
      if (hasData) finalUrl = finalUrl.replaceAll('{data}', hexData);

      final response = await _httpClient.get(Uri.parse(finalUrl));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final result = body['data'] as String?;
        return result != null ? HexUtils.decode(result) : null;
      }
    } else {
      // POST request
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sender': sender, 'data': hexData}),
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final result = body['data'] as String?;
        return result != null ? HexUtils.decode(result) : null;
      }
    }
    return null;
  }
}
