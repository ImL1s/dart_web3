/// Mock Ledger Transport for testing without physical device.
///
/// Provides predefined responses for common Ledger APDU commands.
/// Use this for comprehensive testing - for simple mocking, use MockLedgerTransport.
library;

import 'dart:typed_data';
import 'package:web3_universal_ledger/web3_universal_ledger.dart';

/// Advanced test transport that simulates Ledger device responses with APDU commands.
class TestLedgerTransport implements LedgerTransport {
  TestLedgerTransport({
    this.mockAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD25',
    this.shouldFail = false,
    this.failureType = LedgerErrorType.communicationError,
  });

  /// Mock Ethereum address to return for getAddress calls.
  final String mockAddress;

  /// Whether to simulate failures.
  final bool shouldFail;

  /// Type of failure to simulate.
  final LedgerErrorType failureType;

  /// Custom response map for specific APDU commands.
  final Map<int, Uint8List> _customResponses = {};

  /// Recorded APDU commands for verification.
  final List<APDUCommand> recordedCommands = [];

  @override
  LedgerTransportType get type => LedgerTransportType.mock;

  @override
  bool get isSupported => true;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {
    if (shouldFail) {
      throw LedgerException(failureType, 'Mock connection failed');
    }
  }

  @override
  Future<void> disconnect() async {}

  /// Set custom response for specific INS command.
  void setCustomResponse(int ins, Uint8List response) {
    _customResponses[ins] = response;
  }

  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    recordedCommands.add(command);

    if (shouldFail) {
      throw LedgerException(failureType, 'Mock exchange failed');
    }

    // Check for custom response
    if (_customResponses.containsKey(command.ins)) {
      return APDUResponse(
        data: _customResponses[command.ins]!,
        statusWord: 0x9000,
      );
    }

    // Default responses based on INS code
    return switch (command.ins) {
      0x01 => _getConfigurationResponse(), // GET_CONFIGURATION
      0x02 => _getAddressResponse(),    // GET_ADDRESS
      0x04 => _signTransactionResponse(), // SIGN_TX
      0x08 => _signMessageResponse(),     // SIGN_MESSAGE
      0x0C => _signTypedDataResponse(),   // SIGN_TYPED_DATA
      0x06 => _getAppNameResponse(),    // GET_APP_NAME  
      _ => APDUResponse(data: Uint8List(0), statusWord: 0x9000),
    };
  }

  APDUResponse _getConfigurationResponse() {
    // Format: [arbitraryDataEnabled][erc20ProvisioningNecessary][major][minor][patch]
    return APDUResponse(
      data: Uint8List.fromList([0x01, 0x00, 1, 10, 0]), // v1.10.0, arbitrary data enabled
      statusWord: 0x9000,
    );
  }

  APDUResponse _getAddressResponse() {
    // Format expected by parser:
    // [pubkey_len][pubkey (65 bytes)][address_len][address (20 bytes as hex chars)]
    // Parser reads address and converts: 0x + hex string of bytes
    final pubKey = Uint8List(65);
    pubKey[0] = 0x04; // Uncompressed prefix
    // Fill with deterministic mock data
    for (var i = 1; i < 65; i++) {
      pubKey[i] = i;
    }

    // Address is returned as ASCII hex string (without 0x), 40 chars = 20 bytes
    final addressHex = mockAddress.substring(2); // Remove 0x
    final addressBytes = Uint8List.fromList(addressHex.codeUnits);

    final response = BytesBuilder();
    response.addByte(65); // pubkey length
    response.add(pubKey);
    response.addByte(addressBytes.length); // address length (40 chars)
    response.add(addressBytes);

    return APDUResponse(data: response.toBytes(), statusWord: 0x9000);
  }

  APDUResponse _signTransactionResponse() {
    // Return mock signature: v, r, s
    final signature = BytesBuilder();
    signature.addByte(27); // v
    signature.add(Uint8List(32)..fillRange(0, 32, 0x01)); // r
    signature.add(Uint8List(32)..fillRange(0, 32, 0x02)); // s
    return APDUResponse(data: signature.toBytes(), statusWord: 0x9000);
  }

  APDUResponse _signMessageResponse() {
    // Return mock signature
    final signature = BytesBuilder();
    signature.addByte(28); // v
    signature.add(Uint8List(32)..fillRange(0, 32, 0x03)); // r
    signature.add(Uint8List(32)..fillRange(0, 32, 0x04)); // s
    return APDUResponse(data: signature.toBytes(), statusWord: 0x9000);
  }

  APDUResponse _signTypedDataResponse() {
    // Return mock signature
    final signature = BytesBuilder();
    signature.addByte(27); // v
    signature.add(Uint8List(32)..fillRange(0, 32, 0x05)); // r
    signature.add(Uint8List(32)..fillRange(0, 32, 0x06)); // s
    return APDUResponse(data: signature.toBytes(), statusWord: 0x9000);
  }

  APDUResponse _getAppNameResponse() {
    // Format: [nameLen][name][versionLen][version]
    final name = 'Ethereum'.codeUnits;
    final version = '1.10.0'.codeUnits;
    
    final response = BytesBuilder();
    response.addByte(name.length);
    response.add(Uint8List.fromList(name));
    response.addByte(version.length);
    response.add(Uint8List.fromList(version));
    
    return APDUResponse(data: response.toBytes(), statusWord: 0x9000);
  }

  @override
  Future<List<LedgerDevice>> discoverDevices() async {
    return [
      LedgerDevice(
        deviceId: 'mock-device-001',
        name: 'Mock Ledger Nano X',
        version: '1.0.0',
        transportType: LedgerTransportType.mock,
      ),
    ];
  }

  @override
  void dispose() {}
}
