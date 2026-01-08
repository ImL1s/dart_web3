import 'dart:typed_data';
import 'sui_types.dart';

/// Sui transaction kind.
sealed class SuiTransactionKind {
  const SuiTransactionKind();
}

/// Programmable transaction block.
class ProgrammableTransaction extends SuiTransactionKind {
  /// Creates a ProgrammableTransaction.
  const ProgrammableTransaction({required this.inputs, required this.commands});

  /// Transaction inputs.
  final List<SuiCallArg> inputs;

  /// Transaction commands.
  final List<SuiCommand> commands;
}

/// Transaction input argument.
sealed class SuiCallArg {
  const SuiCallArg();
}

/// Pure value argument (BCS encoded).
class PureArg extends SuiCallArg {
  /// Creates a PureArg.
  const PureArg(this.value);

  /// BCS encoded value.
  final Uint8List value;

  /// Creates a pure u64 argument.
  static PureArg u64(BigInt value) {
    final bytes = Uint8List(8);
    var v = value;
    for (var i = 0; i < 8; i++) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return PureArg(bytes);
  }

  /// Creates a pure address argument.
  static PureArg address(SuiAddress address) {
    return PureArg(address.bytes);
  }

  /// Creates a pure bool argument.
  static PureArg bool_(bool value) {
    return PureArg(Uint8List.fromList([value ? 1 : 0]));
  }

  /// Creates a pure string argument (UTF-8 encoded).
  static PureArg string(String value) {
    final bytes = Uint8List.fromList(value.codeUnits);
    // BCS string encoding includes length prefix
    final result = Uint8List(bytes.length + 1);
    result[0] = bytes.length;
    result.setRange(1, result.length, bytes);
    return PureArg(result);
  }
}

/// Object argument.
class ObjectArg extends SuiCallArg {
  /// Creates an ObjectArg.
  const ObjectArg(this.objectRef);

  /// Object reference.
  final SuiObjectRef objectRef;
}

/// Shared object argument.
class SharedObjectArg extends SuiCallArg {
  /// Creates a SharedObjectArg.
  const SharedObjectArg({
    required this.objectId,
    required this.initialSharedVersion,
    required this.mutable,
  });

  /// Object ID.
  final SuiObjectId objectId;

  /// Initial shared version.
  final BigInt initialSharedVersion;

  /// Whether the object is being accessed mutably.
  final bool mutable;
}

/// Transaction command.
sealed class SuiCommand {
  const SuiCommand();
}

/// Move call command.
class MoveCallCommand extends SuiCommand {
  /// Creates a MoveCallCommand.
  const MoveCallCommand({
    required this.package,
    required this.module,
    required this.function,
    this.typeArguments = const [],
    this.arguments = const [],
  });

  /// Package address.
  final SuiAddress package;

  /// Module name.
  final String module;

  /// Function name.
  final String function;

  /// Type arguments.
  final List<SuiTypeTag> typeArguments;

  /// Arguments (indices into inputs or results).
  final List<SuiArgument> arguments;
}

/// Transfer objects command.
class TransferObjectsCommand extends SuiCommand {
  /// Creates a TransferObjectsCommand.
  const TransferObjectsCommand({required this.objects, required this.address});

  /// Objects to transfer.
  final List<SuiArgument> objects;

  /// Recipient address.
  final SuiArgument address;
}

/// Split coins command.
class SplitCoinsCommand extends SuiCommand {
  /// Creates a SplitCoinsCommand.
  const SplitCoinsCommand({required this.coin, required this.amounts});

  /// Coin to split.
  final SuiArgument coin;

  /// Amounts to split off.
  final List<SuiArgument> amounts;
}

/// Merge coins command.
class MergeCoinsCommand extends SuiCommand {
  /// Creates a MergeCoinsCommand.
  const MergeCoinsCommand({required this.destination, required this.sources});

  /// Destination coin.
  final SuiArgument destination;

  /// Source coins to merge in.
  final List<SuiArgument> sources;
}

/// Publish command.
class PublishCommand extends SuiCommand {
  /// Creates a PublishCommand.
  const PublishCommand({required this.modules, required this.dependencies});

  /// Compiled Move modules (bytecode).
  final List<Uint8List> modules;

  /// Package dependencies.
  final List<SuiObjectId> dependencies;
}

/// Upgrade command.
class UpgradeCommand extends SuiCommand {
  /// Creates an UpgradeCommand.
  const UpgradeCommand({
    required this.modules,
    required this.dependencies,
    required this.package,
    required this.ticket,
  });

  /// Compiled Move modules (bytecode).
  final List<Uint8List> modules;

  /// Package dependencies.
  final List<SuiObjectId> dependencies;

  /// Package to upgrade.
  final SuiObjectId package;

  /// Upgrade ticket.
  final SuiArgument ticket;
}

/// Make Move vector command.
class MakeMoveVecCommand extends SuiCommand {
  /// Creates a MakeMoveVecCommand.
  const MakeMoveVecCommand({this.type, required this.elements});

  /// Element type (optional, can be inferred).
  final SuiTypeTag? type;

  /// Vector elements.
  final List<SuiArgument> elements;
}

/// Command argument reference.
sealed class SuiArgument {
  const SuiArgument();
}

/// Gas coin argument.
class GasCoinArg extends SuiArgument {
  /// Creates a GasCoinArg.
  const GasCoinArg();
}

/// Input argument (index into inputs).
class InputArg extends SuiArgument {
  /// Creates an InputArg.
  const InputArg(this.index);

  /// Input index.
  final int index;
}

