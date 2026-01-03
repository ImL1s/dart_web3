/// Session management for Reown/WalletConnect v2 protocol.
library;

import 'dart:async';
import 'dart:math';

import 'namespace_config.dart';
import 'relay_client.dart';

/// Manages WalletConnect v2 sessions.
class SessionManager {

  SessionManager(this.relayClient) {
    _relaySubscription = relayClient.events.listen(_handleRelayEvent);
  }
  final RelayClient relayClient;
  final Map<String, Session> _sessions = {};
  final StreamController<SessionEvent> _eventController = StreamController.broadcast();
  
  late StreamSubscription<RelayEvent> _relaySubscription;

  /// Stream of session events.
  Stream<SessionEvent> get events => _eventController.stream;

  /// All active sessions.
  List<Session> get sessions => _sessions.values.toList();

  /// Gets a session by topic.
  Session? getSession(String topic) => _sessions[topic];

  final Map<String, Completer<Session>> _pendingProposals = {};

  /// Proposes a new session.
  Future<SessionProposal> proposeSession({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    Map<String, dynamic>? metadata,
    Duration? expiry,
  }) async {
    final proposalId = _generateId();
    final pairingTopic = _generateTopic();
    
    // Subscribe to pairing topic
    await relayClient.subscribe(pairingTopic);
    
    final completer = Completer<Session>();
    _pendingProposals[pairingTopic] = completer;

    final proposal = SessionProposal(
      id: proposalId,
      topic: pairingTopic,
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces ?? [],
      metadata: metadata ?? _defaultMetadata(),
      expiry: expiry ?? const Duration(minutes: 5),
      createdAt: DateTime.now(),
      onApprove: completer.future,
    );

    // Send session proposal
    await relayClient.publish(
      topic: pairingTopic,
      message: {
        'id': proposalId,
        'jsonrpc': '2.0',
        'method': 'wc_sessionPropose',
        'params': proposal.toJson(),
      },
      ttl: 300, // 5 minutes
    );

    _eventController.add(SessionEvent.proposalSent(proposal));
    return proposal;
  }

  /// Approves a session proposal.
  Future<Session> approveSession({
    required String proposalId,
    required String topic,
    required List<NamespaceConfig> namespaces,
    required String account,
    Map<String, dynamic>? metadata,
  }) async {
    final sessionTopic = _generateTopic();
    final session = Session(
      topic: sessionTopic,
      pairingTopic: topic,
      account: account,
      namespaces: namespaces,
      metadata: metadata ?? _defaultMetadata(),
      createdAt: DateTime.now(),
      expiry: DateTime.now().add(const Duration(days: 7)),
    );

    // Subscribe to session topic
    await relayClient.subscribe(sessionTopic);
    
    // Send session approval
    await relayClient.publish(
      topic: topic,
      message: {
        'id': proposalId,
        'jsonrpc': '2.0',
        'result': {
          'relay': {'protocol': 'irn'},
          'responderPublicKey': _generatePublicKey(),
          'sessionTopic': sessionTopic,
          'state': {
            'accounts': [account],
            'chains': namespaces.expand((ns) => ns.chains).toList(),
          },
        },
      },
    );

    _sessions[sessionTopic] = session;
    _eventController.add(SessionEvent.established(session));
    
    return session;
  }

  /// Rejects a session proposal.
  Future<void> rejectSession({
    required String proposalId,
    required String topic,
    String? reason,
  }) async {
    await relayClient.publish(
      topic: topic,
      message: {
        'id': proposalId,
        'jsonrpc': '2.0',
        'error': {
          'code': 5000,
          'message': reason ?? 'User rejected session',
        },
      },
    );

    _eventController.add(SessionEvent.proposalRejected(proposalId, reason));
  }

  /// Disconnects a session.
  Future<void> disconnectSession(String topic, {String? reason}) async {
    final session = _sessions[topic];
    if (session == null) return;

    await relayClient.publish(
      topic: topic,
      message: {
        'id': _generateId(),
        'jsonrpc': '2.0',
        'method': 'wc_sessionDelete',
        'params': {
          'code': 6000,
          'message': reason ?? 'User disconnected session',
        },
      },
    );

    await relayClient.unsubscribe(topic);
    _sessions.remove(topic);
    
    _eventController.add(SessionEvent.disconnected(session, reason));
  }

