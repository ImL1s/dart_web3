/// Ledger Service for hardware wallet integration.
///
/// Handles discovery, connection, and signing with Ledger devices
/// using the ledger_flutter package with web3_universal_ledger.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ledger_flutter/ledger_flutter.dart' as lf;
import 'package:web3_universal_ledger/web3_universal_ledger.dart';

/// Connection status for Ledger service.
enum LedgerStatus {
  disconnected,
  scanning,
  connected,
  error,
}

/// Ledger Service singleton.
class LedgerService extends ChangeNotifier {
  LedgerService._({lf.Ledger? ledger}) 
      : _ledger = ledger ?? lf.Ledger(
          options: lf.LedgerOptions(),
        );

  @visibleForTesting
  factory LedgerService.test({required lf.Ledger ledger}) {
    return LedgerService._(ledger: ledger);
  }

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

  final lf.Ledger _ledger;

  LedgerClient? _client;
  LedgerStatus _status = LedgerStatus.disconnected;
  List<lf.LedgerDevice> _discoveredDevices = [];
  lf.LedgerDevice? _connectedDevice;
  String? _error;
  String? _connectedAddress;

  LedgerStatus get status => _status;
  List<lf.LedgerDevice> get discoveredDevices => _discoveredDevices;
  lf.LedgerDevice? get connectedDevice => _connectedDevice;
  String? get error => _error;
  LedgerClient? get client => _client;
  String? get connectedAddress => _connectedAddress;

  /// Scan for Bluetooth Low Energy (BLE) Ledger devices.
  Future<void> scanForDevices() async {
    _updateStatus(LedgerStatus.scanning);
    _discoveredDevices = [];
    _error = null;

    try {
      final stream = _ledger.scan();
      final subscription = stream.listen((device) {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices.add(device);
          notifyListeners();
        }
      });

      // Stop scanning after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();
      _updateStatus(LedgerStatus.disconnected);
    } catch (e) {
      _error = 'Scan failed: $e';
      _updateStatus(LedgerStatus.error);
    }
  }

  /// Connect to a specific Ledger device.
  Future<void> connect(lf.LedgerDevice device) async {
    try {
      if (_connectedDevice != null) {
        await disconnect();
      }

      await _ledger.connect(device);
      _connectedDevice = device;
      
      // Create LedgerClient with our Flutter transport wrapper
      final transport = _LedgerFlutterTransport(_ledger, device);
      _client = LedgerClient(transport);
      
      // Verify connection and get address
      try {
        final account = await _client!.getAccount("m/44'/60'/0'/0/0");
        _connectedAddress = account.address;
      } catch (e) {
        debugPrint('Failed to fetch Ledger address: $e');
        // Don't fail connection, but address won't be available
      }

      _updateStatus(LedgerStatus.connected);
    } catch (e) {
      _error = 'Connection failed: $e';
      _updateStatus(LedgerStatus.error);
      _connectedDevice = null;
      _connectedAddress = null;
      _client = null;
    }
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _ledger.disconnect(_connectedDevice!);
      _connectedDevice = null;
      _client = null;
      _connectedAddress = null;
    }
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
}

/// Adapts `ledger_flutter` to `LedgerTransport` interface.
class _LedgerFlutterTransport implements LedgerTransport {
  _LedgerFlutterTransport(this._ledger, this._device);

  final lf.Ledger _ledger;
  final lf.LedgerDevice _device;

  @override
  LedgerTransportType get type => LedgerTransportType.ble;

  @override
  bool get isSupported => true;

  @override
  bool get isConnected => true; // Managed by service

  @override
  Future<void> connect() async {
    // Connection managed by LedgerService
  }

  @override
  Future<void> disconnect() async {
    // Disconnection managed by LedgerService
  }

  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    try {
      final response = await _ledger.sendOperation(
        _device,
        _EthereumOperation(command),
      );

      // Parse status word from response (last 2 bytes)
      if (response.length >= 2) {
        final statusWord = (response[response.length - 2] << 8) | response[response.length - 1];
        final data = response.length > 2 
            ? Uint8List.fromList(response.sublist(0, response.length - 2))
            : Uint8List(0);
        return APDUResponse(data: data, statusWord: statusWord);
      }

      return APDUResponse(
        data: Uint8List.fromList(response),
        statusWord: 0x9000,
      );
    } catch (e) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'APDU Exchange failed: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<LedgerDevice>> discoverDevices() async {
    return [];
  }

  @override
  void dispose() {}
}

/// Custom LedgerOperation for Ethereum APDU commands.
class _EthereumOperation extends lf.LedgerOperation<Uint8List> {
  final APDUCommand _command;

  _EthereumOperation(this._command);

  @override
  Future<List<Uint8List>> write(lf.ByteDataWriter writer) async {
    writer.writeUint8(_command.cla);
    writer.writeUint8(_command.ins);
    writer.writeUint8(_command.p1);
    writer.writeUint8(_command.p2);
    final data = _command.data;
    if (data != null && data.isNotEmpty) {
      writer.writeUint8(data.length);
      writer.write(data);
    } else {
      writer.writeUint8(0);
    }
    return [];
  }

  @override
  Future<Uint8List> read(lf.ByteDataReader reader) async {
    final length = reader.remainingLength;
    if (length > 0) {
      final data = reader.read(length);
      return Uint8List.fromList(data);
    }
    return Uint8List(0);
  }
}
