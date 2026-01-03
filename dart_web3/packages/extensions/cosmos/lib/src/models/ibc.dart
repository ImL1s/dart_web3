
import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import '../encoding/protobuf.dart';
import 'transaction.dart'; // for Coin, GoogleAny

/// IBC Transfer Message
class MsgTransfer {
  MsgTransfer({
    required this.sourcePort,
    required this.sourceChannel,
    required this.token,
    required this.sender,
    required this.receiver,
    required this.timeoutHeight,
    required this.timeoutTimestamp,
  });

  final String sourcePort;
  final String sourceChannel;
  final Coin token;
  final String sender;
  final String receiver;
  final Height timeoutHeight;
  final BigInt timeoutTimestamp;

  static const typeUrl = '/ibc.applications.transfer.v1.MsgTransfer';

  GoogleAny toAny() {
    final pb = ProtobufBuilder();
    pb.addString(1, sourcePort);
    pb.addString(2, sourceChannel);
    pb.addMessage(3, token.toProto());
    pb.addString(4, sender);
    pb.addString(5, receiver);
    pb.addMessage(6, timeoutHeight.toProto());
    pb.addUint64(7, timeoutTimestamp);
    
    return GoogleAny(typeUrl: typeUrl, value: pb.toBytes());
  }
}

class Height {
  Height({required this.revisionNumber, required this.revisionHeight});
  final BigInt revisionNumber;
  final BigInt revisionHeight;
  
  ProtobufBuilder toProto() {
      final pb = ProtobufBuilder();
      pb.addUint64(1, revisionNumber);
      pb.addUint64(2, revisionHeight);
      return pb;
  }
}
