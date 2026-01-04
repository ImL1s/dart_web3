import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Please provide a file name');
    return;
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    print('Analysis file not found: ${args[0]}');
    return;
  }

  final lines = await file.readAsLines();
  final lintCounts = <String, int>{};
  final severityCounts = <String, int>{};

  for (final line in lines) {
    if (!line.contains(' - ')) continue;

    final parts = line.split(' - ');
    if (parts.length < 2) continue;

    final lintName = parts.last.trim();
    if (lintName.isEmpty || lintName.contains(' ')) continue;

    lintCounts[lintName] = (lintCounts[lintName] ?? 0) + 1;

    if (line.contains('info - '))
      severityCounts['info'] = (severityCounts['info'] ?? 0) + 1;
    else if (line.contains('warning - '))
      severityCounts['warning'] = (severityCounts['warning'] ?? 0) + 1;
    else if (line.contains('error - '))
      severityCounts['error'] = (severityCounts['error'] ?? 0) + 1;
  }

  print('\nSummary for ${args[0]}:');
  print('Severity Summary:');
  severityCounts.forEach((k, v) => print('$k: $v'));

  print('\nTop 20 Lint Issues:');
  final sortedLints = lintCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (var i = 0; i < sortedLints.length && i < 20; i++) {
    print(
        '${sortedLints[i].value.toString().padLeft(6)} ${sortedLints[i].key}');
  }
}
