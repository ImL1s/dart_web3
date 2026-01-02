import 'dart:async';
import 'dart:typed_data';
import 'ledger_types.dart';

/// Abstract transport interface for Ledger communication
abstract class LedgerTransport {
  /// Transport type
  LedgerTransportType get type;
  
  /// Check if transport is supported on current platform
  bool get isSupported;
  
  /// Check if currently connected
  bool get isConnected;
  
  /// Connect to device
  Future<void> connect();
  
  /// Disconnect from device
  Future<void> disconnect();
  
  /// Send APDU command and receive response
  Future<APDUResponse> exchange(APDUCommand command);
  
  /// Discover available devices
  Future<List<LedgerDevice>> discoverDevices();
  
  /// Dispose resources
  void dispose();
}

/// USB transport implementation (mock for pure Dart)
class LedgerUSBTransport implements LedgerTransport {
  bool _isConnected = false;

  
  @override
  LedgerTransportType get type => LedgerTransportType.usb;
  
  @override
  bool get isSupported => false; // USB requires platform-specific implementation
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Future<void> connect() async {
    if (!isSupported) {
      throw LedgerException(
        LedgerErrorType.unsupportedOperation,
        'USB transport not supported in pure Dart implementation',
      );
    }
    
    // Mock connection
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _isConnected = true;
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;

  }
  
  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    if (!_isConnected) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    // Mock APDU exchange - in real implementation, this would communicate with USB device
    await Future<void>.delayed(const Duration(milliseconds: 100));
    
    // Return mock success response
    return APDUResponse(
      data: Uint8List.fromList([0x90, 0x00]), // Mock data
      statusWord: 0x9000,
    );
  }
  
  @override
  Future<List<LedgerDevice>> discoverDevices() async {
    if (!isSupported) {
      return [];
    }
    
    // Mock device discovery
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    
    return [
      LedgerDevice(
        deviceId: 'usb-ledger-1',
        name: 'Ledger Nano S Plus',
        version: '1.0.0',
        transportType: LedgerTransportType.usb,
      ),
    ];
  }
  
  @override
  void dispose() {
    disconnect();
  }
}

/// Bluetooth Low Energy transport implementation (mock for pure Dart)
class LedgerBLETransport implements LedgerTransport {
  bool _isConnected = false;

  
  @override
  LedgerTransportType get type => LedgerTransportType.ble;
  
  @override
  bool get isSupported => false; // BLE requires platform-specific implementation
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Future<void> connect() async {
    if (!isSupported) {
      throw LedgerException(
        LedgerErrorType.unsupportedOperation,
        'BLE transport not supported in pure Dart implementation',
      );
    }
    
    // Mock connection
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    _isConnected = true;
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;

  }
  
  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    if (!_isConnected) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    // Mock APDU exchange
    await Future<void>.delayed(const Duration(milliseconds: 200));
    
    return APDUResponse(
      data: Uint8List.fromList([0x90, 0x00]),
      statusWord: 0x9000,
    );
  }
  
  @override
  Future<List<LedgerDevice>> discoverDevices() async {
    if (!isSupported) {
      return [];
    }
    
    // Mock device discovery
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    
    return [
      LedgerDevice(
        deviceId: 'ble-ledger-1',
        name: 'Ledger Nano X',
        version: '2.0.0',
        transportType: LedgerTransportType.ble,
      ),
    ];
  }
  
  @override
  void dispose() {
    disconnect();
  }
}

/// Mock transport for testing
class MockLedgerTransport implements LedgerTransport {
  bool _isConnected = false;
  final Map<String, Uint8List> _mockResponses = {};
  
  @override
  LedgerTransportType get type => LedgerTransportType.usb;
  
  @override
  bool get isSupported => true;
  
  @override
  bool get isConnected => _isConnected;
  
  /// Set mock response for specific command
  void setMockResponse(APDUCommand command, Uint8List responseData, {int statusWord = 0x9000}) {
    final key = _commandKey(command);
    final response = Uint8List.fromList([...responseData, (statusWord >> 8) & 0xFF, statusWord & 0xFF]);
    _mockResponses[key] = response;
  }
  
  @override
  Future<void> connect() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _isConnected = true;
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }
  
  @override
  Future<APDUResponse> exchange(APDUCommand command) async {
    if (!_isConnected) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    await Future<void>.delayed(const Duration(milliseconds: 50));
    
    final key = _commandKey(command);
    final response = _mockResponses[key];
    
    if (response == null) {
      // Default success response
      return APDUResponse(
        data: Uint8List(0),
        statusWord: 0x9000,
      );
    }
    
    final dataLength = response.length - 2;
    final data = response.sublist(0, dataLength);
    final statusWord = (response[dataLength] << 8) | response[dataLength + 1];
    
    return APDUResponse(
      data: data,
      statusWord: statusWord,
    );
  }
  
  @override
  Future<List<LedgerDevice>> discoverDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    return [
      LedgerDevice(
        deviceId: 'mock-ledger-1',
        name: 'Mock Ledger Device',
        version: '1.0.0',
        transportType: LedgerTransportType.usb,
      ),
    ];
  }
  
  @override
  void dispose() {
    disconnect();
    _mockResponses.clear();
  }
  
  String _commandKey(APDUCommand command) {
    return '${command.cla.toRadixString(16)}-${command.ins.toRadixString(16)}-${command.p1.toRadixString(16)}-${command.p2.toRadixString(16)}';
  }
}

/// Transport factory for creating appropriate transport
class LedgerTransportFactory {
  /// Create USB transport
  static LedgerTransport createUSB() {
    return LedgerUSBTransport();
  }
  
  /// Create BLE transport
  static LedgerTransport createBLE() {
    return LedgerBLETransport();
  }
  
  /// Create mock transport for testing
  static MockLedgerTransport createMock() {
    return MockLedgerTransport();
  }
  
  /// Get available transport types for current platform
  static List<LedgerTransportType> getAvailableTransports() {
    final available = <LedgerTransportType>[];
    
    // In a real implementation, check platform capabilities
    // For now, return empty list since pure Dart doesn't support USB/BLE
    
    return available;
  }
}
