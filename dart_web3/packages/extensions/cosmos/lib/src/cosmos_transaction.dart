import 'dart:typed_data';
import 'cosmos_types.dart';

/// Cosmos message types.
sealed class CosmosMsg {
  const CosmosMsg();

  /// Converts to JSON (Amino or Direct encoding).
  Map<String, dynamic> toJson();

  /// Gets the type URL for Direct/Protobuf encoding.
  String get typeUrl;
}

/// MsgSend - transfer tokens.
class MsgSend extends CosmosMsg {
  /// Creates a MsgSend.
  const MsgSend({
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
  });

  /// Sender address.
  final String fromAddress;

  /// Recipient address.
  final String toAddress;

  /// Amount to send.
  final List<CosmosCoin> amount;

  @override
  String get typeUrl => '/cosmos.bank.v1beta1.MsgSend';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'from_address': fromAddress,
    'to_address': toAddress,
    'amount': amount.map((c) => c.toJson()).toList(),
  };
}

/// MsgDelegate - delegate tokens to a validator.
class MsgDelegate extends CosmosMsg {
  /// Creates a MsgDelegate.
  const MsgDelegate({
    required this.delegatorAddress,
    required this.validatorAddress,
    required this.amount,
  });

  /// Delegator address.
  final String delegatorAddress;

  /// Validator address.
  final String validatorAddress;

  /// Amount to delegate.
  final CosmosCoin amount;

  @override
  String get typeUrl => '/cosmos.staking.v1beta1.MsgDelegate';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'delegator_address': delegatorAddress,
    'validator_address': validatorAddress,
    'amount': amount.toJson(),
  };
}

/// MsgUndelegate - undelegate tokens from a validator.
class MsgUndelegate extends CosmosMsg {
  /// Creates a MsgUndelegate.
  const MsgUndelegate({
    required this.delegatorAddress,
    required this.validatorAddress,
    required this.amount,
  });

  /// Delegator address.
  final String delegatorAddress;

  /// Validator address.
  final String validatorAddress;

  /// Amount to undelegate.
  final CosmosCoin amount;

  @override
  String get typeUrl => '/cosmos.staking.v1beta1.MsgUndelegate';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'delegator_address': delegatorAddress,
    'validator_address': validatorAddress,
    'amount': amount.toJson(),
  };
}

/// MsgBeginRedelegate - redelegate tokens between validators.
class MsgBeginRedelegate extends CosmosMsg {
  /// Creates a MsgBeginRedelegate.
  const MsgBeginRedelegate({
    required this.delegatorAddress,
    required this.validatorSrcAddress,
    required this.validatorDstAddress,
    required this.amount,
  });

  /// Delegator address.
  final String delegatorAddress;

  /// Source validator address.
  final String validatorSrcAddress;

  /// Destination validator address.
  final String validatorDstAddress;

  /// Amount to redelegate.
  final CosmosCoin amount;

  @override
  String get typeUrl => '/cosmos.staking.v1beta1.MsgBeginRedelegate';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'delegator_address': delegatorAddress,
    'validator_src_address': validatorSrcAddress,
    'validator_dst_address': validatorDstAddress,
    'amount': amount.toJson(),
  };
}

/// MsgWithdrawDelegatorReward - withdraw staking rewards.
class MsgWithdrawDelegatorReward extends CosmosMsg {
  /// Creates a MsgWithdrawDelegatorReward.
  const MsgWithdrawDelegatorReward({
    required this.delegatorAddress,
    required this.validatorAddress,
  });

  /// Delegator address.
  final String delegatorAddress;

  /// Validator address.
  final String validatorAddress;

  @override
  String get typeUrl => '/cosmos.distribution.v1beta1.MsgWithdrawDelegatorReward';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'delegator_address': delegatorAddress,
    'validator_address': validatorAddress,
  };
}

/// MsgVote - vote on a governance proposal.
class MsgVote extends CosmosMsg {
  /// Creates a MsgVote.
  const MsgVote({
    required this.proposalId,
    required this.voter,
    required this.option,
  });

  /// Proposal ID.
  final BigInt proposalId;

  /// Voter address.
  final String voter;

  /// Vote option.
  final VoteOption option;

  @override
  String get typeUrl => '/cosmos.gov.v1beta1.MsgVote';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'proposal_id': proposalId.toString(),
    'voter': voter,
    'option': option.value,
  };
}

/// Vote options.
enum VoteOption {
  /// Unspecified vote.
  unspecified('VOTE_OPTION_UNSPECIFIED', 0),

  /// Yes vote.
  yes('VOTE_OPTION_YES', 1),

  /// Abstain vote.
  abstain('VOTE_OPTION_ABSTAIN', 2),

  /// No vote.
  no('VOTE_OPTION_NO', 3),

  /// No with veto vote.
  noWithVeto('VOTE_OPTION_NO_WITH_VETO', 4);

  const VoteOption(this.value, this.number);

  /// String value.
  final String value;

  /// Numeric value.
  final int number;
}

