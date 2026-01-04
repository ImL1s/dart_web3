import 'dart:io';

void main() {
  final file = File('current_analysis.txt');
  if (!file.existsSync()) {
    print('Analysis file not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  final catches = <String>[];
  
  for (final line in lines) {
    if (line.contains('avoid_catches_without_on_clauses')) {
      catches.add(line.trim());
    }
  }
  
  print('Total avoid_catches_without_on_clauses: ${catches.length}');
  print('\n--- All instances ---');
  for (final catch_ in catches) {
    print(catch_);
  }
}
