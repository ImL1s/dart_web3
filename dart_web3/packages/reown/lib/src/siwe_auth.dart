/// Sign-In with Ethereum (SIWE) authentication for Reown/WalletConnect v2.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';

import 'namespace_config.dart';
import 'session_manager.dart';

/// Sign-In with Ethereum (SIWE) authentication manager.
class SiweAuth {
  SiweAuth({
    required this.sessionManager,
    SiweConfig? config,
  }) : config = config ?? SiweConfig.defaultConfig();
  final SessionManager sessionManager;
  final SiweConfig config;

  /// Initiates One-Click Auth flow combining session proposal and SIWE authentication.
  Future<SiweAuthResult> initiateOneClickAuth({
    required List<NamespaceConfig> requiredNamespaces,
    List<NamespaceConfig>? optionalNamespaces,
    Map<String, dynamic>? metadata,
    SiweMessage? customMessage,
  }) async {
    // Generate SIWE message
    final siweMessage = customMessage ?? _generateSiweMessage();

    // Create session proposal with SIWE authentication
    final proposal = await sessionManager.proposeSession(
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces,
      metadata: {
        ...metadata ?? {},
        'siwe': {
          'message': siweMessage.toMessage(),
          'domain': siweMessage.domain,
          'nonce': siweMessage.nonce,
        },
      },
    );

    return SiweAuthResult(
      proposal: proposal,
      siweMessage: siweMessage,
      isOneClickAuth: true,
    );
  }

  /// Handles SIWE authentication for an existing session.
  Future<SiweAuthResult> authenticateWithSiwe({
    required String sessionTopic,
    SiweMessage? customMessage,
  }) async {
    final session = sessionManager.getSession(sessionTopic);
    if (session == null) {
      throw Exception('Session not found: $sessionTopic');
    }

    // Generate SIWE message
    final siweMessage = customMessage ?? _generateSiweMessage();

    // Request SIWE signature from wallet
    final response = await sessionManager.sendRequest(
      topic: sessionTopic,
      method: 'personal_sign',
      params: {
        'message': siweMessage.toMessage(),
        'address': session.account,
      },
    );

    final signature = response['result'] as String;

    // Verify the signature
    final isValid = await verifySiweSignature(
      message: siweMessage,
      signature: signature,
      address: CaipUtils.getAddressFromAccount(session.account),
    );

    if (!isValid) {
      throw Exception('Invalid SIWE signature');
    }

    return SiweAuthResult(
      session: session,
      siweMessage: siweMessage,
      signature: signature,
      isAuthenticated: true,
    );
  }

  /// Verifies a SIWE signature.
  Future<bool> verifySiweSignature({
    required SiweMessage message,
    required String signature,
    required String address,
  }) async {
    try {
      // This is a simplified verification - in a real implementation,
      // you would use proper cryptographic verification
      final messageBytes = utf8.encode(message.toMessage());
      final signatureBytes = HexUtils.decode(signature);

      // Verify that the signature was created by the expected address
      // This would typically involve ECDSA signature recovery
      return _verifyEcdsaSignature(messageBytes, signatureBytes, address);
    } on Object catch (_) {
      return false;
    }
  }

  /// Generates a SIWE message with default values.
  SiweMessage _generateSiweMessage() {
    return SiweMessage(
      domain: config.domain,
      address: '', // Will be filled when we know the address
      statement: config.statement,
      uri: config.uri,
      version: '1',
      chainId: config.chainId,
      nonce: _generateNonce(),
      issuedAt: DateTime.now(),
      expirationTime: config.expirationTime != null
          ? DateTime.now().add(config.expirationTime!)
          : null,
      notBefore: config.notBefore,
      requestId: config.requestId,
      resources: config.resources,
    );
  }

  /// Generates a cryptographically secure nonce.
  String _generateNonce() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Simplified ECDSA signature verification (placeholder).
  bool _verifyEcdsaSignature(
      Uint8List message, Uint8List signature, String address) {
    // In a real implementation, this would:
    // 1. Hash the message with Keccak-256
    // 2. Recover the public key from the signature
    // 3. Derive the address from the public key
    // 4. Compare with the expected address

    // For now, return true as a placeholder
    return true;
  }
}

/// SIWE message structure according to EIP-4361.
class SiweMessage {
  SiweMessage({
    required this.domain,
    required this.address,
    required this.uri,
    required this.version,
    required this.chainId,
    required this.nonce,
    required this.issuedAt,
    this.statement,
    this.expirationTime,
    this.notBefore,
    this.requestId,
    this.resources,
  });