/// MsgTransfer - IBC token transfer.
class MsgTransfer extends CosmosMsg {
  /// Creates a MsgTransfer.
  const MsgTransfer({
    required this.sourcePort,
    required this.sourceChannel,
    required this.token,
    required this.sender,
    required this.receiver,
    required this.timeoutHeight,
    required this.timeoutTimestamp,
    this.memo,
  });

  /// Source port (usually "transfer").
  final String sourcePort;

  /// Source channel ID.
  final String sourceChannel;

  /// Token to transfer.
  final CosmosCoin token;

  /// Sender address.
  final String sender;

  /// Receiver address on destination chain.
  final String receiver;

  /// Timeout block height.
  final IbcHeight timeoutHeight;

  /// Timeout timestamp in nanoseconds.
  final BigInt timeoutTimestamp;

  /// Optional memo.
  final String? memo;

  @override
  String get typeUrl => '/ibc.applications.transfer.v1.MsgTransfer';

  @override
  Map<String, dynamic> toJson() => {
    '@type': typeUrl,
    'source_port': sourcePort,
    'source_channel': sourceChannel,
    'token': token.toJson(),
    'sender': sender,
    'receiver': receiver,
    'timeout_height': timeoutHeight.toJson(),
    'timeout_timestamp': timeoutTimestamp.toString(),
    if (memo != null) 'memo': memo,
  };
}

/// IBC height.
class IbcHeight {
  /// Creates an IbcHeight.
  const IbcHeight({required this.revisionNumber, required this.revisionHeight});

  /// Zero height (use timestamp instead).
  static final zero = IbcHeight(revisionNumber: BigInt.zero, revisionHeight: BigInt.zero);

  /// Revision number.
  final BigInt revisionNumber;

  /// Revision height.
  final BigInt revisionHeight;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'revision_number': revisionNumber.toString(),
    'revision_height': revisionHeight.toString(),
  };
}

/// Cosmos transaction body.
class CosmosTxBody {
  /// Creates a CosmosTxBody.
  CosmosTxBody({
    required this.messages,
    this.memo = '',
    BigInt? timeoutHeight,
    this.extensionOptions = const [],
    this.nonCriticalExtensionOptions = const [],
  }) : timeoutHeight = timeoutHeight ?? BigInt.zero;

  /// Messages.
  final List<CosmosMsg> messages;

  /// Memo.
  final String memo;

  /// Timeout height.
  final BigInt timeoutHeight;

  /// Extension options.
  final List<Map<String, dynamic>> extensionOptions;

  /// Non-critical extension options.
  final List<Map<String, dynamic>> nonCriticalExtensionOptions;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'messages': messages.map((m) => m.toJson()).toList(),
    'memo': memo,
    'timeout_height': timeoutHeight.toString(),
    'extension_options': extensionOptions,
    'non_critical_extension_options': nonCriticalExtensionOptions,
  };
}

/// Cosmos auth info.
class CosmosAuthInfo {
  /// Creates a CosmosAuthInfo.
  const CosmosAuthInfo({required this.signerInfos, required this.fee});

  /// Signer information.
  final List<CosmosSignerInfo> signerInfos;

  /// Fee.
  final CosmosFee fee;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'signer_infos': signerInfos.map((s) => s.toJson()).toList(),
    'fee': fee.toJson(),
  };
}

/// Cosmos signer info.
class CosmosSignerInfo {
  /// Creates a CosmosSignerInfo.
  const CosmosSignerInfo({
    required this.publicKey,
    required this.modeInfo,
    required this.sequence,
  });

  /// Public key.
  final CosmosPubKey publicKey;

  /// Mode info.
  final CosmosModeInfo modeInfo;

  /// Sequence number.
  final BigInt sequence;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'public_key': publicKey.toJson(),
    'mode_info': modeInfo.toJson(),
    'sequence': sequence.toString(),
  };
}

/// Cosmos public key.
sealed class CosmosPubKey {
  const CosmosPubKey();

  /// Converts to JSON.
  Map<String, dynamic> toJson();
}

/// Secp256k1 public key.
class Secp256k1PubKey extends CosmosPubKey {
  /// Creates a Secp256k1PubKey.
  const Secp256k1PubKey(this.key);

  /// Public key bytes (33 bytes compressed).
  final Uint8List key;

  @override
  Map<String, dynamic> toJson() => {
    '@type': '/cosmos.crypto.secp256k1.PubKey',
    'key': _bytesToBase64(key),
  };
}

/// Ed25519 public key.
class Ed25519PubKey extends CosmosPubKey {
  /// Creates an Ed25519PubKey.
  const Ed25519PubKey(this.key);

  /// Public key bytes (32 bytes).
  final Uint8List key;

  @override
  Map<String, dynamic> toJson() => {
    '@type': '/cosmos.crypto.ed25519.PubKey',
    'key': _bytesToBase64(key),
  };
}

/// Cosmos mode info.
sealed class CosmosModeInfo {
  const CosmosModeInfo();

  /// Converts to JSON.
  Map<String, dynamic> toJson();
}

