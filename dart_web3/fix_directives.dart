import 'dart:io';

void main() async {
  // Extract all directives_ordering issues
  final analysisFile = File('verify_catch_fixes.txt');
  final lines = analysisFile.readAsLinesSync();
  
  final directiveIssues = <Map<String, dynamic>>{};
  
  for (final line in lines) {
    if (line.contains('directives_ordering')) {
      final match = RegExp(r'\[([^\]]+)\]:\s+info - ([^:]+):(\d+):(\d+)').firstMatch(line);
      if (match != null) {
        final path = match.group(2)!.replaceAll('\\', '/');
        final lineNum = int.parse(match.group(3)!);
        final fullPath = 'packages/${match.group(1)!.replaceAll('web3_universal_', '')}/$path';
        
        directiveIssues.putIfAbsent(fullPath, () => <int>[]).add(lineNum);
      }
    }
  }
  
  print('Found ${directiveIssues.values.fold(0, (sum, list) => sum + list.length)} directives_ordering issues');
  print('Across ${directiveIssues.length} files\n');
  
  // Fix each file
  int fixedFiles = 0;
  
  for (final entry in directiveIssues.entries) {
    final filePath = entry.key;
    final file = File(filePath);
    
    if (!file.existsSync()) {
      print('⚠️  File not found: $filePath');
      continue;
    }
    
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    
    // Find import/export section
    final imports = <String>[];
    final exports = <String>[];
    int firstImportLine = -1;
    int lastDirectiveLine = -1;
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('import ')) {
        if (firstImportLine == -1) firstImportLine = i;
        imports.add(lines[i]);
        lastDirectiveLine = i;
      } else if (line.startsWith('export ')) {
        exports.add(lines[i]);
        lastDirectiveLine = i;
      } else if (firstImportLine != -1 && line.isNotEmpty && !line.startsWith('//')) {
        break;
      }
    }
    
    if (imports.isEmpty && exports.isEmpty) continue;
    
    // Sort imports: dart: first, then package:, then relative
    final dartImports = imports.where((i) => i.contains("'dart:") || i.contains('"dart:')).toList()..sort();
    final packageImports = imports.where((i) => i.contains("'package:") || i.contains('"package:')).toList()..sort();
    final relativeImports = imports.where((i) => !dartImports.contains(i) && !packageImports.contains(i)).toList()..sort();
    
    final sortedImports = [...dartImports, if (dartImports.isNotEmpty && packageImports.isNotEmpty) '', ...packageImports, if (packageImports.isNotEmpty && relativeImports.isNotEmpty) '', ...relativeImports];
    final sortedExports = exports..sort();
    
    // Replace in content
    final newLines = <String>[];
    newLines.addAll(lines.sublist(0, firstImportLine));
    newLines.addAll(sortedImports);
    if (sortedExports.isNotEmpty) {
      if (sortedImports.isNotEmpty) newLines.add('');
      newLines.addAll(sortedExports);
    }
    newLines.addAll(lines.sublist(lastDirectiveLine + 1));
    
    file.writeAsStringSync(newLines.join('\n'));
    fixedFiles++;
    print('✓ Fixed $filePath');
  }
  
  print('\n✅ Fixed $fixedFiles files');
}
