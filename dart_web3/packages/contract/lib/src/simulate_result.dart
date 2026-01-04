/// Result of a contract function simulation.
class SimulateResult {
  SimulateResult({
    required this.result,
    required this.gasUsed,
    required this.success,
    this.revertReason,
  });

  /// The decoded return values.
  final List<dynamic> result;

  /// The estimated gas used.
  final BigInt gasUsed;

  /// Whether the simulation succeeded.
  final bool success;

  /// The revert reason if the simulation failed.
  final String? revertReason;

  @override
  String toString() {
    if (success) {
      return 'SimulateResult(success: true, result: $result, gasUsed: $gasUsed)';
    } else {
      return 'SimulateResult(success: false, revertReason: $revertReason)';
    }
  }
}
