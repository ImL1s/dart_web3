import 'dart:typed_data';

/// Supported curve types for MPC signing.
enum CurveType {
  /// secp256k1 curve (Ethereum, Bitcoin)
  secp256k1,
  
  /// ed25519 curve (Solana, Polkadot)
  ed25519,
}

/// MPC key share information.
class KeyShare {

  KeyShare({
    required this.partyId,
    required this.shareData,
    required this.curveType,
    required this.threshold,
    required this.totalParties,
    required this.publicKey,
    required this.createdAt,
    this.lastRefreshed,
  });

  /// Creates a KeyShare from JSON.
  factory KeyShare.fromJson(Map<String, dynamic> json) {
    return KeyShare(
      partyId: json['partyId'] as String,
      shareData: Uint8List.fromList((json['shareData'] as List).cast<int>()),
      curveType: CurveType.values.byName(json['curveType'] as String),
      threshold: json['threshold'] as int,
      totalParties: json['totalParties'] as int,
      publicKey: Uint8List.fromList((json['publicKey'] as List).cast<int>()),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastRefreshed: json['lastRefreshed'] != null 
          ? DateTime.parse(json['lastRefreshed'] as String) 
          : null,
    );
  }
  /// The party ID that owns this key share.
  final String partyId;
  
  /// The key share data (encrypted).
  final Uint8List shareData;
  
  /// The curve type for this key share.
  final CurveType curveType;
  
  /// The threshold required for signing.
  final int threshold;
  
  /// The total number of parties.
  final int totalParties;
  
  /// The public key derived from all shares.
  final Uint8List publicKey;
  
  /// Creation timestamp.
  final DateTime createdAt;
  
  /// Last refresh timestamp.
  final DateTime? lastRefreshed;

  /// Converts the KeyShare to JSON.
  Map<String, dynamic> toJson() {
    return {
      'partyId': partyId,
      'shareData': shareData.toList(),
      'curveType': curveType.name,
      'threshold': threshold,
      'totalParties': totalParties,
      'publicKey': publicKey.toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastRefreshed': lastRefreshed?.toIso8601String(),
    };
  }
}

/// MPC signing session state.
enum SigningSessionState {
  /// Session is being initialized.
  initializing,
  
  /// Waiting for parties to join.
  waitingForParties,
  
  /// Parties are signing.
  signing,
  
  /// Signature is complete.
  completed,
  
  /// Session failed or was cancelled.
  failed,
  
  /// Session was cancelled.
  cancelled,
}

/// MPC key generation ceremony state.
enum KeyGenerationState {
  /// Ceremony is being initialized.
  initializing,
  
  /// Waiting for parties to join.
  waitingForParties,
  
  /// Generating key shares.
  generating,
  
  /// Key generation is complete.
  completed,
  
  /// Key generation failed.
  failed,
  
  /// Key generation was cancelled.
  cancelled,
}

/// MPC provider configuration.
class MpcProviderConfig {

  MpcProviderConfig({
    required this.providerName,
    required this.apiUrl,
    required this.apiKey,
    this.additionalConfig = const {},
  });

  /// Creates an MpcProviderConfig from JSON.
  factory MpcProviderConfig.fromJson(Map<String, dynamic> json) {
    return MpcProviderConfig(
      providerName: json['providerName'] as String,
      apiUrl: json['apiUrl'] as String,
      apiKey: json['apiKey'] as String,
      additionalConfig: Map<String, dynamic>.from(json['additionalConfig'] as Map? ?? {}),
    );
  }
  /// The provider name (e.g., 'fireblocks', 'fordefi').
  final String providerName;
  
  /// API endpoint URL.
  final String apiUrl;
  
  /// API key for authentication.
  final String apiKey;
  
  /// Additional configuration parameters.
  final Map<String, dynamic> additionalConfig;

  /// Converts the MpcProviderConfig to JSON.
  Map<String, dynamic> toJson() {
    return {
      'providerName': providerName,
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'additionalConfig': additionalConfig,
    };
  }
}

/// MPC signing request.
class MpcSigningRequest {

  MpcSigningRequest({
    required this.messageHash,
    required this.curveType,
    required this.keyShareId,
    this.metadata = const {},
  });

