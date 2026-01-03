
import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final root = Directory.current;
  final pubspecs = <String, String>{};
  final dependencies = <String, Map<String, String>>{};

  // 1. Find all pubspec.yaml and their package names
  root.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('pubspec.yaml')) {
      final path = entity.path;
      if (path.contains('.git') || path.contains('.dart_tool') || path.contains('build')) return;
      
      try {
        final content = entity.readAsStringSync();
        final yaml = loadYaml(content);
        final name = yaml['name'] as String?;
        if (name != null) {
          // Normalize path for Windows
          final dirPath = entity.parent.absolute.path.replaceAll('\\', '/').toLowerCase();
          pubspecs[dirPath] = name;
          
          final deps = <String, String>{};
          void addDeps(Map? d) {
            if (d == null) return;
            d.forEach((k, v) {
              if (v is Map && v.containsKey('path')) {
                deps[k] = v['path'];
              } else if (v is YamlMap && v.containsKey('path')) {
                deps[k] = v['path'];
              }
            });
          }
          
          addDeps(yaml['dependencies'] as Map?);
          addDeps(yaml['dev_dependencies'] as Map?);
          if (deps.isNotEmpty) {
            dependencies[entity.path] = deps;
          }
        }
      } catch (e) {
        // Skip malformed yaml or other errors
      }
    }
  });

  print('Found ${pubspecs.length} packages.');

  // 2. Check dependencies
  var foundError = false;
  dependencies.forEach((file, deps) {
    final parentDir = Directory(file).parent.absolute;
    deps.forEach((depName, relPath) {
      // Very simple path joining for this monorepo structure
      final targetDir = Directory.fromUri(parentDir.uri.resolve(relPath)).absolute;
      final targetPath = targetDir.path.replaceAll('\\', '/').toLowerCase();
      
      final actualName = pubspecs[targetPath];
      
      if (actualName != null && actualName != depName) {
        print('MISMATCH in $file:');
        print('  Dependency "$depName" points to "$relPath"');
        print('  But the package at "$relPath" is actually named "$actualName"');
        foundError = true;
      }
    });
  });

  if (!foundError) {
    print('No mismatches found!');
  }
}
