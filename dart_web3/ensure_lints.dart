import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final rootDir = Directory.current;
  final packagesDir = Directory(p.join(rootDir.path, 'packages'));

  if (!packagesDir.existsSync()) {
    print('Packages directory not found: ${packagesDir.path}');
    return;
  }

  packagesDir.listSync(recursive: true).forEach((entity) {
    if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
      _checkAndFixPubspec(entity);
    }
  });

  // Also check root (already done manually but good to check)
  // _checkAndFixPubspec(File(p.join(rootDir.path, 'pubspec.yaml')));
}

void _checkAndFixPubspec(File pubspecFile) {
  final content = pubspecFile.readAsStringSync();
  
  if (content.contains('lints:')) {
    print('OK: ${pubspecFile.path} (has lints)');
    return;
  }

  print('MISSING lints: ${pubspecFile.path}');
  
  // Add lints to dev_dependencies
  if (content.contains('dev_dependencies:')) {
    final newContent = content.replaceFirst(
      'dev_dependencies:',
      'dev_dependencies:\n  lints: ^5.0.0',
    );
    pubspecFile.writeAsStringSync(newContent);
    print('  Added lints to dev_dependencies.');
  } else {
    // Add dev_dependencies section
    final newContent = '$content\n\ndev_dependencies:\n  lints: ^5.0.0\n';
    pubspecFile.writeAsStringSync(newContent);
    print('  Added dev_dependencies and lints.');
  }
}