  /// Updates session namespaces.
  Future<void> updateSession({
    required String topic,
    required List<NamespaceConfig> namespaces,
  }) async {
    final session = _sessions[topic];
    if (session == null) {
      throw Exception('Session not found: $topic');
    }

    await relayClient.publish(
      topic: topic,
      message: {
        'id': _generateId(),
        'jsonrpc': '2.0',
        'method': 'wc_sessionUpdate',
        'params': {
          'namespaces': {
            for (final ns in namespaces)
              ns.namespace: ns.toJson(),
          },
        },
      },
    );

    // Update local session
    final updatedSession = session.copyWith(namespaces: namespaces);
    _sessions[topic] = updatedSession;
    
    _eventController.add(SessionEvent.updated(updatedSession));
  }

  /// Extends session expiry.
  Future<void> extendSession(String topic, Duration extension) async {
    final session = _sessions[topic];
    if (session == null) {
      throw Exception('Session not found: $topic');
    }

    final newExpiry = DateTime.now().add(extension);
    
    await relayClient.publish(
      topic: topic,
      message: {
        'id': _generateId(),
        'jsonrpc': '2.0',
        'method': 'wc_sessionExtend',
        'params': {
          'expiry': newExpiry.millisecondsSinceEpoch ~/ 1000,
        },
      },
    );

    // Update local session
    final updatedSession = session.copyWith(expiry: newExpiry);
    _sessions[topic] = updatedSession;
    
    _eventController.add(SessionEvent.extended(updatedSession));
  }

