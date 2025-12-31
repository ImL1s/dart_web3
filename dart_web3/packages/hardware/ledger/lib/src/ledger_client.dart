import 'dart:async';
import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'ledger_types.dart';
import 'ledger_transport.dart';
import 'apdu_commands.dart';

/// Ledger hardware wallet client
class LedgerClient {
  final LedgerTransport _transport;
  LedgerConnectionState _state = LedgerConnectionState.disconnected;
  LedgerDevice? _device;
  EthereumAppConfig? _appConfig;
  final StreamController<LedgerConnectionState> _stateController = StreamController.broadcast();
  
  LedgerClient(this._transport);
  
  /// Current connection state
  LedgerConnectionState get state => _state;
  
  /// Stream of connection state changes
  Stream<LedgerConnectionState> get stateStream => _stateController.stream;
  
  /// Current device
  LedgerDevice? get device => _device;
  
  /// Ethereum app configuration
  EthereumAppConfig? get appConfig => _appConfig;
  
  /// Check if connected and Ethereum app is open
  bool get isReady => _state == LedgerConnectionState.connected && _appConfig != null;
  
  /// Discover available Ledger devices
  Future<List<LedgerDevice>> discoverDevices() async {
    return await _transport.discoverDevices();
  }
  
  /// Connect to Ledger device
  Future<void> connect() async {
    if (_state == LedgerConnectionState.connected) {
      return;
    }
    
    try {
      _setState(LedgerConnectionState.connecting);
      
      await _transport.connect();
      
      // Try to get app configuration to verify Ethereum app is open
      await _loadAppConfiguration();
      
      _setState(LedgerConnectionState.connected);
      
    } catch (e) {
      _setState(LedgerConnectionState.error);
      rethrow;
    }
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } finally {
      _device = null;
      _appConfig = null;
      _setState(LedgerConnectionState.disconnected);
    }
  }
  
  /// Get public key and address for derivation path
  Future<LedgerAccount> getAccount(String derivationPath, {bool display = false}) async {
    _ensureConnected();
    
    try {
      final command = EthereumAPDU.getPublicKey(derivationPath, display: display);
      final response = await _transport.exchange(command);
      final result = EthereumResponseParser.parsePublicKey(response);
      
      return LedgerAccount(
        address: result['address'] as String,
        derivationPath: derivationPath,
        publicKey: result['publicKey'] as Uint8List,
        index: _extractAccountIndex(derivationPath),
      );
      
    } catch (e) {
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Failed to get account: $e',
        originalError: e,
      );
    }
  }
  
  /// Get multiple accounts
  Future<List<LedgerAccount>> getAccounts({
    int count = 5,
    int offset = 0,
    String basePath = "m/44'/60'/0'/0",
  }) async {
    final accounts = <LedgerAccount>[];
    
    for (int i = offset; i < offset + count; i++) {
      final path = '$basePath/$i';
      final account = await getAccount(path);
      accounts.add(account);
    }
    
    return accounts;
  }
  
  /// Sign transaction
  Future<LedgerSignResponse> signTransaction(
    Uint8List transactionData,
    String derivationPath,
  ) async {
    _ensureConnected();
    
    try {
      // For large transactions, we might need to send in chunks
      // For now, send as single command
      final command = EthereumAPDU.signTransactionFirst(derivationPath, transactionData);
      final response = await _transport.exchange(command);
      
      return EthereumResponseParser.parseSignature(response);
      
    } catch (e) {
      if (e is LedgerException) {
        rethrow;
      }
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Failed to sign transaction: $e',
        originalError: e,
      );
    }
  }
  
  /// Sign personal message
  Future<LedgerSignResponse> signPersonalMessage(
    Uint8List messageData,
    String derivationPath,
  ) async {
    _ensureConnected();
    
    try {
      final command = EthereumAPDU.signPersonalMessage(derivationPath, messageData);
      final response = await _transport.exchange(command);
      
      return EthereumResponseParser.parseSignature(response);
      
    } catch (e) {
      if (e is LedgerException) {
        rethrow;
      }
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Failed to sign message: $e',
        originalError: e,
      );
    }
  }
  
  /// Sign EIP-712 typed data
  Future<LedgerSignResponse> signTypedData(
    Uint8List domainHash,
    Uint8List messageHash,
    String derivationPath,
  ) async {
    _ensureConnected();
    
    try {
      final command = EthereumAPDU.signTypedData(derivationPath, domainHash, messageHash);
      final response = await _transport.exchange(command);
      
      return EthereumResponseParser.parseSignature(response);
      
    } catch (e) {
      if (e is LedgerException) {
        rethrow;
      }
      throw LedgerException(
        LedgerErrorType.communicationError,
        'Failed to sign typed data: $e',
        originalError: e,
      );
    }
  }
  
  /// Check if Ethereum app is open and get configuration
  Future<void> _loadAppConfiguration() async {
    try {
      // Try to get app configuration
      final configCommand = EthereumAPDU.getConfiguration();
      final configResponse = await _transport.exchange(configCommand);
      _appConfig = EthereumResponseParser.parseConfiguration(configResponse);
      
      // Get app name to verify it's the Ethereum app
      final nameCommand = EthereumAPDU.getAppName();
      final nameResponse = await _transport.exchange(nameCommand);
      final app = EthereumResponseParser.parseAppName(nameResponse);
      
      if (!app.name.toLowerCase().contains('ethereum')) {
        throw LedgerException(
          LedgerErrorType.appNotOpen,
          'Ethereum app not open. Current app: ${app.name}',
        );
      }
      
    } catch (e) {
      if (e is LedgerException) {
        rethrow;
      }
      throw LedgerException(
        LedgerErrorType.appNotOpen,
        'Failed to verify Ethereum app: $e',
        originalError: e,
      );
    }
  }
  
  void _ensureConnected() {
    if (_state != LedgerConnectionState.connected) {
      throw LedgerException(
        LedgerErrorType.connectionFailed,
        'Device not connected',
      );
    }
    
    if (_appConfig == null) {
      throw LedgerException(
        LedgerErrorType.appNotOpen,
        'Ethereum app not open',
      );
    }
  }
  
  void _setState(LedgerConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }
  
  int _extractAccountIndex(String derivationPath) {
    final parts = derivationPath.split('/');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      final cleanPart = lastPart.replaceAll("'", "").replaceAll('h', '');
      return int.tryParse(cleanPart) ?? 0;
    }
    return 0;
  }
  
  /// Dispose resources
  void dispose() {
    _transport.dispose();
    _stateController.close();
  }
  
  /// Send raw APDU command (for multi-chain support)
  Future<APDUResponse> sendCommand(APDUCommand command) async {
    return await _transport.exchange(command);
  }
}