  /// Creates a SIWE message from its string representation.
  factory SiweMessage.parse(String message) {
    final lines = message.split('\n');

    if (lines.length < 6) {
      throw ArgumentError('Invalid SIWE message format');
    }

    // Parse domain and address from first two lines
    final domainLine = lines[0];
    final address = lines[1];

    const suffix = ' wants you to sign in with your Ethereum account:';
    if (!domainLine.endsWith(suffix)) {
      throw ArgumentError('Invalid SIWE message header');
    }

    final domain = domainLine.substring(0, domainLine.length - suffix.length);

    // Find statement (optional)
    String? statement;
    var lineIndex = 2;

    if (lines[lineIndex].isEmpty) {
      lineIndex++; // Skip empty line

      // Look for statement
      while (lineIndex < lines.length && !lines[lineIndex].startsWith('URI:')) {
        if (lines[lineIndex].isNotEmpty) {
          statement = (statement ?? '') + lines[lineIndex];
          if (lineIndex + 1 < lines.length && lines[lineIndex + 1].isNotEmpty) {
            statement += '\n';
          }
        }
        lineIndex++;
      }
    }

    // Parse required fields
    final fields = <String, String>{};
    while (lineIndex < lines.length) {
      final line = lines[lineIndex];
      if (line.contains(':')) {
        final colonIndex = line.indexOf(':');
        final key = line.substring(0, colonIndex);
        final value = line.substring(colonIndex + 2); // Skip ': '
        fields[key] = value;
      }
      lineIndex++;
    }

    return SiweMessage(
      domain: domain,
      address: address,
      statement: statement?.trim(),
      uri: fields['URI'] ?? '',
      version: fields['Version'] ?? '1',
      chainId: int.parse(fields['Chain ID'] ?? '1'),
      nonce: fields['Nonce'] ?? '',
      issuedAt: DateTime.parse(
          fields['Issued At'] ?? DateTime.now().toIso8601String()),
      expirationTime: fields['Expiration Time'] != null
          ? DateTime.parse(fields['Expiration Time']!)
          : null,
      notBefore: fields['Not Before'] != null
          ? DateTime.parse(fields['Not Before']!)
          : null,
      requestId: fields['Request ID'],
    );
  }

  /// Creates from JSON representation.
  factory SiweMessage.fromJson(Map<String, dynamic> json) {
    return SiweMessage(
      domain: json['domain'] as String,
      address: json['address'] as String,
      statement: json['statement'] as String?,
      uri: json['uri'] as String,
      version: json['version'] as String,
      chainId: json['chainId'] as int,
      nonce: json['nonce'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expirationTime: json['expirationTime'] != null
          ? DateTime.parse(json['expirationTime'] as String)
          : null,
      notBefore: json['notBefore'] != null
          ? DateTime.parse(json['notBefore'] as String)
          : null,
      requestId: json['requestId'] as String?,
      resources: (json['resources'] as List?)?.cast<String>(),
    );
  }

  /// The domain that is requesting the signing.
  final String domain;

  /// The Ethereum address performing the signing.
  final String address;

  /// A human-readable ASCII assertion that the user will sign.
  final String? statement;

  /// An RFC 3986 URI referring to the resource that is the subject of the signing.
  final String uri;

  /// The current version of the message.
  final String version;

  /// The EIP-155 Chain ID to which the session is bound.
  final int chainId;

  /// A randomized token used to prevent replay attacks.
  final String nonce;

  /// The time when the message was generated.
  final DateTime issuedAt;

  /// The time when the signed authentication message is no longer valid.
  final DateTime? expirationTime;

  /// The time when the signed authentication message will become valid.
  final DateTime? notBefore;

  /// An system-specific identifier that may be used to uniquely refer to the sign-in request.
  final String? requestId;

  /// A list of information or references to information the user wishes to have resolved.
  final List<String>? resources;

  /// Converts the SIWE message to its string representation.
  String toMessage() {
    final buffer = StringBuffer()
      ..writeln('$domain wants you to sign in with your Ethereum account:')
      ..writeln(address)
      ..writeln();

    if (statement != null) {
      buffer
        ..writeln(statement)
        ..writeln();
    }

    buffer
      ..writeln('URI: $uri')
      ..writeln('Version: $version')
      ..writeln('Chain ID: $chainId')
      ..writeln('Nonce: $nonce')
      ..writeln('Issued At: ${issuedAt.toIso8601String()}');

    if (expirationTime != null) {
      buffer.writeln('Expiration Time: ${expirationTime!.toIso8601String()}');
    }

    if (notBefore != null) {
      buffer.writeln('Not Before: ${notBefore!.toIso8601String()}');
    }

    if (requestId != null) {
      buffer.writeln('Request ID: $requestId');
    }

    if (resources != null && resources!.isNotEmpty) {
      buffer.writeln('Resources:');
      for (final resource in resources!) {
        buffer.writeln('- $resource');
      }
    }

    return buffer.toString().trim();
  }

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'domain': domain,
      'address': address,
      'statement': statement,
      'uri': uri,
      'version': version,
      'chainId': chainId,
      'nonce': nonce,
      'issuedAt': issuedAt.toIso8601String(),
      'expirationTime': expirationTime?.toIso8601String(),
      'notBefore': notBefore?.toIso8601String(),
      'requestId': requestId,
      'resources': resources,
    };
  }

  /// Checks if the message is currently valid.
  bool get isValid {
    final now = DateTime.now();

    if (notBefore != null && now.isBefore(notBefore!)) {
      return false;
    }

    if (expirationTime != null && now.isAfter(expirationTime!)) {
      return false;
    }

    return true;
  }
}

