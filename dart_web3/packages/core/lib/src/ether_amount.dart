import 'package:meta/meta.dart';
import 'units.dart';

/// Represents an amount of Ether with wei-precision.
///
/// This class provides a convenient, immutable wrapper around BigInt wei values,
/// with factory constructors for common unit conversions.
///
/// Example:
/// ```dart
/// final amount = EtherAmount.fromEther('1.5');
/// print(amount.inWei); // 1500000000000000000
/// print(amount.formatEther()); // '1.5'
/// ```
@immutable
class EtherAmount implements Comparable<EtherAmount> {
  /// The amount in wei.
  final BigInt inWei;

  const EtherAmount._(this.inWei);

  /// Creates an [EtherAmount] from a wei value.
  factory EtherAmount.inWei(BigInt wei) => EtherAmount._(wei);

  /// Creates an [EtherAmount] from an integer wei value.
  factory EtherAmount.fromInt(int wei) => EtherAmount._(BigInt.from(wei));

  /// Creates an [EtherAmount] from an ether string value.
  ///
  /// Example: `EtherAmount.fromEther('1.5')` = 1.5 ETH
  factory EtherAmount.fromEther(String ether) =>
      EtherAmount._(EthUnit.ether(ether));

  /// Creates an [EtherAmount] from a gwei string value.
  ///
  /// Example: `EtherAmount.fromGwei('20')` = 20 gwei
  factory EtherAmount.fromGwei(String gwei) =>
      EtherAmount._(EthUnit.gwei(gwei));

  /// Zero ether.
  static EtherAmount zero() => EtherAmount._(BigInt.zero);

  /// Gets the value in wei as a BigInt.
  BigInt getInWei() => inWei;

  /// Gets the value in gwei as a BigInt (truncated).
  BigInt getInGwei() => inWei ~/ EthUnit.weiPerGwei;

  /// Gets the value in ether as a BigInt (truncated).
  BigInt getInEther() => inWei ~/ EthUnit.weiPerEther;

  /// Formats the amount as an ether string.
  String formatEther() => EthUnit.formatEther(inWei);

  /// Formats the amount as a gwei string.
  String formatGwei() => EthUnit.formatGwei(inWei);

  /// Formats the amount as a wei string.
  String formatWei() => EthUnit.formatWei(inWei);

  /// Returns a new [EtherAmount] with the sum of this and [other].
  EtherAmount operator +(EtherAmount other) =>
      EtherAmount._(inWei + other.inWei);

  /// Returns a new [EtherAmount] with the difference of this and [other].
  EtherAmount operator -(EtherAmount other) =>
      EtherAmount._(inWei - other.inWei);

  /// Returns a new [EtherAmount] multiplied by [multiplier].
  EtherAmount operator *(int multiplier) =>
      EtherAmount._(inWei * BigInt.from(multiplier));

  /// Returns a new [EtherAmount] divided by [divisor] (truncated).
  EtherAmount operator ~/(int divisor) =>
      EtherAmount._(inWei ~/ BigInt.from(divisor));

  /// Returns true if this amount is greater than [other].
  bool operator >(EtherAmount other) => inWei > other.inWei;

  /// Returns true if this amount is less than [other].
  bool operator <(EtherAmount other) => inWei < other.inWei;

  /// Returns true if this amount is greater than or equal to [other].
  bool operator >=(EtherAmount other) => inWei >= other.inWei;

  /// Returns true if this amount is less than or equal to [other].
  bool operator <=(EtherAmount other) => inWei <= other.inWei;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EtherAmount && inWei == other.inWei;

  @override
  int get hashCode => inWei.hashCode;

  @override
  int compareTo(EtherAmount other) => inWei.compareTo(other.inWei);

  @override
  String toString() => 'EtherAmount(${formatEther()} ETH)';
}
