/// Pairing URI generation for Reown/WalletConnect v2 protocol.
library;

import 'dart:math';
import 'package:meta/meta.dart';

/// Generates pairing URIs for WalletConnect v2 protocol.
@immutable
class PairingUri {
  PairingUri({
    required this.topic,
    required this.symKey,
    required this.relay,
    this.expiryTimestamp,
  });

  /// Generates a new pairing URI with random topic and symmetric key.
  factory PairingUri.generate({
    String relay = 'wss://relay.walletconnect.com',
    Duration? expiry,
  }) {
    final random = Random.secure();

    // Generate random topic (32 bytes hex)
    final topicBytes = List.generate(32, (_) => random.nextInt(256));
    final topic =
        topicBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Generate random symmetric key (32 bytes hex)
    final symKeyBytes = List.generate(32, (_) => random.nextInt(256));
    final symKey =
        symKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final expiryTimestamp = expiry != null
        ? DateTime.now().add(expiry).millisecondsSinceEpoch ~/ 1000
        : null;

    return PairingUri(
      topic: topic,
      symKey: symKey,
      relay: relay,
      expiryTimestamp: expiryTimestamp,
    );
  }

  /// Parses a pairing URI string into a PairingUri object.
  factory PairingUri.parse(String uri) {
    if (!uri.startsWith('wc:')) {
      throw ArgumentError('Invalid WalletConnect URI: must start with "wc:"');
    }

    final parts = uri.substring(3).split('@');
    if (parts.length != 2) {
      throw ArgumentError('Invalid WalletConnect URI format');
    }

    final topic = parts[0];
    final paramsPart = parts[1];

    final queryIndex = paramsPart.indexOf('?');
    if (queryIndex == -1) {
      throw ArgumentError('Invalid WalletConnect URI: missing parameters');
    }

    final version = paramsPart.substring(0, queryIndex);
    if (version != '2') {
      throw ArgumentError('Unsupported WalletConnect version: $version');
    }

    final queryString = paramsPart.substring(queryIndex + 1);
    final params = Uri.splitQueryString(queryString);

    final relay = params['relay-protocol'];
    final symKey = params['symKey'];

    if (relay == null || symKey == null) {
      throw ArgumentError(
          'Missing required parameters: relay-protocol or symKey');
    }

    final expiryStr = params['expiryTimestamp'];
    final expiryTimestamp = expiryStr != null ? int.tryParse(expiryStr) : null;

    return PairingUri(
      topic: topic,
      symKey: symKey,
      relay: relay,
      expiryTimestamp: expiryTimestamp,
    );
  }
  final String topic;
  final String symKey;
  final String relay;
  final int? expiryTimestamp;

  /// Converts the pairing URI to a string format.
  String toUri() {
    final params = <String, String>{
      'relay-protocol': relay,
      'symKey': symKey,
    };

    if (expiryTimestamp != null) {
      params['expiryTimestamp'] = expiryTimestamp.toString();
    }

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'wc:$topic@2?$queryString';
  }

  /// Checks if the pairing URI has expired.
  bool get isExpired {
    if (expiryTimestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now > expiryTimestamp!;
  }

  /// Time remaining until expiry.
  Duration? get timeUntilExpiry {
    if (expiryTimestamp == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = expiryTimestamp! - now;
    return remaining > 0 ? Duration(seconds: remaining) : Duration.zero;
  }

  @override
  String toString() => toUri();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingUri &&
          runtimeType == other.runtimeType &&
          topic == other.topic &&
          symKey == other.symKey &&
          relay == other.relay &&
          expiryTimestamp == other.expiryTimestamp;

  @override
  int get hashCode =>
      topic.hashCode ^
      symKey.hashCode ^
      relay.hashCode ^
      (expiryTimestamp?.hashCode ?? 0);
}
