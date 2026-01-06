/// Reown Service - WalletConnect v2 integration wrapper.
///
/// Provides a simplified interface to connect external wallets
/// via the WalletConnect v2 protocol (Reown).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web3_universal_reown/web3_universal_reown.dart';

/// Reown connection state for UI binding.
enum ReownConnectionStatus {
  disconnected,
  connecting,
  connected,
  sessionPending,
  sessionActive,
}

/// Connected wallet information.
class ConnectedWallet {
  const ConnectedWallet({
    required this.address,
    required this.chainId,
    required this.sessionTopic,
    this.walletName,
    this.walletIcon,
  });

  final String address;
  final int chainId;
  final String sessionTopic;
  final String? walletName;
  final String? walletIcon;
}

/// Reown Service for WalletConnect v2 integration.
class ReownService extends ChangeNotifier {
  ReownService._();

  static final ReownService instance = ReownService._();

  ReownClient? _client;
  StreamSubscription<ReownEvent>? _eventSubscription;

  ReownConnectionStatus _status = ReownConnectionStatus.disconnected;
  ConnectedWallet? _connectedWallet;
  String? _pairingUri;
  String? _error;

  // Public getters
  ReownConnectionStatus get status => _status;
  ConnectedWallet? get connectedWallet => _connectedWallet;
  String? get pairingUri => _pairingUri;
  String? get error => _error;
  bool get isConnected => _status == ReownConnectionStatus.sessionActive;

  /// Initializes the Reown client with project ID.
  ///
  /// You must call this before using any other methods.
  /// Get your project ID from https://cloud.walletconnect.com
  Future<void> initialize({required String projectId}) async {
    if (_client != null) return;

    try {
      _client = ReownClientFactory.createDAppClient(projectId: projectId);
      _eventSubscription = _client!.events.listen(_handleEvent);
      _updateStatus(ReownConnectionStatus.disconnected);
    } catch (e) {
      _error = 'Failed to initialize Reown: $e';
      notifyListeners();
    }
  }

  /// Creates a pairing URI for QR code display.
  ///
  /// Returns the WalletConnect URI that should be displayed as a QR code
  /// or used as a deep link.
  Future<String?> createPairing() async {
    if (_client == null) {
      _error = 'Reown not initialized. Call initialize() first.';
      notifyListeners();
      return null;
    }

    try {
      _updateStatus(ReownConnectionStatus.connecting);
      _error = null;

      final pairingUri = await _client!.createPairingUri();
      _pairingUri = pairingUri.toUri();

      _updateStatus(ReownConnectionStatus.sessionPending);
      return _pairingUri;
    } catch (e) {
      _error = 'Failed to create pairing: $e';
      _updateStatus(ReownConnectionStatus.disconnected);
      return null;
    }
  }

  /// Proposes a session with required EVM namespaces.
  ///
  /// This is called after the wallet scans the QR code and connects.
  Future<void> proposeEvmSession({
    List<int> chainIds = const [1, 137], // Ethereum + Polygon
  }) async {
    if (_client == null) return;

    try {
      // Create EVM namespace with all chains
      final namespace = NamespaceConfig(
        namespace: 'eip155',
        chains: chainIds.map((id) => 'eip155:$id').toList(),
        methods: const [
          'eth_sendTransaction',
          'eth_signTransaction',
          'eth_sign',
          'personal_sign',
          'eth_signTypedData',
          'eth_signTypedData_v4',
        ],
        events: const [
          'chainChanged',
          'accountsChanged',
        ],
      );

      await _client!.proposeSession(
        requiredNamespaces: [namespace],
        metadata: {
          'name': 'dart_web3 Example App',
          'description': 'Multi-chain wallet demo',
          'url': 'https://github.com/ImL1s/dart_web3',
          'icons': ['https://avatars.githubusercontent.com/u/37784886'],
        },
      );
    } catch (e) {
      _error = 'Failed to propose session: $e';
      notifyListeners();
    }
  }

  /// Gets a signer for the connected session.
  ///
  /// The returned signer can be used to sign transactions via the
  /// connected wallet.
  ReownSigner? getSigner() {
    if (_client == null || _connectedWallet == null) return null;

    try {
      return _client!.createSigner(_connectedWallet!.sessionTopic);
    } catch (e) {
      _error = 'Failed to create signer: $e';
      notifyListeners();
      return null;
    }
  }

  /// Disconnects the current session.
  Future<void> disconnect() async {
    if (_client == null) return;

    try {
      if (_connectedWallet != null) {
        await _client!.disconnectSession(_connectedWallet!.sessionTopic);
      }
      _connectedWallet = null;
      _pairingUri = null;
      _updateStatus(ReownConnectionStatus.disconnected);
    } catch (e) {
      _error = 'Failed to disconnect: $e';
      notifyListeners();
    }
  }

  /// Handles Reown events.
  void _handleEvent(ReownEvent event) {
    switch (event.type) {
      case ReownEventType.connectionStateChanged:
        // ConnectionState is an enum, compare directly
        if (event.connectionState == ConnectionState.connected) {
          _updateStatus(ReownConnectionStatus.connected);
        }
        break;

      case ReownEventType.sessionEstablished:
        final session = event.session;
        if (session != null) {
          // Session has single 'account' field in CAIP-10 format: eip155:1:0x...
          final accountStr = session.account;
          final parts = accountStr.split(':');
          if (parts.length >= 3) {
            _connectedWallet = ConnectedWallet(
              address: parts[2],
              chainId: int.tryParse(parts[1]) ?? 1,
              sessionTopic: session.topic,
              walletName: session.metadata['name'] as String?,
              walletIcon:
                  (session.metadata['icons'] as List?)?.first as String?,
            );
          }
          _pairingUri = null;
          _updateStatus(ReownConnectionStatus.sessionActive);
        }
        break;

      case ReownEventType.sessionDisconnected:
        _connectedWallet = null;
        _updateStatus(ReownConnectionStatus.disconnected);
        break;

      case ReownEventType.sessionProposalRejected:
        _error = event.reason ?? 'Session rejected by wallet';
        _updateStatus(ReownConnectionStatus.disconnected);
        break;

      default:
        break;
    }
  }

  void _updateStatus(ReownConnectionStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  /// Disposes resources.
  @override
  void dispose() {
    _eventSubscription?.cancel();
    _client?.dispose();
    super.dispose();
  }
}
