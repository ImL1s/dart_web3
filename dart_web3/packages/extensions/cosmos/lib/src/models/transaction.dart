import 'dart:typed_data';

import '../encoding/protobuf.dart';

/// Represents a Cosmos Transaction (wrapper).
class CosmosTx {
  // Only supporting direct signing for now for simplicity of this verification
  CosmosTx({
    required this.body,
    required this.authInfo,
    this.signatures = const [],
  });

  final TxBody body;
  final AuthInfo authInfo;
  final List<Uint8List> signatures;

  Uint8List serialize() {
    final pb = ProtobufBuilder();
    pb.addMessage(1, body.toProto());
    pb.addMessage(2, authInfo.toProto());
    for (final sig in signatures) {
      pb.addBytes(3, sig);
    }
    return pb.toBytes();
  }
}

class TxBody {
  TxBody({
    required this.messages,
    this.memo = '',
    this.timeoutHeight = 0,
  });

  final List<GoogleAny> messages;
  final String memo;
  final int timeoutHeight; // 0 means disabled

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    for (final msg in messages) {
      pb.addMessage(1, msg.toProto());
    }
    pb.addString(2, memo);
    pb.addInt64(3, timeoutHeight);
    return pb;
  }

  Uint8List toBytes() => toProto().toBytes();
}

class GoogleAny {
  GoogleAny({required this.typeUrl, required this.value});

  final String typeUrl;
  final Uint8List value;

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    pb.addString(1, typeUrl);
    pb.addBytes(2, value);
    return pb;
  }
}

class AuthInfo {
  AuthInfo({
    required this.signerInfos,
    required this.fee,
  });

  final List<SignerInfo> signerInfos;
  final Fee fee;

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    for (final info in signerInfos) {
      pb.addMessage(1, info.toProto());
    }
    pb.addMessage(2, fee.toProto());
    return pb;
  }

  Uint8List toBytes() => toProto().toBytes();
}

class SignerInfo {
  // Scaffold
  SignerInfo({
    required this.publicKey,
    required this.modeInfo,
    required this.sequence,
  });

  final GoogleAny publicKey; // Any
  final ModeInfo modeInfo;
  final int sequence;

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    pb.addMessage(1, publicKey.toProto());
    pb.addMessage(2, modeInfo.toProto());
    pb.addInt64(3, sequence);
    return pb;
  }
}

class ModeInfo {
  ModeInfo.single(int mode) : singleMode = mode;

  final int singleMode;

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    // Single is a submessage field 1
    final singlePb = ProtobufBuilder();
    singlePb.addInt64(1, singleMode);

    pb.addMessage(1, singlePb);
    return pb;
  }
}

class Fee {
  Fee({required this.amount, required this.gasLimit});

  final List<Coin> amount;
  final int gasLimit;

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    for (final coin in amount) {
      pb.addMessage(1, coin.toProto());
    }
    pb.addInt64(2, gasLimit);
    return pb;
  }
}

class Coin {
  Coin({required this.denom, required this.amount});
  final String denom;
  final String amount; // Int as string

  ProtobufBuilder toProto() {
    final pb = ProtobufBuilder();
    pb.addString(1, denom);
    pb.addString(2, amount);
    return pb;
  }
}

/// Helper for standard messages
class MsgSend {
  MsgSend({
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
  });

  final String fromAddress;
  final String toAddress;
  final List<Coin> amount;

  static const typeUrl = '/cosmos.bank.v1beta1.MsgSend';

  GoogleAny toAny() {
    final pb = ProtobufBuilder();
    pb.addString(1, fromAddress);
    pb.addString(2, toAddress);
    for (final coin in amount) {
      pb.addMessage(3, coin.toProto());
    }
    return GoogleAny(typeUrl: typeUrl, value: pb.toBytes());
  }
}

/// SignDoc (what gets signed)
class SignDoc {
  SignDoc({
    required this.bodyBytes,
    required this.authInfoBytes,
    required this.chainId,
    required this.accountNumber,
  });

  final Uint8List bodyBytes;
  final Uint8List authInfoBytes;
  final String chainId;
  final int accountNumber;

  Uint8List serialize() {
    final pb = ProtobufBuilder();
    pb.addBytes(1, bodyBytes);
    pb.addBytes(2, authInfoBytes);
    pb.addString(3, chainId);
    pb.addInt64(4, accountNumber);
    return pb.toBytes();
  }
}
