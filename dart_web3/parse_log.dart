import 'dart:io';

void main() {
  final file = File('job_full_log.txt');
  if (!file.existsSync()) {
    print('Log file not found');
    return;
  }

  final lines = file.readAsLinesSync();
  bool foundIssue = false;

  print('--- LOG ANALYSIS START ---');
  for (final line in lines) {
    if (line.contains(' [error] ') ||
        line.contains('error -') ||
        line.contains('warning -') ||
        line.contains('Try sort') ||
        line.contains('FAILED') ||
        line.contains('failed')) {
      print(line);
      foundIssue = true;
    }
  }

  if (!foundIssue) {
    // If no specific error key found, print the last 50 lines
    print('--- NO OBVIOUS ERRORS FOUND, PRINTING TAIL ---');
    for (var i = lines.length - 50; i < lines.length; i++) {
      if (i >= 0) print(lines[i]);
    }
  }
  print('--- LOG ANALYSIS END ---');
}
