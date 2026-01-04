import 'dart:async';
import 'dart:typed_data';

import 'protobuf_messages.dart';
import 'trezor_transport.dart';
import 'trezor_types.dart';

/// Trezor hardware wallet client
class TrezorClient {
  TrezorClient(this._transport);
  final TrezorTransport _transport;
  TrezorConnectionState _state = TrezorConnectionState.disconnected;
  TrezorDevice? _device;
  TrezorFeatures? _features;
  final StreamController<TrezorConnectionState> _stateController =
      StreamController.broadcast();

  /// Current connection state
  TrezorConnectionState get state => _state;

  /// Stream of connection state changes
  Stream<TrezorConnectionState> get stateStream => _stateController.stream;

  /// Current device
  TrezorDevice? get device => _device;

  /// Device features
  TrezorFeatures? get features => _features;

  /// Check if connected and ready
  bool get isReady =>
      _state == TrezorConnectionState.connected && _features != null;

  /// Discover available Trezor devices
  Future<List<TrezorDevice>> discoverDevices() async {
    return _transport.discoverDevices();
  }

  /// Connect to Trezor device
  Future<void> connect() async {
    if (_state == TrezorConnectionState.connected) {
      return;
    }

    try {
      _setState(TrezorConnectionState.connecting);

      await _transport.connect();

      // Initialize device and get features
      await _initializeDevice();

      _setState(TrezorConnectionState.connected);
    } catch (e) {
      _setState(TrezorConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } finally {
      _device = null;
      _features = null;
      _setState(TrezorConnectionState.disconnected);
    }
  }

  /// Get Ethereum address for derivation path
  Future<TrezorAccount> getAccount(String derivationPath,
      {bool showDisplay = false}) async {
    _ensureConnected();

    try {
      final requestData = encodeEthereumGetAddress(
        derivationPath: derivationPath,
        showDisplay: showDisplay,
      );

      final request = TrezorMessage(
        type: TrezorMessageType.ethereumGetAddress,
        data: requestData,
      );

      final response = await _handleUserInteraction(request);

      if (response.type != TrezorMessageType.ethereumAddress) {
        throw TrezorException(
          TrezorErrorType.protocolError,
          'Unexpected response type: ${response.type}',
        );
      }

      final result = decodeEthereumAddress(response.data);

      return TrezorAccount(
        address: result['address'] as String,
        derivationPath: derivationPath,
        publicKey: result['publicKey'] as Uint8List,
        index: _extractAccountIndex(derivationPath),
      );
    } catch (e) {
      if (e is TrezorException) {
        rethrow;
      }
      throw TrezorException(
        TrezorErrorType.communicationError,
        'Failed to get account: $e',
        originalError: e,
      );
    }
  }

  /// Get multiple accounts
  Future<List<TrezorAccount>> getAccounts({
    int count = 5,
    int offset = 0,
    String basePath = "m/44'/60'/0'/0",
  }) async {
    final accounts = <TrezorAccount>[];

    for (var i = offset; i < offset + count; i++) {
      final path = '$basePath/$i';
      final account = await getAccount(path);
      accounts.add(account);
    }

    return accounts;
  }

  /// Sign Ethereum transaction
  Future<TrezorSignResponse> signTransaction({
    required String derivationPath,
    required Uint8List nonce,
    required Uint8List gasPrice,
    required Uint8List gasLimit,
    required String to,
    required Uint8List value,
    Uint8List? data,
    int? chainId,
  }) async {
    _ensureConnected();

    try {
      final requestData = encodeEthereumSignTx(
        derivationPath: derivationPath,
        nonce: nonce,
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        to: to,
        value: value,
        data: data,
        chainId: chainId,
      );

      final request = TrezorMessage(
        type: TrezorMessageType.ethereumSignTx,
        data: requestData,
      );

      final response = await _handleUserInteraction(request);

      if (response.type != TrezorMessageType.ethereumMessageSignature) {
        throw TrezorException(
          TrezorErrorType.protocolError,
          'Unexpected response type: ${response.type}',
        );
      }

      return decodeEthereumMessageSignature(response.data);
    } catch (e) {
      if (e is TrezorException) {
        rethrow;
      }
      throw TrezorException(
        TrezorErrorType.communicationError,
        'Failed to sign transaction: $e',
        originalError: e,
      );
    }
  }

  /// Sign Ethereum message
  Future<TrezorSignResponse> signMessage({
    required String derivationPath,
    required Uint8List message,
  }) async {
    _ensureConnected();

    try {
      final requestData = encodeEthereumSignMessage(
        derivationPath: derivationPath,
        message: message,
      );

      final request = TrezorMessage(
        type: TrezorMessageType.ethereumSignMessage,
        data: requestData,
      );

      final response = await _handleUserInteraction(request);

      if (response.type != TrezorMessageType.ethereumMessageSignature) {
        throw TrezorException(
          TrezorErrorType.protocolError,
          'Unexpected response type: ${response.type}',
        );
      }

      return decodeEthereumMessageSignature(response.data);
    } catch (e) {
      if (e is TrezorException) {
        rethrow;
      }
      throw TrezorException(
        TrezorErrorType.communicationError,
        'Failed to sign message: $e',
        originalError: e,
      );
    }
  }

  /// Initialize device and get features
  Future<void> _initializeDevice() async {
    // Send Initialize message
    final initMessage = TrezorMessage(
      type: TrezorMessageType.initialize,
      data: encodeInitialize(),
    );

    final response = await _transport.exchange(initMessage);

    if (response.type != TrezorMessageType.features) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Expected Features message, got ${response.type}',
      );
    }

