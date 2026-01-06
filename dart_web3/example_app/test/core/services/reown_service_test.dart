/// Unit tests for ReownService (WalletConnect v2 integration).
///
/// Tests cover:
/// - Service state initialization
/// - Connection status enum values
/// - ConnectedWallet data class
/// - MockReownClient for integration testing
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3_universal_reown/web3_universal_reown.dart';

import 'package:web3_wallet_app/core/services/reown_service.dart';

/// Mock ReownClient for testing without real network connections.
class MockReownClient implements ReownClient {
  MockReownClient();

  final StreamController<ReownEvent> _eventController =
      StreamController<ReownEvent>.broadcast();

  bool _isConnected = false;
  final List<Session> _sessions = [];

  // Mock control methods
  void simulateSessionEstablished(Session session) {
    _sessions.add(session);
    _eventController.add(ReownEvent.sessionEstablished(session));
  }

  void simulateDisconnection(Session session, String? reason) {
    _sessions.remove(session);
    _eventController.add(ReownEvent.sessionDisconnected(session, reason));
  }

  void simulateConnectionStateChange(ConnectionState state) {
    _isConnected = state == ConnectionState.connected;
    _eventController.add(ReownEvent.connectionStateChanged(state));
  }

  @override
  String get projectId => 'test_project_id';

  @override
  String get relayUrl => 'wss://relay.walletconnect.com';

  @override
  ReconnectionConfig? get reconnectionConfig => null;

  @override
  Stream<ReownEvent> get events => _eventController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  ConnectionState get connectionState =>
      _isConnected ? ConnectionState.connected : ConnectionState.disconnected;

  @override
  List<Session> get sessions => List.unmodifiable(_sessions);

  @override
  ConnectionStats get connectionStats => ConnectionStats(
        currentState: connectionState,
        reconnectAttempts: 0,
        lastSuccessfulConnection: null,
        lastConnectionAttempt: null,
        timeSinceLastConnection: null,
        isHealthy: _isConnected,
      );

  @override
  Future<void> connect() async {
    _isConnected = true;
    _eventController
        .add(ReownEvent.connectionStateChanged(ConnectionState.connected));
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _eventController
        .add(ReownEvent.connectionStateChanged(ConnectionState.disconnected));
  }

  @override
  Future<PairingUri> createPairingUri({Duration? expiry}) async {
    return PairingUri.generate(relay: relayUrl, expiry: expiry);
  }

  @override
  Future<void> pair(String uri) async {}

  @override
  Future<SessionProposal> proposeSession({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    Map<String, dynamic>? metadata,
  }) async {
    final completer = Completer<Session>();
    return SessionProposal(
      id: 'mock_proposal_id',
      topic: 'mock_topic',
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces ?? [],
      metadata: metadata ?? {},
      expiry: const Duration(minutes: 5),
      createdAt: DateTime.now(),
      onApprove: completer.future,
    );
  }

  @override
  Future<Session> approveSession({
    required String proposalId,
    required String topic,
    required List<NamespaceConfig> namespaces,
    required String account,
    Map<String, dynamic>? metadata,
  }) async {
    final session = Session(
      topic: 'session_$topic',
      pairingTopic: topic,
      account: account,
      namespaces: namespaces,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
      expiry: DateTime.now().add(const Duration(days: 7)),
    );
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> rejectSession({
    required String proposalId,
    required String topic,
    String? reason,
  }) async {
    _eventController
        .add(ReownEvent.sessionProposalRejected(proposalId, reason));
  }

  @override
  Future<void> disconnectSession(String topic, {String? reason}) async {
    _sessions.removeWhere((s) => s.topic == topic);
  }

  @override
  Future<void> updateSession({
    required String topic,
    required List<NamespaceConfig> namespaces,
  }) async {}

  @override
  Future<void> extendSession(String topic, Duration extension) async {}

  @override
  ReownSigner createSigner(String sessionTopic) {
    throw UnimplementedError('Mock signer not implemented');
  }

  @override
  List<ReownSigner> createSigners(String sessionTopic) {
    throw UnimplementedError('Mock signers not implemented');
  }

  @override
  Future<SiweAuthResult> oneClickAuth({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    SiweConfig? siweConfig,
    Duration? timeout,
  }) async {
    throw UnimplementedError('Mock oneClickAuth not implemented');
  }

  @override
  Future<SiweAuthResult> authenticateWithSiwe({
    required String sessionTopic,
    SiweConfig? config,
  }) async {
    throw UnimplementedError('Mock authenticateWithSiwe not implemented');
  }

  @override
  Future<Map<String, dynamic>> sendRequest({
    required String sessionTopic,
    required String method,
    required Map<String, dynamic> params,
    Duration? timeout,
  }) async {
    return {'result': 'mock_result'};
  }

  @override
  Session? getSession(String topic) {
    for (final session in _sessions) {
      if (session.topic == topic) return session;
    }
    return null;
  }

  @override
  void dispose() {
    _eventController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall methodCall) async {
      return null;
    },
  );

  group('ReownService', () {
    late ReownService service;

    setUp(() {
      service = ReownService.instance;
    });

    test('initial status is disconnected', () {
      expect(service.status, ReownConnectionStatus.disconnected);
    });

    test('isConnected returns false when not in sessionActive state', () {
      expect(service.isConnected, isFalse);
    });

    test('connectedWallet is null initially', () {
      expect(service.connectedWallet, isNull);
    });

    test('pairingUri is null initially', () {
      expect(service.pairingUri, isNull);
    });

    test('error is null initially', () {
      expect(service.error, isNull);
    });
  });

