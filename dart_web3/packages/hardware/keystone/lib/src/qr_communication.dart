import 'dart:async';
import 'package:web3_universal_bc_ur/web3_universal_bc_ur.dart';
import 'keystone_types.dart';

/// QR code communication manager for Keystone devices
class QRCommunication {
  QRCommunicationState _state = QRCommunicationState.idle;
  AnimatedQR? _currentRequest;
  BCURDecoder? _responseDecoder;
  final StreamController<QRCommunicationState> _stateController =
      StreamController.broadcast();
  final StreamController<String> _qrDisplayController =
      StreamController.broadcast();
  final StreamController<QRProgress> _progressController =
      StreamController.broadcast();

  /// Current communication state
  QRCommunicationState get state => _state;

  /// Stream of state changes
  Stream<QRCommunicationState> get stateStream => _stateController.stream;

  /// Stream of QR codes to display
  Stream<String> get qrDisplayStream => _qrDisplayController.stream;

  /// Stream of progress updates
  Stream<QRProgress> get progressStream => _progressController.stream;

  /// Start displaying a signing request as QR codes
  Future<void> displaySignRequest(KeystoneSignRequest request) async {
    if (_state != QRCommunicationState.idle) {
      throw KeystoneException(
        KeystoneErrorType.invalidRequest,
        'Communication already in progress',
      );
    }

    try {
      _setState(QRCommunicationState.displayingRequest);

      // Create BC-UR sign request
      final ethSignRequest = EthSignRequest(
        requestId: request.requestId,
        signData: request.data,
        dataType: request.dataType.value,
        chainId: request.chainId,
        derivationPath: request.derivationPath,
      );

      // Encode as BC-UR
      final encoded = BCUREncoder.encodeEthSignRequest(ethSignRequest);

      // Create animated QR if multi-part
      final parts = [
        encoded
      ]; // Single part for now, can be extended for large data
      _currentRequest = AnimatedQR.fromEncodedParts(parts);

      // Start displaying QR codes
      final qrStream = _currentRequest!.start();
      qrStream.listen(
        _qrDisplayController.add,
        onError: (Object error) => _handleError(
            KeystoneErrorType.qrCodeError, 'QR display error: $error'),
      );

      _setState(QRCommunicationState.waitingForResponse);
    } on Object catch (e) {
      _handleError(
          KeystoneErrorType.qrCodeError, 'Failed to display sign request: $e');
    }
  }

  /// Process a scanned QR code response
  Future<KeystoneSignResponse?> processScannedQR(String qrData) async {
    if (_state != QRCommunicationState.waitingForResponse &&
        _state != QRCommunicationState.scanningResponse) {
      throw KeystoneException(
        KeystoneErrorType.invalidRequest,
        'Not waiting for QR response',
      );
    }

    try {
      _setState(QRCommunicationState.scanningResponse);

      // Initialize decoder if needed
      _responseDecoder ??= BCURDecoder();

      // Process the QR part
      final wasUseful = _responseDecoder!.receivePart(qrData);

      if (wasUseful) {
        // Update progress
        final progress = QRProgress(
          currentPart: _responseDecoder!.solvedFragmentCount,
          totalParts: _responseDecoder!.expectedFragmentCount ?? 1,
        );
        _progressController.add(progress);
      }

      // Check if decoding is complete
      if (_responseDecoder!.isComplete) {
        final result = _responseDecoder!.getResult();
        if (result != null) {
          final signature = BCURDecoder.decodeEthSignature(qrData);
          if (signature != null) {
            _setState(QRCommunicationState.completed);
            return KeystoneSignResponse(
              requestId: signature.requestId,
              signature: signature.signature,
            );
          }
        }
      }

      return null; // Still waiting for more parts
    } on Object catch (e) {
      _handleError(
          KeystoneErrorType.qrCodeError, 'Failed to process QR response: $e');
      return null;
    }
  }

  /// Cancel current communication
  void cancel() {
    _currentRequest?.stop();
    _currentRequest = null;
    _responseDecoder?.reset();
    _responseDecoder = null;
    _setState(QRCommunicationState.idle);
  }

  /// Reset communication state
  void reset() {
    cancel();
  }

  void _setState(QRCommunicationState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  void _handleError(KeystoneErrorType type, String message) {
    _setState(QRCommunicationState.error);
    throw KeystoneException(type, message);
  }

  /// Dispose resources
  void dispose() {
    cancel();
    _stateController.close();
    _qrDisplayController.close();
    _progressController.close();
  }
}

/// QR scanner interface for platform-specific implementations
abstract class QRScanner {
  /// Start scanning for QR codes
  Future<void> startScanning();

  /// Stop scanning
  Future<void> stopScanning();

  /// Stream of scanned QR codes
  Stream<QRScanResult> get scanResults;

  /// Check if scanning is supported on this platform
  bool get isSupported;
}

/// Mock QR scanner for testing
class MockQRScanner implements QRScanner {
  final StreamController<QRScanResult> _controller =
      StreamController.broadcast();
  bool _isScanning = false;

  @override
  Stream<QRScanResult> get scanResults => _controller.stream;

  @override
  bool get isSupported => true;

  @override
  Future<void> startScanning() async {
    _isScanning = true;
  }

  @override
  Future<void> stopScanning() async {
    _isScanning = false;
  }

  /// Simulate scanning a QR code (for testing)
  void simulateScan(String qrData) {
    if (_isScanning) {
      _controller.add(
        QRScanResult(
          data: qrData,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void dispose() {
    _controller.close();
  }
}