  /// Sends a request to a session.
  Future<Map<String, dynamic>> sendRequest({
    required String topic,
    required String method,
    required Map<String, dynamic> params,
    Duration? timeout,
  }) async {
    final session = _sessions[topic];
    if (session == null) {
      throw Exception('Session not found: $topic');
    }

    final requestId = _generateId();
    final completer = Completer<Map<String, dynamic>>();
    
    // Store pending request
    _pendingRequests[requestId] = completer;

    await relayClient.publish(
      topic: topic,
      message: {
        'id': requestId,
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      },
    );

    // Set timeout
    Timer(timeout ?? const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        _pendingRequests.remove(requestId);
        completer.completeError(TimeoutException('Request timeout'));
      }
    });

    return completer.future;
  }

  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Handles relay events.
  void _handleRelayEvent(RelayEvent event) {
    switch (event.type) {
      case RelayEventType.message:
        _handleMessage(event.topic!, event.message!);
        break;
      case RelayEventType.disconnected:
        _handleDisconnect();
        break;
      default:
        break;
    }
  }

  /// Handles incoming messages.
  void _handleMessage(String topic, Map<String, dynamic> message) {
    final method = message['method'] as String?;
    final id = message['id'];

    if (method != null) {
      // Handle method calls
      switch (method) {
        case 'wc_sessionPropose':
          _handleSessionProposal(topic, message);
          break;
        case 'wc_sessionSettle':
          _handleSessionSettle(topic, message);
          break;
        case 'wc_sessionUpdate':
          _handleSessionUpdate(topic, message);
          break;
        case 'wc_sessionExtend':
          _handleSessionExtend(topic, message);
          break;
        case 'wc_sessionDelete':
          _handleSessionDelete(topic, message);
          break;
        default:
          // Forward to session for handling
          final session = _sessions[topic];
          if (session != null) {
            _eventController.add(SessionEvent.request(session, message));
          }
          break;
      }
    } else if (id != null) {
      // Handle responses
      final completer = _pendingRequests.remove(id.toString());
      if (completer != null && !completer.isCompleted) {
        if (message.containsKey('error')) {
          completer.completeError(Exception((message['error'] as Map<String, dynamic>)['message']));
        } else {
          completer.complete(message['result'] ?? message);
        }
      }
    }
  }

  void _handleSessionProposal(String topic, Map<String, dynamic> message) {
    final params = message['params'] as Map<String, dynamic>;
    final proposal = SessionProposal.fromJson(params, topic);
    _eventController.add(SessionEvent.proposalReceived(proposal));
  }

  void _handleSessionSettle(String topic, Map<String, dynamic> message) {
    final params = message['params'] as Map<String, dynamic>;
    final session = Session.fromSettleParams(topic, params);
    _sessions[topic] = session;
    
    // Resolve pending proposal if matches pairing topic
    final completer = _pendingProposals.remove(session.pairingTopic);
    if (completer != null && !completer.isCompleted) {
      completer.complete(session);
    }

    _eventController.add(SessionEvent.established(session));
  }

  void _handleSessionUpdate(String topic, Map<String, dynamic> message) {
    final session = _sessions[topic];
    if (session != null) {
      final params = message['params'] as Map<String, dynamic>;
      final namespaces = (params['namespaces'] as Map<String, dynamic>)
          .entries
          .map((e) => NamespaceConfig.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList();
      
      final updatedSession = session.copyWith(namespaces: namespaces);
      _sessions[topic] = updatedSession;
      _eventController.add(SessionEvent.updated(updatedSession));
    }
  }

  void _handleSessionExtend(String topic, Map<String, dynamic> message) {
    final session = _sessions[topic];
    if (session != null) {
      final params = message['params'] as Map<String, dynamic>;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (params['expiry'] as int) * 1000,
      );
      
      final updatedSession = session.copyWith(expiry: expiry);
      _sessions[topic] = updatedSession;
      _eventController.add(SessionEvent.extended(updatedSession));
    }
  }

  void _handleSessionDelete(String topic, Map<String, dynamic> message) {
    final session = _sessions.remove(topic);
    if (session != null) {
      final params = message['params'] as Map<String, dynamic>;
      final reason = params['message'] as String?;
      _eventController.add(SessionEvent.disconnected(session, reason));
    }
  }

  void _handleDisconnect() {
    // Mark all sessions as disconnected
    for (final session in _sessions.values) {
      _eventController.add(SessionEvent.disconnected(session, 'Relay disconnected'));
    }
    _sessions.clear();
  }

  String _generateId() {
    final random = Random.secure();
    return random.nextInt(1000000000).toString();
  }

  String _generateTopic() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _generatePublicKey() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, dynamic> _defaultMetadata() {
    return {
      'name': 'Dart Web3 SDK',
      'description': 'Dart Web3 SDK with Reown integration',
      'url': 'https://github.com/example/web3_universal',
      'icons': ['https://example.com/icon.png'],
    };
  }

  /// Disposes the session manager.
  void dispose() {
    _relaySubscription.cancel();
    _eventController.close();
    
    // Complete all pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Session manager disposed'));
      }
    }
    _pendingRequests.clear();
  }
}

/// Represents a WalletConnect session.
class Session {

  Session({
    required this.topic,
    required this.pairingTopic,
    required this.account,
    required this.namespaces,
    required this.metadata,
    required this.createdAt,
    required this.expiry,
  });

  factory Session.fromSettleParams(String topic, Map<String, dynamic> params) {
    final state = params['state'] as Map<String, dynamic>;
    final accounts = (state['accounts'] as List).cast<String>();
    final namespaces = (params['namespaces'] as Map<String, dynamic>)
        .entries
        .map((e) => NamespaceConfig.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();

    return Session(
      topic: topic,
      pairingTopic: params['pairingTopic'] as String? ?? '',
      account: accounts.first,
      namespaces: namespaces,
      metadata: params['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.now(),
      expiry: DateTime.fromMillisecondsSinceEpoch(
        (params['expiry'] as int) * 1000,
      ),
    );
  }
  final String topic;
  final String pairingTopic;
  final String account;
  final List<NamespaceConfig> namespaces;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime expiry;

  Session copyWith({
    String? topic,
    String? pairingTopic,
    String? account,
    List<NamespaceConfig>? namespaces,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? expiry,
  }) {
    return Session(
      topic: topic ?? this.topic,
      pairingTopic: pairingTopic ?? this.pairingTopic,
      account: account ?? this.account,
      namespaces: namespaces ?? this.namespaces,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      expiry: expiry ?? this.expiry,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiry);

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'pairingTopic': pairingTopic,
      'account': account,
      'namespaces': {
        for (final ns in namespaces)
          ns.namespace: ns.toJson(),
      },
      'metadata': metadata,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiry': expiry.millisecondsSinceEpoch,
    };
  }
}

/// Represents a session proposal.
class SessionProposal {

