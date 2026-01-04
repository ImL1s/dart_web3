import 'dart:async';
import 'dart:typed_data';
import 'trezor_types.dart';

/// Abstract transport interface for Trezor communication
abstract class TrezorTransport {
  /// Check if transport is supported on current platform
  bool get isSupported;
  
  /// Check if currently connected
  bool get isConnected;
  
  /// Connect to device
  Future<void> connect();
  
  /// Disconnect from device
  Future<void> disconnect();
  
  /// Send message and receive response
  Future<TrezorMessage> exchange(TrezorMessage message);
  
  /// Discover available devices
  Future<List<TrezorDevice>> discoverDevices();
  
  /// Dispose resources
  void dispose();
}

/// WebUSB transport implementation (mock for pure Dart)
class TrezorWebUSBTransport implements TrezorTransport {
  bool _isConnected = false;
  
  @override
  bool get isSupported => false; // WebUSB requires browser environment
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Future<void> connect() async {
    if (!isSupported) {
      throw TrezorException(
        TrezorErrorType.unsupportedOperation,
        'WebUSB transport not supported in pure Dart implementation',
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
  Future<TrezorMessage> exchange(TrezorMessage message) async {
    if (!_isConnected) {
      throw TrezorException(
        TrezorErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    // Mock message exchange
    await Future<void>.delayed(const Duration(milliseconds: 100));
    
    // Return mock response based on message type
    switch (message.type) {
      case TrezorMessageType.initialize:
        return TrezorMessage(
          type: TrezorMessageType.features,
          data: Uint8List.fromList([0x08, 0x01]), // Mock features data
        );
        
      case TrezorMessageType.getFeatures:
        return TrezorMessage(
          type: TrezorMessageType.features,
          data: Uint8List.fromList([0x08, 0x01]),
        );
        
      default:
        return TrezorMessage(
          type: TrezorMessageType.success,
          data: Uint8List(0),
        );
    }
  }
  
  @override
  Future<List<TrezorDevice>> discoverDevices() async {
    if (!isSupported) {
      return [];
    }
    
    // Mock device discovery
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    
    return [
      TrezorDevice(
        deviceId: 'webusb-trezor-1',
        model: 'Trezor Model T',
        label: 'My Trezor',
        firmwareVersion: '2.1.0',
      ),
    ];
  }
  
  @override
  void dispose() {
    disconnect();
  }
}

/// Mock transport for testing
class MockTrezorTransport implements TrezorTransport {
  bool _isConnected = false;
  final Map<TrezorMessageType, TrezorMessage> _mockResponses = {};
  final StreamController<TrezorMessage> _messageController = StreamController.broadcast();
  
  @override
  bool get isSupported => true;
  
  @override
  bool get isConnected => _isConnected;
  
  /// Stream of received messages (for testing)
  Stream<TrezorMessage> get messageStream => _messageController.stream;
  
  /// Set mock response for specific message type
  void setMockResponse(TrezorMessageType requestType, TrezorMessage response) {
    _mockResponses[requestType] = response;
  }
  
  /// Simulate user interaction (button press, PIN entry, etc.)
  void simulateUserInteraction(TrezorMessage response) {
    _messageController.add(response);
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
  Future<TrezorMessage> exchange(TrezorMessage message) async {
    if (!_isConnected) {
      throw TrezorException(
        TrezorErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    await Future<void>.delayed(const Duration(milliseconds: 50));
    
    // Check for mock response
    final mockResponse = _mockResponses[message.type];
    if (mockResponse != null) {
      return mockResponse;
    }
    
    // Default responses based on message type
    switch (message.type) {
      case TrezorMessageType.initialize:
      case TrezorMessageType.getFeatures:
        return TrezorMessage(
          type: TrezorMessageType.features,
          data: _createMockFeaturesData(),
        );
        
      case TrezorMessageType.ethereumGetAddress:
        return TrezorMessage(
          type: TrezorMessageType.ethereumAddress,
          data: _createMockAddressData(),
        );
        
      case TrezorMessageType.ethereumSignTx:
      case TrezorMessageType.ethereumSignMessage:
        // Simulate button request first
        return TrezorMessage(
          type: TrezorMessageType.buttonRequest,
          data: _createMockButtonRequestData(),
        );
        
      case TrezorMessageType.buttonAck:
        return TrezorMessage(
          type: TrezorMessageType.ethereumMessageSignature,
          data: _createMockSignatureData(),
        );
        
      default:
        return TrezorMessage(
          type: TrezorMessageType.success,
          data: Uint8List(0),
        );
    }
  }
  
  @override
  Future<List<TrezorDevice>> discoverDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    return [
      TrezorDevice(
        deviceId: 'mock-trezor-1',
        model: 'Mock Trezor Device',
        label: 'Test Trezor',
        firmwareVersion: '2.1.0',
      ),
    ];
  }
  
  @override
  void dispose() {
    disconnect();
    _mockResponses.clear();
    _messageController.close();
  }
  
  Uint8List _createMockFeaturesData() {
    // Mock protobuf-encoded Features message
    return Uint8List.fromList([
      0x0A, 0x09, 0x74, 0x72, 0x65, 0x7A, 0x6F, 0x72, 0x2E, 0x69, 0x6F, // vendor
      0x10, 0x02, // major_version
      0x18, 0x01, // minor_version
      0x20, 0x00, // patch_version
      0x28, 0x00, // bootloader_mode
      0x30, 0x01, // pin_protection
      0x38, 0x00, // passphrase_protection
      0x48, 0x01, // initialized
    ]);
  }
  
  Uint8List _createMockAddressData() {
    // Mock protobuf-encoded EthereumAddress message
    return Uint8List.fromList([
      0x0A, 0x14, // address field (20 bytes)
      0x74, 0x2d, 0x35, 0xCc, 0x66, 0x34, 0xC0, 0x53, 0x29, 0x25,
      0xa3, 0xb8, 0xD0, 0xC9, 0xe3, 0xe0, 0xC8, 0xb8, 0xc8, 0xc8,
    ]);
  }
  
  Uint8List _createMockButtonRequestData() {
    // Mock protobuf-encoded ButtonRequest message
    return Uint8List.fromList([
      0x08, 0x0E, // code (ButtonRequestType.confirmAction)
    ]);
  }
  
  Uint8List _createMockSignatureData() {
    // Mock protobuf-encoded EthereumMessageSignature message
    return Uint8List.fromList([
      0x0A, 0x14, // address field (20 bytes)
      0x74, 0x2d, 0x35, 0xCc, 0x66, 0x34, 0xC0, 0x53, 0x29, 0x25,
      0xa3, 0xb8, 0xD0, 0xC9, 0xe3, 0xe0, 0xC8, 0xb8, 0xc8, 0xc8,
      0x12, 0x41, // signature field (65 bytes)
      ...List.filled(32, 0xAA), // r
      ...List.filled(32, 0xBB), // s
      0x1B, // v
    ]);
  }
}

/// Create WebUSB transport
TrezorTransport createWebUSBTransport() {
  return TrezorWebUSBTransport();
}

/// Create mock transport for testing
MockTrezorTransport createMockTrezorTransport() {
  return MockTrezorTransport();
}

/// Get available transport types for current platform
List<String> getAvailableTrezorTransports() {
  final available = <String>[];
  
  // In a real implementation, check platform capabilities
  // For now, return empty list since pure Dart doesn't support WebUSB
  
  return available;
}
