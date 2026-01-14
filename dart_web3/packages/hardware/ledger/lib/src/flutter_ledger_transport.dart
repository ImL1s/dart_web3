import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as lf;

import 'ledger_transport.dart';
import 'ledger_types.dart';

/// Wraps the native LedgerDevice
class FlutterLedgerDevice extends LedgerDevice {
  final lf.LedgerDevice internalDevice;
  
  FlutterLedgerDevice(this.internalDevice) : super(
    deviceId: internalDevice.id,
    name: internalDevice.name,
    version: 'BLE', // Default for now
    transportType: LedgerTransportType.ble,
  );
}

/// Interface for Ledger Connection to allow mocking
abstract class LedgerConnectionInterface {
  bool get isDisconnected;
  Future<void> disconnect();
  Future<T> sendOperation<T>(lf.LedgerComplexOperation<T> operation);
}

/// Adapter for real LedgerConnection
class LedgerConnectionAdapter implements LedgerConnectionInterface {
  final lf.LedgerConnection _impl;

  LedgerConnectionAdapter(this._impl);

  @override
  bool get isDisconnected => _impl.isDisconnected;

  @override
  Future<void> disconnect() => _impl.disconnect();

  @override
  Future<T> sendOperation<T>(lf.LedgerComplexOperation<T> operation) {
    return _impl.sendOperation(operation);
  }
}

/// Wrapper to allow mocking of the sealed LedgerInterface
class LedgerInterfaceWrapper {
  final lf.LedgerInterface _impl;

  LedgerInterfaceWrapper(this._impl);

  factory LedgerInterfaceWrapper.ble() {
    return LedgerInterfaceWrapper(
      lf.LedgerInterface.ble(onPermissionRequest: (_) async => true),
    );
  }

  Stream<lf.LedgerDevice> scan() => _impl.scan();
  
  // Returns interface instead of concrete type
  Future<LedgerConnectionInterface> connect(lf.LedgerDevice device) async {
    final connection = await _impl.connect(device);
    return LedgerConnectionAdapter(connection);
  }
}

/// Main entry point for Flutter-based Ledger operations
class FlutterLedger {
  static LedgerInterfaceWrapper? _interface;

  static LedgerInterfaceWrapper get _ledger => _interface ??= LedgerInterfaceWrapper.ble();

  @visibleForTesting
  static void setMockLedger(LedgerInterfaceWrapper mock) {
    _interface = mock;
  }

  /// Scan for devices
  static Stream<LedgerDevice> scan() {
    return _ledger.scan().map((d) => FlutterLedgerDevice(d));
  }

  /// Connect to a device
  static Future<LedgerTransport> connect(LedgerDevice device) async {
    if (device is! FlutterLedgerDevice) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Invalid device type. Must be FlutterLedgerDevice.',
      );
    }

    try {
      final connection = await _ledger.connect(device.internalDevice);
      // Connection is already an interface
      return FlutterLedgerTransport(connection);
    } catch (e) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Failed to connect: $e',
        originalError: e,
      );
    }
  }
  
  /// Disconnect all?
  static Future<void> cleanup() async {
    // optional
  }
}


/// Transport implementation using ledger_flutter_plus
class FlutterLedgerTransport implements LedgerTransport {
  FlutterLedgerTransport(this._connection);

  final LedgerConnectionInterface _connection;

  @override
  LedgerTransportType get type => LedgerTransportType.ble;

  @override
  bool get isSupported => true;

  @override
  bool get isConnected => !_connection.isDisconnected;

  @override
  Future<void> connect() async {
    // Managed externally via FlutterLedger.connect
  }

  @override
  Future<void> disconnect() async {
    await _connection.disconnect();
  }

  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    try {
      final response = await _connection.sendOperation<List<int>>(
        _EthereumOperation(command),
      );

      final respList = response;
      // Parse status word from response (last 2 bytes)
      if (respList.length >= 2) {
        final statusWord = (respList[respList.length - 2] << 8) |
            respList[respList.length - 1];
        final data = respList.length > 2
            ? Uint8List.fromList(respList.sublist(0, respList.length - 2))
            : Uint8List(0);
        return APDUResponse(data: data, statusWord: statusWord);
      }

      return APDUResponse(
        data: Uint8List.fromList(respList),
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
     // Helper to allow discovery via Transport interface if needed
     final devices = <LedgerDevice>[];
     final sub = FlutterLedger.scan().listen((d) => devices.add(d));
     await Future<void>.delayed(const Duration(seconds: 2));
     await sub.cancel();
     return devices;
  }

  @override
  void dispose() {
    disconnect();
  }
}

/// Custom LedgerOperation for Ethereum APDU commands.
class _EthereumOperation extends lf.LedgerComplexOperation<List<int>> {
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
  Future<List<int>> read(lf.ByteDataReader reader) async {
    return reader.read(reader.remainingLength);
  }
}
