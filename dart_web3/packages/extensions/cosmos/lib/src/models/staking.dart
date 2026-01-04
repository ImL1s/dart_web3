import '../encoding/protobuf.dart';
import 'transaction.dart'; // for Coin, GoogleAny

/// MsgDelegate
class MsgDelegate {
  MsgDelegate({
    required this.delegatorAddress,
    required this.validatorAddress,
    required this.amount,
  });

  final String delegatorAddress;
  final String validatorAddress;
  final Coin amount;

  static const typeUrl = '/cosmos.staking.v1beta1.MsgDelegate';

  GoogleAny toAny() {
    final pb = ProtobufBuilder();
    pb.addString(1, delegatorAddress);
    pb.addString(2, validatorAddress);
    pb.addMessage(3, amount.toProto());
    return GoogleAny(typeUrl: typeUrl, value: pb.toBytes());
  }
}

/// MsgUndelegate
class MsgUndelegate {
  MsgUndelegate({
    required this.delegatorAddress,
    required this.validatorAddress,
    required this.amount,
  });

  final String delegatorAddress;
  final String validatorAddress;
  final Coin amount;

  static const typeUrl = '/cosmos.staking.v1beta1.MsgUndelegate';

  GoogleAny toAny() {
    final pb = ProtobufBuilder();
    pb.addString(1, delegatorAddress);
    pb.addString(2, validatorAddress);
    pb.addMessage(3, amount.toProto());
    return GoogleAny(typeUrl: typeUrl, value: pb.toBytes());
  }
}