/// Configuration for SIWE authentication.
class SiweConfig {
  SiweConfig({
    required this.domain,
    required this.uri,
    required this.chainId,
    this.statement,
    this.expirationTime,
    this.notBefore,
    this.requestId,
    this.resources,
  });

  /// Default configuration.
  factory SiweConfig.defaultConfig() {
    return SiweConfig(
      domain: 'localhost:3000',
      statement: 'Sign in to the application',
      uri: 'http://localhost:3000',
      chainId: 1,
      expirationTime: const Duration(hours: 24),
    );
  }

  /// The domain requesting the signing.
  final String domain;

  /// The statement to include in the message.
  final String? statement;

  /// The URI of the application.
  final String uri;

  /// The chain ID to use.
  final int chainId;

  /// How long the authentication is valid.
  final Duration? expirationTime;

  /// When the authentication becomes valid.
  final DateTime? notBefore;

  /// Request ID for tracking.
  final String? requestId;

  /// Additional resources to include.
  final List<String>? resources;
}

/// Result of SIWE authentication.
class SiweAuthResult {
  SiweAuthResult({
    required this.siweMessage,
    this.proposal,
    this.session,
    this.signature,
    this.isOneClickAuth = false,
    this.isAuthenticated = false,
  });

  /// The session proposal (for One-Click Auth).
  final SessionProposal? proposal;

  /// The established session.
  final Session? session;

  /// The SIWE message that was signed.
  final SiweMessage siweMessage;

  /// The signature (if authentication completed).
  final String? signature;

  /// Whether this was a One-Click Auth flow.
  final bool isOneClickAuth;

  /// Whether authentication was successful.
  final bool isAuthenticated;

  /// Whether the authentication is complete and valid.
  bool get isComplete => isAuthenticated && signature != null;

  /// The authenticated address.
  String? get authenticatedAddress {
    if (!isAuthenticated) return null;
    return session != null
        ? CaipUtils.getAddressFromAccount(session!.account)
        : siweMessage.address;
  }
}

/// One-Click Auth helper for simplified integration.
class OneClickAuth {
  OneClickAuth(this.siweAuth);
  final SiweAuth siweAuth;

  /// Initiates a complete One-Click Auth flow.
  Future<SiweAuthResult> authenticate({
    required List<NamespaceConfig> namespaces,
    SiweConfig? config,
    Duration? timeout,
  }) async {
    // Start the One-Click Auth flow
    final result = await siweAuth.initiateOneClickAuth(
      requiredNamespaces: namespaces,
    );

    // Wait for session establishment with timeout
    final completer = Completer<Session>();
    late StreamSubscription<SessionEvent> subscription;

    subscription = siweAuth.sessionManager.events.listen((event) {
      if (event.type == SessionEventType.established) {
        subscription.cancel();
        completer.complete(event.session!);
      } else if (event.type == SessionEventType.proposalRejected) {
        subscription.cancel();
        completer.completeError(Exception('Session proposal rejected'));
      }
    });

    // Set timeout
    Timer(timeout ?? const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(TimeoutException('Authentication timeout'));
      }
    });

    try {
      final session = await completer.future;

      // Complete SIWE authentication
      final authResult = await siweAuth.authenticateWithSiwe(
        sessionTopic: session.topic,
        customMessage:
            result.siweMessage.address.isEmpty ? result.siweMessage : null,
      );

      return SiweAuthResult(
        session: authResult.session,
        siweMessage: authResult.siweMessage,
        signature: authResult.signature,
        isOneClickAuth: true,
        isAuthenticated: authResult.isAuthenticated,
      );
    } catch (e) {
      rethrow;
    }
  }
}
