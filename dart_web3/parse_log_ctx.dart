import 'dart:io';

void main() {
  final file = File('job_full_log.txt');
  final lines = file.readAsLinesSync();
  
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('exit code 128')) {
      print('--- CONTEXT FOR ERROR ---');
      for (var j = i - 10; j <= i + 10; j++) {
        if (j >= 0 && j < lines.length) {
          print(lines[j]);
        }
      }
    }
  }
}