/// Single signature mode info.
class SingleModeInfo extends CosmosModeInfo {
  /// Creates a SingleModeInfo.
  const SingleModeInfo({required this.mode});

  /// Sign mode.
  final SignMode mode;

  @override
  Map<String, dynamic> toJson() => {
    'single': {'mode': mode.value},
  };
}

/// Multi signature mode info.
class MultiModeInfo extends CosmosModeInfo {
  /// Creates a MultiModeInfo.
  const MultiModeInfo({required this.bitarray, required this.modeInfos});

  /// Bit array indicating which keys signed.
  final CompactBitArray bitarray;

  /// Mode infos for each signer.
  final List<CosmosModeInfo> modeInfos;

  @override
  Map<String, dynamic> toJson() => {
    'multi': {
      'bitarray': bitarray.toJson(),
      'mode_infos': modeInfos.map((m) => m.toJson()).toList(),
    },
  };
}

/// Sign modes.
enum SignMode {
  /// Unspecified mode.
  unspecified('SIGN_MODE_UNSPECIFIED', 0),

  /// Direct (Protobuf) mode.
  direct('SIGN_MODE_DIRECT', 1),

  /// Textual mode.
  textual('SIGN_MODE_TEXTUAL', 2),

  /// Direct aux mode.
  directAux('SIGN_MODE_DIRECT_AUX', 3),

  /// Legacy Amino JSON mode.
  legacyAminoJson('SIGN_MODE_LEGACY_AMINO_JSON', 127),

  /// EIP-191 mode.
  eip191('SIGN_MODE_EIP_191', 191);

  const SignMode(this.value, this.number);

  /// String value.
  final String value;

  /// Numeric value.
  final int number;
}

/// Compact bit array.
class CompactBitArray {
  /// Creates a CompactBitArray.
  const CompactBitArray({required this.extraBitsStored, required this.elems});

  /// Extra bits stored.
  final int extraBitsStored;

  /// Element bytes.
  final Uint8List elems;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'extra_bits_stored': extraBitsStored,
    'elems': _bytesToBase64(elems),
  };
}

/// Cosmos transaction (ready for broadcast).
class CosmosTx {
  /// Creates a CosmosTx.
  const CosmosTx({required this.body, required this.authInfo, required this.signatures});

  /// Transaction body.
  final CosmosTxBody body;

  /// Auth info.
  final CosmosAuthInfo authInfo;

  /// Signatures.
  final List<Uint8List> signatures;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'body': body.toJson(),
    'auth_info': authInfo.toJson(),
    'signatures': signatures.map(_bytesToBase64).toList(),
  };
}

/// Transaction builder.
class CosmosTxBuilder {
  /// Creates a CosmosTxBuilder.
  CosmosTxBuilder({required this.chainId});

  /// Chain ID.
  final String chainId;

  final List<CosmosMsg> _messages = [];
  String _memo = '';
  BigInt _timeoutHeight = BigInt.zero;
  CosmosFee? _fee;
  final List<_SignerConfig> _signers = [];

  /// Adds a message.
  CosmosTxBuilder addMessage(CosmosMsg message) {
    _messages.add(message);
    return this;
  }

  /// Sets the memo.
  CosmosTxBuilder memo(String memo) {
    _memo = memo;
    return this;
  }

  /// Sets the timeout height.
  CosmosTxBuilder timeoutHeight(BigInt height) {
    _timeoutHeight = height;
    return this;
  }

  /// Sets the fee.
  CosmosTxBuilder fee({
    required List<CosmosCoin> amount,
    required BigInt gasLimit,
    String? payer,
    String? granter,
  }) {
    _fee = CosmosFee(
      amount: amount,
      gasLimit: gasLimit,
      payer: payer,
      granter: granter,
    );
    return this;
  }

  /// Adds a signer.
  CosmosTxBuilder addSigner({
    required CosmosPubKey publicKey,
    required BigInt sequence,
    SignMode mode = SignMode.direct,
  }) {
    _signers.add(_SignerConfig(publicKey: publicKey, sequence: sequence, mode: mode));
    return this;
  }

  /// Builds the transaction body.
  CosmosTxBody buildBody() {
    return CosmosTxBody(
      messages: _messages,
      memo: _memo,
      timeoutHeight: _timeoutHeight,
    );
  }

  /// Builds the auth info.
  CosmosAuthInfo buildAuthInfo() {
    if (_fee == null) {
      throw StateError('Fee not set');
    }

    return CosmosAuthInfo(
      signerInfos: _signers
          .map((s) => CosmosSignerInfo(
                publicKey: s.publicKey,
                modeInfo: SingleModeInfo(mode: s.mode),
                sequence: s.sequence,
              ))
          .toList(),
      fee: _fee!,
    );
  }
}

class _SignerConfig {
  const _SignerConfig({
    required this.publicKey,
    required this.sequence,
    required this.mode,
  });

  final CosmosPubKey publicKey;
  final BigInt sequence;
  final SignMode mode;
}

/// Helper to convert bytes to Base64.
String _bytesToBase64(Uint8List bytes) {
  // Simple Base64 encoding placeholder
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
