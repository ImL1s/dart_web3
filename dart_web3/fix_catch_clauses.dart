import 'dart:io';

void main() async {
  // Extract all catch clause locations
  final analysisFile = File('current_analysis.txt');
  final lines = analysisFile.readAsLinesSync();

  final catchIssues = <Map<String, String>>[];

  for (final line in lines) {
    if (line.contains('avoid_catches_without_on_clauses')) {
      // Parse: [package]: info - path:line:col - message - lint
      final match = RegExp(r'\[([^\]]+)\]:\s+info - ([^:]+):(\d+):(\d+)')
          .firstMatch(line);
      if (match != null) {
        final path = match.group(2)!.replaceAll('\\', '/');
        final lineNum = int.parse(match.group(3)!);
        catchIssues.add({
          'package': match.group(1)!,
          'path':
              'packages/${match.group(1)!.replaceAll('web3_universal_', '')}/$path',
          'line': lineNum.toString(),
        });
      }
    }
  }

  print('Found ${catchIssues.length} catch clauses to fix');

  // Group by file
  final fileGroups = <String, List<int>>{};
  for (final issue in catchIssues) {
    final path = issue['path']!;
    final line = int.parse(issue['line']!);
    fileGroups.putIfAbsent(path, () => []).add(line);
  }

  print('Across ${fileGroups.length} files\n');

  int fixedCount = 0;

  for (final entry in fileGroups.entries) {
    final filePath = entry.key;
    final lines = entry.value
      ..sort((a, b) => b.compareTo(a)); // Sort descending

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

        // Check if it's a catch without 'on'
        if (line.contains('catch') && !line.contains(' on ')) {
          // Replace 'catch (e)' with 'on Exception catch (e)'
          final fixed = line.replaceFirst(
            RegExp(r'catch\s*\('),
            'on Exception catch (',
          );

          if (fixed != line) {
            contentLines[lineNum - 1] = fixed;
            fixedCount++;
            print('✓ Fixed $filePath:$lineNum');
          }
        }
      }
    }

    // Write back
    file.writeAsStringSync(contentLines.join('\n'));
  }

  print('\n✅ Fixed $fixedCount catch clauses');
}
