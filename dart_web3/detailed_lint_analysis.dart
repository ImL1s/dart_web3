import 'dart:io';

void main() {
  final file = File('current_analysis.txt');
  if (!file.existsSync()) {
    print('Analysis file not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  final lintCounts = <String, List<String>>{};
  
  for (final line in lines) {
    if (!line.contains(' - ')) continue;
    
    final parts = line.split(' - ');
    if (parts.length < 2) continue;
    
    final lintName = parts.last.trim();
    if (lintName.isEmpty || lintName.contains(' ')) continue;
    
    lintCounts.putIfAbsent(lintName, () => []).add(line.trim());
  }
  
  print('=== DETAILED LINT BREAKDOWN ===\n');
  
  final sorted = lintCounts.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  
  for (final entry in sorted.take(10)) {
    print('${entry.key}: ${entry.value.length} instances');
    print('  First 3 examples:');
    for (var i = 0; i < entry.value.length && i < 3; i++) {
      print('    ${entry.value[i]}');
    }
    print('');
  }
}
