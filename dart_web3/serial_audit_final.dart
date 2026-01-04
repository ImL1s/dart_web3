
import 'dart:io';

void main() async {
  final root = Directory.current;
  final pubspecs = <File>[];

  void findPubspecs(Directory dir) {
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (['.git', '.dart_tool', 'build', '.gemini'].contains(name)) continue;
        findPubspecs(entity);
      } else if (entity is File && entity.path.endsWith('pubspec.yaml')) {
        pubspecs.add(entity);
      }
    }
  }

  findPubspecs(root);
  print('Auditing ${pubspecs.length} packages...');

  for (final pubspec in pubspecs) {
    final dir = pubspec.parent;
    // print('Checking ${dir.path}...');
    final result = await Process.run('dart', ['pub', 'get', '--offline'], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      if (result.stderr.toString().contains('expected name') || result.stderr.toString().contains('Could not find package')) {
        print('FAILURE in ${dir.path}:');
        print(result.stderr);
      }
    }
  }
  print('Audit complete.');
}
