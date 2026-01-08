import 'dart:typed_data';
import 'near_types.dart';

/// NEAR action types.
sealed class NearAction {
  const NearAction();

  /// Converts to JSON.
  Map<String, dynamic> toJson();
}

/// Create account action.
class CreateAccountAction extends NearAction {
  /// Creates a CreateAccountAction.
  const CreateAccountAction();

  @override
  Map<String, dynamic> toJson() => {'CreateAccount': {}};
}

/// Deploy contract action.
class DeployContractAction extends NearAction {
  /// Creates a DeployContractAction.
  const DeployContractAction({required this.code});

  /// WebAssembly code.
  final Uint8List code;

  @override
  Map<String, dynamic> toJson() => {
    'DeployContract': {'code': code},
  };
}

/// Function call action.
class FunctionCallAction extends NearAction {
  /// Creates a FunctionCallAction.
  const FunctionCallAction({
    required this.methodName,
    required this.args,
    required this.gas,
    required this.deposit,
  });

  /// Creates a simple function call.
  factory FunctionCallAction.call({
    required String methodName,
    Map<String, dynamic>? args,
    NearGas? gas,
    NearAmount? deposit,
  }) {
    return FunctionCallAction(
      methodName: methodName,
      args: args != null ? _jsonToBytes(args) : Uint8List(0),
      gas: gas ?? NearGas.defaultFunctionCall,
      deposit: deposit ?? NearAmount.zero,
    );
  }

  /// Method name.
  final String methodName;

  /// Method arguments (JSON encoded).
  final Uint8List args;

  /// Gas to attach.
  final NearGas gas;

  /// NEAR deposit.
  final NearAmount deposit;

  @override
  Map<String, dynamic> toJson() => {
    'FunctionCall': {
      'method_name': methodName,
      'args': args,
      'gas': gas.gas.toString(),
      'deposit': deposit.yoctoNear.toString(),
    },
  };
}

/// Transfer action.
class TransferAction extends NearAction {
  /// Creates a TransferAction.
  const TransferAction({required this.deposit});

  /// Amount to transfer.
  final NearAmount deposit;

  @override
  Map<String, dynamic> toJson() => {
    'Transfer': {'deposit': deposit.yoctoNear.toString()},
  };
}

/// Stake action.
class StakeAction extends NearAction {
  /// Creates a StakeAction.
  const StakeAction({required this.stake, required this.publicKey});

  /// Amount to stake.
  final NearAmount stake;

  /// Validator public key.
  final NearPublicKey publicKey;

  @override
  Map<String, dynamic> toJson() => {
    'Stake': {
      'stake': stake.yoctoNear.toString(),
      'public_key': publicKey.toStringKey(),
    },
  };
}

/// Add key action.
class AddKeyAction extends NearAction {
  /// Creates an AddKeyAction.
  const AddKeyAction({required this.publicKey, required this.accessKey});

  /// Public key to add.
  final NearPublicKey publicKey;

  /// Access key configuration.
  final NearAccessKey accessKey;

  @override
  Map<String, dynamic> toJson() => {
    'AddKey': {
      'public_key': publicKey.toStringKey(),
      'access_key': {
        'nonce': accessKey.nonce.toString(),
        'permission': _permissionToJson(accessKey.permission),
      },
    },
  };

  Map<String, dynamic> _permissionToJson(NearAccessKeyPermission permission) {
    if (permission is FullAccessPermission) {
      return {'FullAccess': {}};
    }
    if (permission is FunctionCallPermission) {
      return {
        'FunctionCall': {
          if (permission.allowance != null)
            'allowance': permission.allowance.toString(),
          'receiver_id': permission.receiverId,
          'method_names': permission.methodNames,
        },
      };
    }
    return {'FullAccess': {}};
  }
}

/// Delete key action.
class DeleteKeyAction extends NearAction {
  /// Creates a DeleteKeyAction.
  const DeleteKeyAction({required this.publicKey});

  /// Public key to delete.
  final NearPublicKey publicKey;

  @override
  Map<String, dynamic> toJson() => {
    'DeleteKey': {'public_key': publicKey.toStringKey()},
  };
}

/// Delete account action.
class DeleteAccountAction extends NearAction {
  /// Creates a DeleteAccountAction.
  const DeleteAccountAction({required this.beneficiaryId});

  /// Beneficiary account for remaining balance.
  final NearAccountId beneficiaryId;

  @override
  Map<String, dynamic> toJson() => {
    'DeleteAccount': {'beneficiary_id': beneficiaryId.value},
  };
}

/// NEAR transaction.
class NearTransaction {
  /// Creates a NearTransaction.
  const NearTransaction({
    required this.signerId,
    required this.publicKey,
    required this.nonce,
    required this.receiverId,
    required this.blockHash,
    required this.actions,
  });