  group('ReownConnectionStatus', () {
    test('has all expected values', () {
      expect(
          ReownConnectionStatus.values,
          containsAll([
            ReownConnectionStatus.disconnected,
            ReownConnectionStatus.connecting,
            ReownConnectionStatus.connected,
            ReownConnectionStatus.sessionPending,
            ReownConnectionStatus.sessionActive,
          ]));
    });

    test('enum count is 5', () {
      expect(ReownConnectionStatus.values.length, 5);
    });
  });

  group('ConnectedWallet', () {
    test('creates with required parameters', () {
      const wallet = ConnectedWallet(
        address: '0x1234567890abcdef1234567890abcdef12345678',
        chainId: 1,
        sessionTopic: 'test_topic',
      );

      expect(wallet.address, '0x1234567890abcdef1234567890abcdef12345678');
      expect(wallet.chainId, 1);
      expect(wallet.sessionTopic, 'test_topic');
      expect(wallet.walletName, isNull);
      expect(wallet.walletIcon, isNull);
    });

    test('creates with optional parameters', () {
      const wallet = ConnectedWallet(
        address: '0xabcd',
        chainId: 137,
        sessionTopic: 'polygon_topic',
        walletName: 'MetaMask',
        walletIcon: 'https://example.com/icon.png',
      );

      expect(wallet.walletName, 'MetaMask');
      expect(wallet.walletIcon, 'https://example.com/icon.png');
    });

    test('chainId can be any EVM chain', () {
      const polygonWallet = ConnectedWallet(
        address: '0x123',
        chainId: 137,
        sessionTopic: 'topic',
      );
      expect(polygonWallet.chainId, 137);

      const arbitrumWallet = ConnectedWallet(
        address: '0x456',
        chainId: 42161,
        sessionTopic: 'topic2',
      );
      expect(arbitrumWallet.chainId, 42161);
    });
  });

  group('MockReownClient', () {
    late MockReownClient mockClient;

    setUp(() {
      mockClient = MockReownClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    test('initial state is disconnected', () {
      expect(mockClient.isConnected, isFalse);
      expect(mockClient.connectionState, ConnectionState.disconnected);
    });

    test('connect changes state to connected', () async {
      await mockClient.connect();
      expect(mockClient.isConnected, isTrue);
      expect(mockClient.connectionState, ConnectionState.connected);
    });

    test('disconnect changes state to disconnected', () async {
      await mockClient.connect();
      await mockClient.disconnect();
      expect(mockClient.isConnected, isFalse);
    });

    test('createPairingUri returns valid URI', () async {
      final uri = await mockClient.createPairingUri();
      expect(uri.toUri(), isNotEmpty);
    });

    test('proposeSession returns SessionProposal', () async {
      final proposal = await mockClient.proposeSession(
        requiredNamespaces: [
          NamespaceConfig(
            namespace: 'eip155',
            chains: ['eip155:1'],
            methods: ['eth_sendTransaction'],
            events: ['chainChanged'],
          ),
        ],
      );

      expect(proposal.id, 'mock_proposal_id');
      expect(proposal.requiredNamespaces, isNotEmpty);
    });

    test('approveSession returns Session', () async {
      final session = await mockClient.approveSession(
        proposalId: 'prop_1',
        topic: 'topic_1',
        namespaces: [],
        account: 'eip155:1:0x1234',
      );

      expect(session.topic, 'session_topic_1');
      expect(session.account, 'eip155:1:0x1234');
    });

    test('sessions list is updated after approve', () async {
      expect(mockClient.sessions, isEmpty);

      await mockClient.approveSession(
        proposalId: 'prop_1',
        topic: 'topic_1',
        namespaces: [],
        account: 'eip155:1:0x1234',
      );

      expect(mockClient.sessions, hasLength(1));
    });

    test('getSession returns null for unknown topic', () {
      expect(mockClient.getSession('unknown'), isNull);
    });

    test('getSession returns session for known topic', () async {
      await mockClient.approveSession(
        proposalId: 'prop_1',
        topic: 'topic_1',
        namespaces: [],
        account: 'eip155:1:0x1234',
      );

      final session = mockClient.getSession('session_topic_1');
      expect(session, isNotNull);
      expect(session!.account, 'eip155:1:0x1234');
    });

    test('simulateSessionEstablished emits event', () async {
      final session = Session(
        topic: 'test_session',
        pairingTopic: 'test_pairing',
        account: 'eip155:1:0xtest',
        namespaces: [],
        metadata: {},
        createdAt: DateTime.now(),
        expiry: DateTime.now().add(const Duration(days: 7)),
      );

      expectLater(
        mockClient.events,
        emits(predicate<ReownEvent>(
          (e) => e.type == ReownEventType.sessionEstablished,
        )),
      );

      mockClient.simulateSessionEstablished(session);
    });

    test('simulateConnectionStateChange emits event', () async {
      expectLater(
        mockClient.events,
        emits(predicate<ReownEvent>(
          (e) => e.type == ReownEventType.connectionStateChanged,
        )),
      );

      mockClient.simulateConnectionStateChange(ConnectionState.connected);
    });
  });
}
