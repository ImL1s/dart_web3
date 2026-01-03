import 'dart:async';



import 'namespace_config.dart';
import 'pairing_uri.dart';
import 'reown_client.dart';
import 'session_manager.dart';

/// Reown AppKit for building dApps.
/// 
/// This kit provides a high-level API for dApps to connect with wallets,
/// manage sessions, and request signatures/transactions.
class ReownAppKit {
  /// Creates a new AppKit instance.
  ReownAppKit({
    required this.projectId,
    required this.metadata,
    this.relayUrl = 'wss://relay.walletconnect.com',
  }) {
    _core = ReownClient(
      projectId: projectId,
      relayUrl: relayUrl,
    );
  }

  final String projectId;
  final Map<String, dynamic> metadata;
  final String relayUrl;
  
  late final ReownClient _core;

  /// Stream of session events (connections, disconnections, etc.).
  Stream<ReownEvent> get events => _core.events;

  /// Current session (if any).
  Session? get session => _core.sessions.isNotEmpty ? _core.sessions.first : null;

  /// Whether the AppKit is connected to the relay network.
  bool get isRelayConnected => _core.isConnected;

  /// Initializes the AppKit.
  Future<void> init() async {
    await _core.connect();
  }

  /// Connects to a wallet using the specified namespaces.
  /// 
  /// Returns a [PairingUri] that should be displayed to the user (QR Code or Deep Link).
  /// The [requiredNamespaces] define what chains and methods the dApp needs.
  Future<ConnectResponse> connect({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
  }) async {
    // 1. Ensure we are connected to the relay
    if (!_core.isConnected) {
      await _core.connect();
    }

    // 2. Generate Pairing URI
    final uri = await _core.createPairingUri();

    // 3. Propose Session (this usually happens after pairing, but here we prepare it)
    // In strict WC v2 flow, specific pairing logic might be needed.
    // For this Kit, we trigger the proposal immediately upon pairing.
    
    // We return a future that resolves when the session is approved,
    // and the URI to show.
    final sessionFuture = _core.proposeSession(
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces,
      metadata: metadata,
    );

    return ConnectResponse(
      uri: uri,
      session: sessionFuture.then((proposal) => proposal.onApprove), 
    );
  }

  /// Sends a request (e.g., eth_sendTransaction) to the connected wallet.
  Future<dynamic> request({
    required String topic,
    required String chainId,
    required String method,
    required dynamic params,
  }) async {
    final result = await _core.sendRequest(
      sessionTopic: topic,
      method: method,
      params: <String, dynamic>{
        'chainId': chainId,
        'request': {
          'method': method,
          'params': params,
        },
      },
    );
    return result;
  }

  /// Disconnects the current session.
  Future<void> disconnect() async {
    if (session != null) {
      await _core.disconnectSession(session!.topic);
    }
  }
}

/// Response returned when initiating a connection.
class ConnectResponse {
  ConnectResponse({
    required this.uri,
    required this.session,
  });

  /// The URI to display (QR Code) or link to.
  final PairingUri uri;

  /// A future that completes when the session is established.
  final Future<Session> session;
}
