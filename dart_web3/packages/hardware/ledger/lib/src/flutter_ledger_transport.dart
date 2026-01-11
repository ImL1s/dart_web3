
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as lf;

import 'apdu_commands.dart';
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

/// Main entry point for Flutter-based Ledger operations
class FlutterLedger {
  static lf.LedgerInterface? _interface;

  static lf.LedgerInterface get _ledger => _interface ??= lf.LedgerInterface.ble(
    onPermissionRequest: (_) async => true,
  );

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

  final lf.LedgerConnection _connection;

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
      final response = await _connection.sendOperation(
        _EthereumOperation(command),
      );

      // Parse status word from response (last 2 bytes)
      if (response.length >= 2) {
        final statusWord = (response[response.length - 2] << 8) |
            response[response.length - 1];
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
     // Helper to allow discovery via Transport interface if needed
     final completer = Completer<List<LedgerDevice>>();
     final devices = <LedgerDevice>[];
     final sub = FlutterLedger.scan().listen((d) => devices.add(d));
     await Future.delayed(const Duration(seconds: 2));
     await sub.cancel();
     completer.complete(devices);
     return completer.future;
  }

  @override
  void dispose() {
    disconnect();
  }
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
