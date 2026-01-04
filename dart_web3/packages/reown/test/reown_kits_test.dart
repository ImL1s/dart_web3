import 'dart:async';
import 'package:test/test.dart';
import 'package:web3_universal_reown/web3_universal_reown.dart';
import 'package:web3_universal_reown/src/relay_client.dart';
import 'package:web3_universal_reown/src/session_manager.dart';
import 'package:web3_universal_reown/src/namespace_config.dart';

class MockRelayClient extends RelayClient {
  MockRelayClient() : super(relayUrl: 'mock://host', projectId: 'test');
  
  final List<Map<String, dynamic>> sentMessages = [];
  final _eventController = StreamController<RelayEvent>.broadcast();

  @override
  Stream<RelayEvent> get events => _eventController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {
    _eventController.add(RelayEvent.connected());
  }

  @override
  Future<void> publish({
    required String topic,
    required Map<String, dynamic> message,
    int? ttl,
    bool? prompt,
    String? tag,
  }) async {
    sentMessages.add({'topic': topic, 'message': message});
  }

  @override
  Future<String> subscribe(String topic) async {
    return 'sub_$topic';
  }

  void receiveMessage(String topic, Map<String, dynamic> message) {
    _eventController.add(RelayEvent.message(topic: topic, message: message));
  }
}

// Internal helper to inject mock relay into ReownClient
// Since we can't easily inject it into ReownClient (it creates its own RelayClient),
// we might need to modify ReownClient to accept an optional RelayClient or just test
// SessionManager directly.
// For the purpose of this PR, I'll test SessionManager which is the heart.

void main() {
  group('Reown Kits Integration', () {
    late MockRelayClient mockRelay;
    late SessionManager sessionManager;

    setUp(() {
      mockRelay = MockRelayClient();
      sessionManager = SessionManager(mockRelay);
    });

    test('Flow: AppKit Proposes -> WalletKit Approves', () async {
      // 1. AppKit (dApp) Proposes
      final namespaces = [
        NamespaceConfig(
          namespace: 'eip155',
          chains: ['eip155:1'],
          methods: ['eth_sendTransaction'],
          events: ['chainChanged'],
        ),
      ];

      final proposal = await sessionManager.proposeSession(
        requiredNamespaces: namespaces,
        metadata: {'name': 'dApp'},
      );

      // Verify proposal was "sent" (published to relay)
      expect(mockRelay.sentMessages.length, 1);
      final sentProposal = mockRelay.sentMessages.first;
      expect(sentProposal['message']['method'], 'wc_sessionPropose');
      
      final pairingTopic = proposal.topic;

      // 2. WalletKit (Wallet) receives proposal
      // In a real flow, the wallet pairs via URI, then receives the proposal
      // on the pairing topic.
      
      // Simulate receiving the proposal on the wallet side
      // (Using the same sessionManager for simplicity in this unit test)
      final receivedProposal = SessionProposal.fromJson(
        sentProposal['message']['params'] as Map<String, dynamic>,
        pairingTopic,
      );

      // Wallet approves
      final settledSessionByWallet = await sessionManager.approveSession(
        proposalId: receivedProposal.id,
        topic: receivedProposal.topic,
        namespaces: receivedProposal.requiredNamespaces,
        account: '0x123',
      );

      // Verify approval was sent
      expect(mockRelay.sentMessages.length, 2);
      final approvalMessage = mockRelay.sentMessages.last;
      expect(approvalMessage['message']['result'], isNotNull);
      final sessionTopic = approvalMessage['message']['result']['sessionTopic'];

      // 3. AppKit receives settlement
      // Simulate settlement message from relay
      mockRelay.receiveMessage(sessionTopic as String, {
        'id': '999',
        'jsonrpc': '2.0',
        'method': 'wc_sessionSettle',
        'params': {
          'pairingTopic': pairingTopic,
          'metadata': {'name': 'Wallet'},
          'expiry': (DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000),
          'state': {
            'accounts': ['0x123'],
          },
          'namespaces': {
            'eip155': {
              'chains': ['eip155:1'],
              'methods': ['eth_sendTransaction'],
              'events': ['chainChanged'],
            }
          }
        }
      });

      // Verification: Does onApprove resolve?
      final settledSessionByApp = await proposal.onApprove;
      expect(settledSessionByApp.account, '0x123');
      expect(settledSessionByApp.topic, sessionTopic);
      
      expect(settledSessionByWallet.account, '0x123');
    });
  group('Reown Kits Wrapper', () {});
  });
}