    _features = decodeFeatures(response.data);

    // Create device info
    _device = TrezorDevice(
      deviceId: _features!.deviceId ?? 'unknown',
      model: _getModelFromFeatures(_features!),
      label: _features!.label ?? 'Trezor',
      firmwareVersion: _features!.firmwareVersion,
      isBootloader: _features!.bootloaderMode,
      isConnected: true,
    );

    // Check if device supports Ethereum
    if (!_features!.supportsEthereum) {
      throw TrezorException(
        TrezorErrorType.unsupportedOperation,
        'Device does not support Ethereum',
      );
    }
  }

  /// Send message and handle user interaction (public method for multi-chain support)
  Future<TrezorMessage> sendMessage(TrezorMessage request) async {
    _ensureConnected();
    return _handleUserInteraction(request);
  }

  /// Handle user interaction (button presses, PIN, passphrase)
  Future<TrezorMessage> _handleUserInteraction(TrezorMessage request) async {
    var response = await _transport.exchange(request);

    // Handle various user interaction requests
    while (true) {
      switch (response.type) {
        case TrezorMessageType.buttonRequest:
          // User needs to confirm on device
          final buttonAck = TrezorMessage(
            type: TrezorMessageType.buttonAck,
            data: encodeButtonAck(),
          );
          response = await _transport.exchange(buttonAck);
          break;

        case TrezorMessageType.pinMatrixRequest:
          // PIN required - in a real app, show PIN matrix UI
          throw TrezorException(
            TrezorErrorType.pinRequired,
            'PIN required - not implemented in mock',
          );

        case TrezorMessageType.passphraseRequest:
          // Passphrase required - in a real app, show passphrase UI
          throw TrezorException(
            TrezorErrorType.passphraseRequired,
            'Passphrase required - not implemented in mock',
          );

        case TrezorMessageType.failure:
          final errorMessage = decodeFailure(response.data);
          throw TrezorException(
            TrezorErrorType.firmwareError,
            errorMessage,
          );

        default:
          // Final response
          return response;
      }
    }
  }

  void _ensureConnected() {
    if (_state != TrezorConnectionState.connected) {
      throw TrezorException(
        TrezorErrorType.connectionFailed,
        'Device not connected',
      );
    }

    if (_features == null) {
      throw TrezorException(
        TrezorErrorType.protocolError,
        'Device not initialized',
      );
    }
  }

  void _setState(TrezorConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  String _getModelFromFeatures(TrezorFeatures features) {
    // Determine model from features
    if (features.majorVersion >= 2) {
      return 'Trezor Model T';
    } else {
      return 'Trezor One';
    }
  }

  int _extractAccountIndex(String derivationPath) {
    final parts = derivationPath.split('/');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      final cleanPart = lastPart.replaceAll("'", '').replaceAll('h', '');
      return int.tryParse(cleanPart) ?? 0;
    }
    return 0;
  }

  /// Dispose resources
  void dispose() {
    _transport.dispose();
    _stateController.close();
  }
}