  SessionProposal({
    required this.id,
    required this.topic,
    required this.requiredNamespaces,
    required this.optionalNamespaces,
    required this.metadata,
    required this.expiry,
    required this.createdAt,
    required this.onApprove,
  });

  factory SessionProposal.fromJson(Map<String, dynamic> json, String topic, {Future<Session>? onApprove}) {
    final requiredNamespaces = (json['requiredNamespaces'] as Map<String, dynamic>)
        .entries
        .map((e) => NamespaceConfig.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();
    
    final optionalNamespaces = (json['optionalNamespaces'] as Map<String, dynamic>?)
        ?.entries
        .map((e) => NamespaceConfig.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList() ?? [];

    return SessionProposal(
      id: json['id'] as String,
      topic: topic,
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces,
      metadata: (json['proposer'] as Map<String, dynamic>)['metadata'] as Map<String, dynamic>,
      expiry: Duration(seconds: json['expiry'] as int? ?? 300),
      createdAt: DateTime.now(),
      onApprove: onApprove ?? Completer<Session>().future,
    );
  }
  final String id;
  final String topic;
  final List<NamespaceConfig> requiredNamespaces;
  final List<NamespaceConfig> optionalNamespaces;
  final Map<String, dynamic> metadata;
  final Duration expiry;
  final DateTime createdAt;
  final Future<Session> onApprove;

  bool get isExpired => DateTime.now().isAfter(createdAt.add(expiry));

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requiredNamespaces': {
        for (final ns in requiredNamespaces)
          ns.namespace: ns.toJson(),
      },
      'optionalNamespaces': {
        for (final ns in optionalNamespaces)
          ns.namespace: ns.toJson(),
      },
      'proposer': {
        'publicKey': 'placeholder', // Would be actual public key
        'metadata': metadata,
      },
      'expiry': (DateTime.now().add(expiry).millisecondsSinceEpoch ~/ 1000),
    };
  }
}

/// Session events.
class SessionEvent {

  SessionEvent._(this.type, {
    this.session,
    this.proposal,
    this.proposalId,
    this.reason,
    this.request,
  });

  factory SessionEvent.proposalSent(SessionProposal proposal) =>
      SessionEvent._(SessionEventType.proposalSent, proposal: proposal);
  
  factory SessionEvent.proposalReceived(SessionProposal proposal) =>
      SessionEvent._(SessionEventType.proposalReceived, proposal: proposal);
  
  factory SessionEvent.proposalRejected(String proposalId, String? reason) =>
      SessionEvent._(SessionEventType.proposalRejected, proposalId: proposalId, reason: reason);
  
  factory SessionEvent.established(Session session) =>
      SessionEvent._(SessionEventType.established, session: session);
  
  factory SessionEvent.updated(Session session) =>
      SessionEvent._(SessionEventType.updated, session: session);
  
  factory SessionEvent.extended(Session session) =>
      SessionEvent._(SessionEventType.extended, session: session);
  
  factory SessionEvent.disconnected(Session session, String? reason) =>
      SessionEvent._(SessionEventType.disconnected, session: session, reason: reason);
  
  factory SessionEvent.request(Session session, Map<String, dynamic> request) =>
      SessionEvent._(SessionEventType.request, session: session, request: request);
  final SessionEventType type;
  final Session? session;
  final SessionProposal? proposal;
  final String? proposalId;
  final String? reason;
  final Map<String, dynamic>? request;
}

enum SessionEventType {
  proposalSent,
  proposalReceived,
  proposalRejected,
  established,
  updated,
  extended,
  disconnected,
  request,
}
