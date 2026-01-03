/// Main Reown client for WalletConnect v2 integration.
library;

import 'dart:async';

import 'connection_manager.dart';
import 'namespace_config.dart';
import 'pairing_uri.dart';
import 'relay_client.dart';
import 'reown_signer.dart';
import 'session_manager.dart';
import 'siwe_auth.dart';

/// Main client for Reown/WalletConnect v2 integration.
class ReownClient {

  ReownClient({
    required this.projectId,
    this.relayUrl = 'wss://relay.walletconnect.com',
    this.reconnectionConfig,
  }) {
    _initialize();
  }
  final String projectId;
  final String relayUrl;
  final ReconnectionConfig? reconnectionConfig;
  
  late final RelayClient _relayClient;
  late final ConnectionManager _connectionManager;
  late final SessionManager _sessionManager;
  late final SiweAuth _siweAuth;
  
  final StreamController<ReownEvent> _eventController = StreamController.broadcast();
  
  late StreamSubscription<SessionEvent> _sessionSubscription;
  late StreamSubscription<ConnectionState> _connectionSubscription;

  /// Stream of Reown events.
  Stream<ReownEvent> get events => _eventController.stream;

  /// Whether the client is connected to the relay.
  bool get isConnected => _connectionManager.isHealthy;

  /// Current connection state.
  ConnectionState get connectionState => _connectionManager.state;

  /// All active sessions.
  List<Session> get sessions => _sessionManager.sessions;

  /// Connection statistics.
  ConnectionStats get connectionStats => _connectionManager.getStats();

  /// Initializes the client components.
  void _initialize() {
    _relayClient = RelayClient(
      relayUrl: relayUrl,
      projectId: projectId,
    );
    
    _connectionManager = ConnectionManager(
      relayClient: _relayClient,
      config: reconnectionConfig,
    );
    
    _sessionManager = SessionManager(_relayClient);
    
    _siweAuth = SiweAuth(sessionManager: _sessionManager);
    
    // Subscribe to events
    _sessionSubscription = _sessionManager.events.listen(_handleSessionEvent);
    _connectionSubscription = _connectionManager.stateChanges.listen(_handleConnectionEvent);
  }

  /// Connects to the Reown relay.
  Future<void> connect() async {
    await _connectionManager.connect();
  }

  /// Disconnects from the Reown relay.
  Future<void> disconnect() async {
    await _connectionManager.disconnect();
  }

  /// Creates a pairing URI for wallet connection.
  Future<PairingUri> createPairingUri({
    Duration? expiry,
  }) async {
    if (!isConnected) {
      await connect();
    }

    return PairingUri.generate(
      relay: relayUrl,
      expiry: expiry,
    );
  }

  /// Pairs with a dApp using a URI string.
  Future<void> pair(String uri) async {
    final pairingUri = PairingUri.parse(uri);
    if (!isConnected) {
      await connect();
    }
    await _connectionManager.relayClient.subscribe(pairingUri.topic);
  }

  /// Proposes a new session.
  Future<SessionProposal> proposeSession({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConnected) {
      await connect();
    }

    return _sessionManager.proposeSession(
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces,
      metadata: metadata,
    );
  }

  /// Approves a session proposal.
  Future<Session> approveSession({
    required String proposalId,
    required String topic,
    required List<NamespaceConfig> namespaces,
    required String account,
    Map<String, dynamic>? metadata,
  }) async {
    return _sessionManager.approveSession(
      proposalId: proposalId,
      topic: topic,
      namespaces: namespaces,
      account: account,
      metadata: metadata,
    );
  }

  /// Rejects a session proposal.
  Future<void> rejectSession({
    required String proposalId,
    required String topic,
    String? reason,
  }) async {
    await _sessionManager.rejectSession(
      proposalId: proposalId,
      topic: topic,
      reason: reason,
    );
  }

  /// Disconnects a session.
  Future<void> disconnectSession(String topic, {String? reason}) async {
    await _sessionManager.disconnectSession(topic, reason: reason);
  }

  /// Updates session namespaces.
  Future<void> updateSession({
    required String topic,
    required List<NamespaceConfig> namespaces,
  }) async {
    await _sessionManager.updateSession(
      topic: topic,
      namespaces: namespaces,
    );
  }

  /// Extends session expiry.
  Future<void> extendSession(String topic, Duration extension) async {
    await _sessionManager.extendSession(topic, extension);
  }

  /// Creates a signer from a session.
  ReownSigner createSigner(String sessionTopic) {
    final session = _sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    return ReownSignerFactory.fromSession(_sessionManager, session);
  }

  /// Creates signers for all accounts in a session.
  List<ReownSigner> createSigners(String sessionTopic) {
    final session = _sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    return ReownSignerFactory.fromSessionAccounts(_sessionManager, session);
  }

  /// Initiates One-Click Auth flow.
  Future<SiweAuthResult> oneClickAuth({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    SiweConfig? siweConfig,
    Duration? timeout,
  }) async {
    if (!isConnected) {
      await connect();
    }

    final oneClickAuth = OneClickAuth(_siweAuth);
    return oneClickAuth.authenticate(
      namespaces: requiredNamespaces,
      config: siweConfig,
      timeout: timeout,
    );
  }

  /// Authenticates with SIWE for an existing session.
  Future<SiweAuthResult> authenticateWithSiwe({
    required String sessionTopic,
    SiweConfig? config,
  }) async {
    return _siweAuth.authenticateWithSiwe(
      sessionTopic: sessionTopic,
    );
  }

