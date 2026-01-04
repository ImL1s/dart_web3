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
  
  print('--- ERRORS ---');
  for (final line in lines) {
    if (line.contains('error - ')) {
      print(line.trim());
    }
  }

  print('\n--- WARNINGS ---');
  for (final line in lines) {
    if (line.contains('warning - ')) {
      print(line.trim());
    }
  }

  print('\n--- UNNECESSARY LIBRARY NAMES ---');
  for (final line in lines) {
    if (line.contains('unnecessary_library_name')) {
      print(line.trim());
    }
  }
}
