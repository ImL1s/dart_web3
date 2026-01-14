/// Ledger Service for hardware wallet integration.
///
/// Handles discovery, connection, and signing with Ledger devices
/// using the web3_universal SDK.
library;

import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:web3_universal/web3_universal.dart';

/// Connection status for Ledger service.
enum LedgerStatus {
  disconnected,
  scanning,
  connected,
  error,
}

/// Ledger Service singleton.
class LedgerService extends ChangeNotifier {
  LedgerService._();

  static LedgerService? _mockInstance;

  static LedgerService get instance => _mockInstance ?? _instance;
  static final LedgerService _instance = LedgerService._();

  @visibleForTesting
  static void setMockInstance(LedgerService mock) {
    _mockInstance = mock;
  }

  @visibleForTesting
  static void resetMockInstance() {
    _mockInstance = null;
  }

  @visibleForTesting
  Duration scanDuration = const Duration(seconds: 10);

  LedgerClient? _client;
  LedgerStatus _status = LedgerStatus.disconnected;
  List<LedgerDevice> _discoveredDevices = [];
  LedgerDevice? _connectedDevice;
  String? _error;
  String? _connectedAddress;
  
  // Keep track of transport to disconnect
  LedgerTransport? _transport;

  LedgerStatus get status => _status;
  List<LedgerDevice> get discoveredDevices => _discoveredDevices;
  LedgerDevice? get connectedDevice => _connectedDevice;
  String? get error => _error;
  LedgerClient? get client => _client;
  String? get connectedAddress => _connectedAddress;

  /// Scan for Bluetooth Low Energy (BLE) Ledger devices.
  Future<void> scanForDevices() async {
    _updateStatus(LedgerStatus.scanning);
    _discoveredDevices = [];
    _error = null;

    try {
      // Use SDK's FlutterLedger for scanning
      final stream = FlutterLedger.scan();
      final subscription = stream.listen((device) {
        if (!_discoveredDevices.any((d) => d.deviceId == device.deviceId)) {
          _discoveredDevices = [..._discoveredDevices, device];
          notifyListeners();
        }
      });

      // Stop scanning after configured duration
      await Future.delayed(scanDuration);
      await subscription.cancel();
      _updateStatus(LedgerStatus.disconnected);
    } catch (e) {
      _error = 'Scan failed: $e';
      _updateStatus(LedgerStatus.error);
    }
  }

  /// Connect to a specific Ledger device.
  Future<void> connect(LedgerDevice device) async {
    try {
      if (_connectedDevice != null) {
        await disconnect();
      }

      // connect via SDK
      final transport = await FlutterLedger.connect(device);
      _transport = transport; // Store to dispose later
      _connectedDevice = device;

      // Create LedgerClient with the SDK transport
      _client = LedgerClient(transport);

      await _client!.connect();

      // Verify connection and get address
      try {
        final account = await _client!.getAccount("m/44'/60'/0'/0/0");
        _connectedAddress = account.address;
      } catch (e) {
        debugPrint('Failed to fetch Ledger address: $e');
      }

      _updateStatus(LedgerStatus.connected);
    } catch (e) {
      _error = 'Connection failed: $e';
      _updateStatus(LedgerStatus.error);
      _connectedDevice = null;
      _connectedAddress = null;
      _client = null;
      _transport = null;
    }
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    if (_transport != null) {
      await _transport!.disconnect();
      _transport = null;
    }
    
    _connectedDevice = null;
    _client = null;
    _connectedAddress = null;
    
    _updateStatus(LedgerStatus.disconnected);
  }

  /// Sign a transaction using the connected Ledger.
  Future<Uint8List> signTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    if (_client == null) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Ledger not connected',
      );
    }

    try {
      final response = await _client!.signTransaction(
        transactionData,
        derivationPath,
      );
      return Uint8List.fromList(response.signature);
    } catch (e) {
      _error = 'Signing failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Sign a personal message using the connected Ledger.
  Future<Uint8List> signPersonalMessage(
    Uint8List message,
    String derivationPath,
  ) async {
    if (_client == null) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Ledger not connected',
      );
    }

    try {
      final response = await _client!.signPersonalMessage(
        message,
        derivationPath,
      );
      return Uint8List.fromList(response.signature);
    } catch (e) {
      _error = 'Message signing failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _updateStatus(LedgerStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    // Do not dispose the singleton instance
  }
}