  /// Signer account ID.
  final NearAccountId signerId;

  /// Signer public key.
  final NearPublicKey publicKey;

  /// Transaction nonce.
  final BigInt nonce;

  /// Receiver account ID.
  final NearAccountId receiverId;

  /// Recent block hash.
  final Uint8List blockHash;

  /// Actions to execute.
  final List<NearAction> actions;

  /// Serializes to bytes for signing.
  Uint8List serialize() {
    // Borsh serialization would go here
    return Uint8List(0);
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
    'signer_id': signerId.value,
    'public_key': publicKey.toStringKey(),
    'nonce': nonce.toString(),
    'receiver_id': receiverId.value,
    'block_hash': blockHash,
    'actions': actions.map((a) => a.toJson()).toList(),
  };
}

/// Signed NEAR transaction.
class SignedNearTransaction {
  /// Creates a SignedNearTransaction.
  const SignedNearTransaction({required this.transaction, required this.signature});

  /// The transaction.
  final NearTransaction transaction;

  /// Ed25519 signature.
  final NearSignature signature;

  /// Serializes to bytes.
  Uint8List serialize() {
    // Borsh serialization would go here
    return Uint8List(0);
  }

  /// Serializes to Base64.
  String toBase64() {
    // Base64 encoding would go here
    return 'placeholder';
  }

  /// Converts to JSON for RPC.
  List<dynamic> toRpcParams() {
    return [toBase64()];
  }
}

/// NEAR signature.
class NearSignature {
  /// Creates a NearSignature.
  const NearSignature({required this.keyType, required this.data});

  /// Key type.
  final NearKeyType keyType;

  /// Signature data (64 bytes for Ed25519).
  final Uint8List data;
}

/// Transaction outcome.
class NearTransactionOutcome {
  /// Creates a NearTransactionOutcome.
  const NearTransactionOutcome({
    required this.transactionHash,
    required this.outcome,
    required this.receiptsOutcome,
  });

