import 'dart:io';

void main() {
  final root = Directory.current;
  final pubspecs = <File>[];

  void findPubspecs(Directory dir) {
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments
            .lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (['.git', '.dart_tool', 'build', '.gemini'].contains(name)) continue;
        findPubspecs(entity);
      } else if (entity is File && entity.path.endsWith('pubspec.yaml')) {
        pubspecs.add(entity);
      }
    }
  }

  findPubspecs(root);
  print('Checking names of ${pubspecs.length} packages...');

  for (final pubspec in pubspecs) {
    final content = pubspec.readAsStringSync();
    final nameLine = content
        .split('\n')
        .firstWhere((l) => l.startsWith('name:'), orElse: () => '');
    final name = nameLine.split(':').last.trim();

    if (!name.startsWith('web3_universal') && name != 'web3_universal') {
      print('WARNING: Package at ${pubspec.path} has name "$name"');
    }

    // Check internal deps
    final lines = content.split('\n');
    for (var line in lines) {
      if (line.trim().startsWith('path:')) {
        // Paths are relative, ensure they point to existing things?
      }
    }
  }
  print('Name check complete.');
}
