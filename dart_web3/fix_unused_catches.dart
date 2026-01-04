import 'dart:io';

void main() async {
  // Extract all unused_catch_clause issues
  final analysisFile = File('verify_catch_fixes.txt');
  final lines = analysisFile.readAsLinesSync();

  final unusedCatchIssues = <Map<String, String>>[];

  for (final line in lines) {
    if (line.contains('unused_catch_clause')) {
      final match = RegExp(r'\[([^\]]+)\]:\s+warning - ([^:]+):(\d+):(\d+)')
          .firstMatch(line);
      if (match != null) {
        final path = match.group(2)!.replaceAll('\\', '/');
        final lineNum = int.parse(match.group(3)!);
        unusedCatchIssues.add({
          'package': match.group(1)!,
          'path':
              'packages/${match.group(1)!.replaceAll('web3_universal_', '')}/$path',
          'line': lineNum.toString(),
        });
      }
    }
  }

  print('Found ${unusedCatchIssues.length} unused catch clauses');

  // Group by file
  final fileGroups = <String, List<int>>{};
  for (final issue in unusedCatchIssues) {
    final path = issue['path']!;
    final line = int.parse(issue['line']!);
    fileGroups.putIfAbsent(path, () => []).add(line);
  }

  print('Across ${fileGroups.length} files\n');

  int fixedCount = 0;

  for (final entry in fileGroups.entries) {
    final filePath = entry.key;
    final lines = entry.value..sort((a, b) => b.compareTo(a));

    final file = File(filePath);
    if (!file.existsSync()) {
      print('⚠️  File not found: $filePath');
      continue;
    }

    var content = file.readAsStringSync();
    final contentLines = content.split('\n');

    for (final lineNum in lines) {
      if (lineNum > 0 && lineNum <= contentLines.length) {
        final line = contentLines[lineNum - 1];

        // Replace catch (e) or catch (error) with catch (_)
        final fixed = line.replaceAllMapped(
          RegExp(r'catch\s*\(\s*\w+\s*\)'),
          (match) => 'catch (_)',
        );

        if (fixed != line) {
          contentLines[lineNum - 1] = fixed;
          fixedCount++;
          print('✓ Fixed $filePath:$lineNum');
        }
      }
    }

    file.writeAsStringSync(contentLines.join('\n'));
  }

  print('\n✅ Fixed $fixedCount unused catch clauses');
}