  /// Creates from JSON.
  factory NearTransactionOutcome.fromJson(Map<String, dynamic> json) {
    return NearTransactionOutcome(
      transactionHash: json['transaction']['hash'] as String,
      outcome: NearExecutionOutcome.fromJson(
        json['transaction_outcome']['outcome'] as Map<String, dynamic>,
      ),
      receiptsOutcome: (json['receipts_outcome'] as List)
          .map((e) => NearReceiptOutcome.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Transaction hash.
  final String transactionHash;

  /// Main execution outcome.
  final NearExecutionOutcome outcome;

  /// Receipt outcomes.
  final List<NearReceiptOutcome> receiptsOutcome;

  /// Whether the transaction succeeded.
  bool get isSuccess => outcome.isSuccess;
}

/// Execution outcome.
class NearExecutionOutcome {
  /// Creates a NearExecutionOutcome.
  const NearExecutionOutcome({
    required this.gasBurnt,
    required this.tokensBurnt,
    required this.status,
    this.logs = const [],
    this.receiptIds = const [],
  });

  /// Creates from JSON.
  factory NearExecutionOutcome.fromJson(Map<String, dynamic> json) {
    return NearExecutionOutcome(
      gasBurnt: BigInt.parse(json['gas_burnt'].toString()),
      tokensBurnt: BigInt.parse(json['tokens_burnt'] as String),
      status: NearExecutionStatus.fromJson(json['status'] as dynamic),
      logs: (json['logs'] as List?)?.cast<String>() ?? [],
      receiptIds: (json['receipt_ids'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Gas burnt.
  final BigInt gasBurnt;

  /// Tokens burnt.
  final BigInt tokensBurnt;

  /// Execution status.
  final NearExecutionStatus status;

  /// Logs.
  final List<String> logs;

  /// Receipt IDs.
  final List<String> receiptIds;

  /// Whether execution succeeded.
  bool get isSuccess => status is SuccessStatus;
}

/// Execution status.
sealed class NearExecutionStatus {
  const NearExecutionStatus();

  /// Creates from JSON.
  factory NearExecutionStatus.fromJson(dynamic json) {
    if (json is String && json == 'Unknown') {
      return const UnknownStatus();
    }
    if (json is Map<String, dynamic>) {
      if (json.containsKey('SuccessValue')) {
        return SuccessValueStatus(json['SuccessValue'] as String);
      }
      if (json.containsKey('SuccessReceiptId')) {
        return SuccessReceiptIdStatus(json['SuccessReceiptId'] as String);
      }
      if (json.containsKey('Failure')) {
        return FailureStatus(json['Failure'] as Map<String, dynamic>);
      }
    }
    return const UnknownStatus();
  }
}

/// Unknown status.
class UnknownStatus extends NearExecutionStatus {
  /// Creates an UnknownStatus.
  const UnknownStatus();
}

/// Success with value.
class SuccessValueStatus extends NearExecutionStatus implements SuccessStatus {
  /// Creates a SuccessValueStatus.
  const SuccessValueStatus(this.value);

  /// Base64 encoded return value.
  final String value;
}

/// Success with receipt ID.
class SuccessReceiptIdStatus extends NearExecutionStatus implements SuccessStatus {
  /// Creates a SuccessReceiptIdStatus.
  const SuccessReceiptIdStatus(this.receiptId);

  /// Receipt ID.
  final String receiptId;
}

/// Marker interface for success statuses.
abstract class SuccessStatus {}

/// Failure status.
class FailureStatus extends NearExecutionStatus {
  /// Creates a FailureStatus.
  const FailureStatus(this.error);

  /// Error details.
  final Map<String, dynamic> error;
}

/// Receipt outcome.
class NearReceiptOutcome {
  /// Creates a NearReceiptOutcome.
  const NearReceiptOutcome({required this.id, required this.outcome});

  /// Creates from JSON.
  factory NearReceiptOutcome.fromJson(Map<String, dynamic> json) {
    return NearReceiptOutcome(
      id: json['id'] as String,
      outcome: NearExecutionOutcome.fromJson(
        json['outcome'] as Map<String, dynamic>,
      ),
    );
  }

  /// Receipt ID.
  final String id;

  /// Execution outcome.
  final NearExecutionOutcome outcome;
}

/// Transaction builder.
class NearTransactionBuilder {
  /// Creates a NearTransactionBuilder.
  NearTransactionBuilder({required this.signerId, required this.publicKey});

  /// Signer account ID.
  final NearAccountId signerId;

  /// Signer public key.
  final NearPublicKey publicKey;

  BigInt? _nonce;
  NearAccountId? _receiverId;
  Uint8List? _blockHash;
  final List<NearAction> _actions = [];

  /// Sets the nonce.
  NearTransactionBuilder nonce(BigInt nonce) {
    _nonce = nonce;
    return this;
  }

  /// Sets the receiver.
  NearTransactionBuilder receiver(NearAccountId receiverId) {
    _receiverId = receiverId;
    return this;
  }

  /// Sets the block hash.
  NearTransactionBuilder blockHash(Uint8List blockHash) {
    _blockHash = blockHash;
    return this;
  }

  /// Adds a transfer action.
  NearTransactionBuilder transfer(NearAmount amount) {
    _actions.add(TransferAction(deposit: amount));
    return this;
  }

  /// Adds a function call action.
  NearTransactionBuilder functionCall({
    required String methodName,
    Map<String, dynamic>? args,
    NearGas? gas,
    NearAmount? deposit,
  }) {
    _actions.add(FunctionCallAction.call(
      methodName: methodName,
      args: args,
      gas: gas,
      deposit: deposit,
    ));
    return this;
  }

  /// Adds a create account action.
  NearTransactionBuilder createAccount() {
    _actions.add(const CreateAccountAction());
    return this;
  }

  /// Adds a deploy contract action.
  NearTransactionBuilder deployContract(Uint8List code) {
    _actions.add(DeployContractAction(code: code));
    return this;
  }

  /// Adds a stake action.
  NearTransactionBuilder stake(NearAmount amount, NearPublicKey validatorKey) {
    _actions.add(StakeAction(stake: amount, publicKey: validatorKey));
    return this;
  }

  /// Adds an add key action.
  NearTransactionBuilder addKey(NearPublicKey key, NearAccessKey accessKey) {
    _actions.add(AddKeyAction(publicKey: key, accessKey: accessKey));
    return this;
  }

  /// Adds a delete key action.
  NearTransactionBuilder deleteKey(NearPublicKey key) {
    _actions.add(DeleteKeyAction(publicKey: key));
    return this;
  }

  /// Adds a delete account action.
  NearTransactionBuilder deleteAccount(NearAccountId beneficiary) {
    _actions.add(DeleteAccountAction(beneficiaryId: beneficiary));
    return this;
  }

  /// Builds the transaction.
  NearTransaction build() {
    if (_nonce == null) {
      throw StateError('Nonce not set');
    }
    if (_receiverId == null) {
      throw StateError('Receiver not set');
    }
    if (_blockHash == null) {
      throw StateError('Block hash not set');
    }
    if (_actions.isEmpty) {
      throw StateError('No actions added');
    }

    return NearTransaction(
      signerId: signerId,
      publicKey: publicKey,
      nonce: _nonce!,
      receiverId: _receiverId!,
      blockHash: _blockHash!,
      actions: _actions,
    );
  }
}

/// Helper to convert JSON to bytes.
Uint8List _jsonToBytes(Map<String, dynamic> json) {
  // JSON encoding
  final jsonString = json.toString();
  return Uint8List.fromList(jsonString.codeUnits);
}
