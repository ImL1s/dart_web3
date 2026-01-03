import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';

import 'keystone_types.dart';
import 'qr_communication.dart';

/// Keystone hardware wallet client
class KeystoneClient {
  
  KeystoneClient({QRScanner? qrScanner}) : _qrScanner = qrScanner;
  final QRCommunication _qrComm = QRCommunication();
  final QRScanner? _qrScanner;
  KeystoneDevice? _device;
  final List<KeystoneAccount> _accounts = [];
  final Random _random = Random.secure();
  
  /// Current device information
  KeystoneDevice? get device => _device;
  
  /// Available accounts
  List<KeystoneAccount> get accounts => List.unmodifiable(_accounts);
  
  /// QR communication state
  QRCommunicationState get communicationState => _qrComm.state;
  
  /// Stream of QR codes to display
  Stream<String> get qrDisplayStream => _qrComm.qrDisplayStream;
  
  /// Stream of communication state changes
  Stream<QRCommunicationState> get stateStream => _qrComm.stateStream;
  
  /// Stream of progress updates
  Stream<QRProgress> get progressStream => _qrComm.progressStream;
  
  /// Connect to Keystone device (mock implementation)
  Future<void> connect() async {
    if (_device != null) {
      throw KeystoneException(
        KeystoneErrorType.invalidRequest,
        'Already connected to device',
      );
    }
    
    // Mock signing with different curves
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    
    _device = KeystoneDevice(
      deviceId: 'keystone-${_random.nextInt(10000)}',
      name: 'Keystone Pro',
      version: '1.0.0',
      supportedCurves: ['secp256k1', 'ed25519'],
    );
    
    // Load mock accounts
    await _loadAccounts();
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    _qrComm.cancel();
    _device = null;
    _accounts.clear();
  }
  
  /// Check if connected to device
  bool get isConnected => _device != null;
  
  /// Get accounts from device
  Future<List<KeystoneAccount>> getAccounts({
    int count = 5,
    int offset = 0,
    String derivationPath = "m/44'/60'/0'/0",
  }) async {
    if (!isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    final accounts = <KeystoneAccount>[];
    
    for (var i = offset; i < offset + count; i++) {
      final path = '$derivationPath/$i';
      
      // Generate mock account data
      final address = _generateMockAddress(i);
      final publicKey = _generateMockPublicKey(i);
      
      accounts.add(KeystoneAccount(
        address: address,
        derivationPath: path,
        publicKey: publicKey,
        name: 'Account ${i + 1}',
      ),);
    }
    
    return accounts;
  }
  
  /// Sign transaction with Keystone device
  Future<String> signTransaction(
    Uint8List transactionData,
    String derivationPath, {
    int? chainId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    final requestId = _generateRequestId();
    
    final request = KeystoneSignRequest(
      requestId: requestId,
      data: transactionData,
      dataType: KeystoneDataType.transaction,
      derivationPath: derivationPath,
      chainId: chainId,
    );
    
    return _performSigning(request, timeout);
  }
  
  /// Sign typed data with Keystone device
  Future<String> signTypedData(
    Uint8List typedDataHash,
    String derivationPath, {
    int? chainId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    final requestId = _generateRequestId();
    
    final request = KeystoneSignRequest(
      requestId: requestId,
      data: typedDataHash,
      dataType: KeystoneDataType.typedData,
      derivationPath: derivationPath,
      chainId: chainId,
    );
    
    return _performSigning(request, timeout);
  }
  
  /// Sign personal message with Keystone device
  Future<String> signPersonalMessage(
    Uint8List messageHash,
    String derivationPath, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!isConnected) {
      throw KeystoneException(
        KeystoneErrorType.deviceNotFound,
        'Device not connected',
      );
    }
    
    final requestId = _generateRequestId();
    
    final request = KeystoneSignRequest(
      requestId: requestId,
      data: messageHash,
      dataType: KeystoneDataType.personalMessage,
      derivationPath: derivationPath,
    );
    
    return _performSigning(request, timeout);
  }
  
  /// Perform the signing process with QR communication
  Future<String> _performSigning(KeystoneSignRequest request, Duration timeout) async {
    final completer = Completer<String>();
    Timer? timeoutTimer;
    StreamSubscription<dynamic>? scanSubscription;
    
    try {
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(KeystoneException(
            KeystoneErrorType.communicationTimeout,
            'Signing request timed out',
          ),);
        }
      });
      
      // Display signing request as QR codes
      await _qrComm.displaySignRequest(request);
      
      // Set up QR scanner if available
      if (_qrScanner != null) {
        await _qrScanner!.startScanning();
        
        scanSubscription = _qrScanner!.scanResults.listen((scanResult) async {
          try {
            final response = await _qrComm.processScannedQR(scanResult.data);
            if (response != null && response.isSuccess) {
              if (!completer.isCompleted) {
                completer.complete(HexUtils.encode(response.signature));
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        });
      }
      
      return await completer.future;
      
    } finally {
      timeoutTimer?.cancel();
      scanSubscription?.cancel();
      if (_qrScanner != null) {
        await _qrScanner!.stopScanning();
      }
      _qrComm.reset();
    }
  }
  
  /// Manually process a scanned QR response (when no automatic scanner is available)
  Future<String?> processQRResponse(String qrData) async {
    try {
      final response = await _qrComm.processScannedQR(qrData);
      if (response != null && response.isSuccess) {
        return HexUtils.encode(response.signature);
      }
      return null;
    } catch (e) {
      throw KeystoneException(
        KeystoneErrorType.qrCodeError,
        'Failed to process QR response: $e',
      );
    }
  }
  
  Future<void> _loadAccounts() async {
    _accounts.clear();
    
    // Load some default accounts
    final defaultAccounts = await getAccounts(count: 3);
    _accounts.addAll(defaultAccounts);
  }
  
  Uint8List _generateRequestId() {
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
  
  String _generateMockAddress(int index) {
    // Generate deterministic mock address for testing
    final bytes = Uint8List(20);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (index * 17 + i * 23) % 256;
    }
    return '0x${HexUtils.encode(bytes, prefix: false)}';
  }
  
  Uint8List _generateMockPublicKey(int index) {
    // Generate deterministic mock public key for testing
    final bytes = Uint8List(64);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (index * 31 + i * 37) % 256;
    }
    return bytes;
  }
  
  /// Dispose resources
  void dispose() {
    _qrComm.dispose();
  }
}