  /// Sends a request to a session.
  Future<Map<String, dynamic>> sendRequest({
    required String sessionTopic,
    required String method,
    required Map<String, dynamic> params,
    Duration? timeout,
  }) async {
    return _sessionManager.sendRequest(
      topic: sessionTopic,
      method: method,
      params: params,
      timeout: timeout,
    );
  }

  /// Gets a session by topic.
  Session? getSession(String topic) {
    return _sessionManager.getSession(topic);
  }

  /// Handles session events.
  void _handleSessionEvent(SessionEvent event) {
    switch (event.type) {
      case SessionEventType.proposalSent:
        _eventController.add(ReownEvent.sessionProposalSent(event.proposal!));
        break;
      case SessionEventType.proposalReceived:
        _eventController.add(ReownEvent.sessionProposalReceived(event.proposal!));
        break;
      case SessionEventType.proposalRejected:
        _eventController.add(ReownEvent.sessionProposalRejected(
          event.proposalId!,
          event.reason,
        ),);
        break;
      case SessionEventType.established:
        _eventController.add(ReownEvent.sessionEstablished(event.session!));
        break;
      case SessionEventType.updated:
        _eventController.add(ReownEvent.sessionUpdated(event.session!));
        break;
      case SessionEventType.extended:
        _eventController.add(ReownEvent.sessionExtended(event.session!));
        break;
      case SessionEventType.disconnected:
        _eventController.add(ReownEvent.sessionDisconnected(
          event.session!,
          event.reason,
        ),);
        break;
      case SessionEventType.request:
        _eventController.add(ReownEvent.sessionRequest(
          event.session!,
          event.request!,
        ),);
        break;
    }
  }

  /// Handles connection events.
  void _handleConnectionEvent(ConnectionState state) {
    _eventController.add(ReownEvent.connectionStateChanged(state));
  }

  /// Disposes the client and cleans up resources.
  void dispose() {
    _sessionSubscription.cancel();
    _connectionSubscription.cancel();
    _eventController.close();
    _sessionManager.dispose();
    _connectionManager.dispose();
    _relayClient.dispose();
  }
}

/// Reown client events.
class ReownEvent {

  ReownEvent._(this.type, {
    this.proposal,
    this.session,
    this.proposalId,
    this.reason,
    this.request,
    this.connectionState,
  });

  factory ReownEvent.sessionProposalSent(SessionProposal proposal) =>
      ReownEvent._(ReownEventType.sessionProposalSent, proposal: proposal);

  factory ReownEvent.sessionProposalReceived(SessionProposal proposal) =>
      ReownEvent._(ReownEventType.sessionProposalReceived, proposal: proposal);

  factory ReownEvent.sessionProposalRejected(String proposalId, String? reason) =>
      ReownEvent._(ReownEventType.sessionProposalRejected, proposalId: proposalId, reason: reason);

  factory ReownEvent.sessionEstablished(Session session) =>
      ReownEvent._(ReownEventType.sessionEstablished, session: session);

  factory ReownEvent.sessionUpdated(Session session) =>
      ReownEvent._(ReownEventType.sessionUpdated, session: session);

  factory ReownEvent.sessionExtended(Session session) =>
      ReownEvent._(ReownEventType.sessionExtended, session: session);

  factory ReownEvent.sessionDisconnected(Session session, String? reason) =>
      ReownEvent._(ReownEventType.sessionDisconnected, session: session, reason: reason);

  factory ReownEvent.sessionRequest(Session session, Map<String, dynamic> request) =>
      ReownEvent._(ReownEventType.sessionRequest, session: session, request: request);

  factory ReownEvent.connectionStateChanged(ConnectionState state) =>
      ReownEvent._(ReownEventType.connectionStateChanged, connectionState: state);
  final ReownEventType type;
  final SessionProposal? proposal;
  final Session? session;
  final String? proposalId;
  final String? reason;
  final Map<String, dynamic>? request;
  final ConnectionState? connectionState;
}

enum ReownEventType {
  sessionProposalSent,
  sessionProposalReceived,
  sessionProposalRejected,
  sessionEstablished,
  sessionUpdated,
  sessionExtended,
  sessionDisconnected,
  sessionRequest,
  connectionStateChanged,
}

/// Factory for creating Reown clients with common configurations.
class ReownClientFactory {
  ReownClientFactory._();

  /// Creates a client for DApp integration.
  static ReownClient createDAppClient({
    required String projectId,
    String? relayUrl,
    ReconnectionConfig? reconnectionConfig,
  }) {
    return ReownClient(
      projectId: projectId,
      relayUrl: relayUrl ?? 'wss://relay.walletconnect.com',
      reconnectionConfig: reconnectionConfig ?? ReconnectionConfig.defaultConfig(),
    );
  }

  /// Creates a client for wallet integration.
  static ReownClient createWalletClient({
    required String projectId,
    String? relayUrl,
    ReconnectionConfig? reconnectionConfig,
  }) {
    return ReownClient(
      projectId: projectId,
      relayUrl: relayUrl ?? 'wss://relay.walletconnect.com',
      reconnectionConfig: reconnectionConfig ?? ReconnectionConfig.aggressive(),
    );
  }

  /// Creates a client with custom configuration.
  static ReownClient createCustomClient({
    required String projectId,
    required String relayUrl,
    required ReconnectionConfig reconnectionConfig,
  }) {
    return ReownClient(
      projectId: projectId,
      relayUrl: relayUrl,
      reconnectionConfig: reconnectionConfig,
    );
  }
}
