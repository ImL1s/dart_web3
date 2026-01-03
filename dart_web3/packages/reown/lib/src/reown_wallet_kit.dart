import 'dart:async';



import 'namespace_config.dart';
import 'pairing_uri.dart';
import 'reown_client.dart';
import 'session_manager.dart';

/// Reown WalletKit for building Wallets.
/// 
/// This kit provides a high-level API for Wallets to accept connections,
/// manage sessions, and sign requests.
class ReownWalletKit {
  /// Creates a new WalletKit instance.
  ReownWalletKit({
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

  /// Stream of session proposals.
  Stream<SessionProposal> get sessionProposals => _core.events
      .where((e) => e.type == ReownEventType.sessionProposalReceived)
      .map((e) => e.proposal!);

  /// Stream of session requests (sign/transact).
  Stream<ReownEvent> get sessionRequests => _core.events
      .where((e) => e.type == ReownEventType.sessionRequest);

  /// Active sessions.
  List<Session> get sessions => _core.sessions;

  /// Initializes the WalletKit.
  Future<void> init() async {
    await _core.connect();
  }

  /// Pairs with a dApp using the provided URI (from QR Code or Deep Link).
  Future<void> pair(String uri) async {
    await _core.pair(uri);
  }

  /// Approves a session proposal.
  Future<Session> approveSession({
    required SessionProposal proposal,
    required List<NamespaceConfig> namespaces,
    required String account, 
  }) async {
    return _core.approveSession(
      proposalId: proposal.id,
      topic: proposal.topic,
      namespaces: namespaces,
      account: account,
      metadata: metadata,
    );
  }

  /// Rejects a session proposal.
  Future<void> rejectSession({
    required SessionProposal proposal,
    String reason = 'User rejected',
  }) async {
    await _core.rejectSession(
      proposalId: proposal.id,
      topic: proposal.topic,
      reason: reason,
    );
  }

  /// Updates an active session.
  Future<void> updateSession({
    required String topic,
    required List<NamespaceConfig> namespaces,
  }) async {
    await _core.updateSession(topic: topic, namespaces: namespaces);
  }

  /// Disconnects a session.
  Future<void> disconnectSession(String topic) async {
    await _core.disconnectSession(topic);
  }
}