  /// Creates an MpcSigningRequest from JSON.
  factory MpcSigningRequest.fromJson(Map<String, dynamic> json) {
    return MpcSigningRequest(
      messageHash: Uint8List.fromList((json['messageHash'] as List).cast<int>()),
      curveType: CurveType.values.byName(json['curveType'] as String),
      keyShareId: json['keyShareId'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
  /// The message hash to sign.
  final Uint8List messageHash;
  
  /// The curve type to use for signing.
  final CurveType curveType;
  
  /// The key share ID to use.
  final String keyShareId;
  
  /// Additional metadata for the signing request.
  final Map<String, dynamic> metadata;

  /// Converts the MpcSigningRequest to JSON.
  Map<String, dynamic> toJson() {
    return {
      'messageHash': messageHash.toList(),
      'curveType': curveType.name,
      'keyShareId': keyShareId,
      'metadata': metadata,
    };
  }
}

/// MPC signing response.
class MpcSigningResponse {

  MpcSigningResponse({
    required this.signature,
    required this.sessionId, required this.completedAt, this.recoveryId,
  });

  /// Creates an MpcSigningResponse from JSON.
  factory MpcSigningResponse.fromJson(Map<String, dynamic> json) {
    return MpcSigningResponse(
      signature: Uint8List.fromList((json['signature'] as List).cast<int>()),
      recoveryId: json['recoveryId'] as int?,
      sessionId: json['sessionId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
  /// The signature bytes.
  final Uint8List signature;
  
  /// The recovery ID (for ECDSA signatures).
  final int? recoveryId;
  
  /// The session ID that produced this signature.
  final String sessionId;
  
  /// Timestamp when the signature was completed.
  final DateTime completedAt;

  /// Converts the MpcSigningResponse to JSON.
  Map<String, dynamic> toJson() {
    return {
      'signature': signature.toList(),
      'recoveryId': recoveryId,
      'sessionId': sessionId,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}

/// MPC error types.
enum MpcErrorType {
  /// Network communication error.
  networkError,
  
  /// Authentication error.
  authenticationError,
  
  /// Insufficient parties for threshold.
  insufficientParties,
  
  /// Key generation failed.
  keyGenerationFailed,
  
  /// Signing failed.
  signingFailed,
  
  /// Session timeout.
  sessionTimeout,
  
  /// Invalid configuration.
  invalidConfiguration,
  
  /// Provider-specific error.
  providerError,
}

/// MPC-specific error.
class MpcError implements Exception {

  MpcError({
    required this.type,
    required this.message,
    this.data,
    this.cause,
  });
  /// The error type.
  final MpcErrorType type;
  
  /// The error message.
  final String message;
  
  /// Additional error data.
  final Map<String, dynamic>? data;
  
  /// The underlying cause.
  final Exception? cause;

  @override
  String toString() {
    return 'MpcError(${type.name}): $message';
  }
}

/// MPC wallet information.
class MpcWalletInfo {

  MpcWalletInfo({
    required this.walletId,
    required this.name,
    required this.curveType,
    required this.threshold,
    required this.totalParties,
    required this.publicKey,
    required this.status,
    required this.createdAt,
    required this.lastActivity,
  });
  final String walletId;
  final String name;
  final CurveType curveType;
  final int threshold;
  final int totalParties;
  final Uint8List publicKey;
  final MpcWalletStatus status;
  final DateTime createdAt;
  final DateTime lastActivity;
}

/// MPC wallet status.
enum MpcWalletStatus {
  active,
  pending,
  frozen,
  archived,
}

/// MPC signing status.
enum MpcSigningStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

/// Abstract MPC provider interface.
abstract class MpcProvider {
  MpcProviderConfig get config;
  
  Future<void> initialize();
  
  Future<String> createWallet({
    required String name,
    required int threshold,
    required int totalParties,
    required CurveType curveType,
    Map<String, dynamic>? metadata,
  });
  
  Future<MpcWalletInfo> getWallet(String walletId);
  
  Future<List<MpcWalletInfo>> listWallets();
  
  Future<String> initiateSigningRequest(MpcSigningRequest request);
  
  Future<MpcSigningStatus> getSigningStatus(String requestId);
  
  Future<MpcSigningResponse> getSigningResult(String requestId);
  
  Future<void> cancelSigningRequest(String requestId);
  
  Future<void> refreshWalletKeys(String walletId);
  
  Future<void> dispose();
}