/// Result argument (index into previous command results).
class ResultArg extends SuiArgument {
  /// Creates a ResultArg.
  const ResultArg(this.index);

  /// Command result index.
  final int index;
}

/// Nested result argument.
class NestedResultArg extends SuiArgument {
  /// Creates a NestedResultArg.
  const NestedResultArg(this.commandIndex, this.resultIndex);

  /// Command index.
  final int commandIndex;

  /// Result index within the command's results.
  final int resultIndex;
}

/// Sui transaction data.
class SuiTransactionData {
  /// Creates SuiTransactionData.
  const SuiTransactionData({
    required this.kind,
    required this.sender,
    required this.gasData,
    required this.expiration,
  });

  /// Transaction kind.
  final SuiTransactionKind kind;

  /// Sender address.
  final SuiAddress sender;

  /// Gas data.
  final SuiGasData gasData;

  /// Transaction expiration.
  final SuiTransactionExpiration expiration;
}

/// Transaction expiration.
sealed class SuiTransactionExpiration {
  const SuiTransactionExpiration();
}

/// No expiration.
class NoExpiration extends SuiTransactionExpiration {
  /// Creates a NoExpiration.
  const NoExpiration();
}

/// Expires at a specific epoch.
class EpochExpiration extends SuiTransactionExpiration {
  /// Creates an EpochExpiration.
  const EpochExpiration(this.epoch);

  /// Expiration epoch.
  final BigInt epoch;
}

/// Sui transaction (signed).
class SuiTransaction {
  /// Creates a SuiTransaction.
  const SuiTransaction({required this.data, required this.signatures});

  /// Transaction data.
  final SuiTransactionData data;

  /// Transaction signatures.
  final List<SuiSignature> signatures;

  /// Serializes the transaction for submission.
  Uint8List serialize() {
    // BCS serialization would go here
    return Uint8List(0);
  }
}

/// Sui signature.
class SuiSignature {
  /// Creates a SuiSignature.
  const SuiSignature({required this.scheme, required this.signature});

  /// Signature scheme (Ed25519, Secp256k1, Secp256r1, MultiSig).
  final SuiSignatureScheme scheme;

  /// Signature bytes (includes public key).
  final Uint8List signature;
}

/// Signature schemes supported by Sui.
enum SuiSignatureScheme {
  /// Ed25519 signature.
  ed25519(0),

  /// Secp256k1 signature.
  secp256k1(1),

  /// Secp256r1 (P-256) signature.
  secp256r1(2),

  /// Multi-signature.
  multiSig(3),

  /// ZK Login signature.
  zkLogin(5);

  const SuiSignatureScheme(this.flag);

  /// Scheme flag byte.
  final int flag;
}

/// Transaction block builder for constructing programmable transactions.
class TransactionBlockBuilder {
  /// Creates a new TransactionBlockBuilder.
  TransactionBlockBuilder();

  final List<SuiCallArg> _inputs = [];
  final List<SuiCommand> _commands = [];
  SuiAddress? _sender;
  SuiGasData? _gasData;

  /// Sets the transaction sender.
  void setSender(SuiAddress sender) {
    _sender = sender;
  }

  /// Sets the gas data.
  void setGasData(SuiGasData gasData) {
    _gasData = gasData;
  }

  /// Adds a pure value input.
  SuiArgument addPure(Uint8List value) {
    _inputs.add(PureArg(value));
    return InputArg(_inputs.length - 1);
  }

  /// Adds an object input.
  SuiArgument addObject(SuiObjectRef ref) {
    _inputs.add(ObjectArg(ref));
    return InputArg(_inputs.length - 1);
  }

  /// Adds a shared object input.
  SuiArgument addSharedObject({
    required SuiObjectId objectId,
    required BigInt initialSharedVersion,
    required bool mutable,
  }) {
    _inputs.add(
      SharedObjectArg(
        objectId: objectId,
        initialSharedVersion: initialSharedVersion,
        mutable: mutable,
      ),
    );
    return InputArg(_inputs.length - 1);
  }

  /// Adds a Move call command.
  SuiArgument moveCall({
    required SuiAddress package,
    required String module,
    required String function,
    List<SuiTypeTag> typeArguments = const [],
    List<SuiArgument> arguments = const [],
  }) {
    _commands.add(
      MoveCallCommand(
        package: package,
        module: module,
        function: function,
        typeArguments: typeArguments,
        arguments: arguments,
      ),
    );
    return ResultArg(_commands.length - 1);
  }

  /// Adds a transfer objects command.
  void transferObjects(List<SuiArgument> objects, SuiArgument address) {
    _commands.add(TransferObjectsCommand(objects: objects, address: address));
  }

  /// Adds a split coins command.
  SuiArgument splitCoins(SuiArgument coin, List<SuiArgument> amounts) {
    _commands.add(SplitCoinsCommand(coin: coin, amounts: amounts));
    return ResultArg(_commands.length - 1);
  }

  /// Adds a merge coins command.
  void mergeCoins(SuiArgument destination, List<SuiArgument> sources) {
    _commands.add(MergeCoinsCommand(destination: destination, sources: sources));
  }

  /// Gets the gas coin argument.
  SuiArgument get gas => const GasCoinArg();

  /// Builds the transaction data.
  SuiTransactionData build() {
    if (_sender == null) {
      throw StateError('Sender not set');
    }
    if (_gasData == null) {
      throw StateError('Gas data not set');
    }

    return SuiTransactionData(
      kind: ProgrammableTransaction(inputs: _inputs, commands: _commands),
      sender: _sender!,
      gasData: _gasData!,
      expiration: const NoExpiration(),
    );
  }
}
