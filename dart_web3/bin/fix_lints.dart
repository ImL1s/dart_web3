import 'dart:io';

void main() async {
  final dir = Directory('packages');
  if (!dir.existsSync()) {
    print('Packages directory not found');
    return;
  }

  int fixedLibraryNames = 0;
  int fixedCatches = 0;

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      var newContent = content;

      // 1. Fix unnecessary_library_name
      // library web3_universal_xxx; -> library;
      final libraryRegex = RegExp(r'^library web3_universal_\w+;', multiLine: true);
      if (libraryRegex.hasMatch(newContent)) {
        newContent = newContent.replaceAll(libraryRegex, 'library;');
        fixedLibraryNames++;
      }

      // 2. Fix avoid_catches_without_on_clauses (Partial fix for common patterns)
      // Only fix simple 'catch (e)' and 'catch (error)' with 'on Object catch'
      // Or just 'catch (e)' to 'catch (e)' is OK if it's on Object.
      // Actually, the lint wants 'on Exception' or 'on Object'.
      // For now, let's focus on library names and directives as they are safer.
      
      if (newContent != content) {
        await entity.writeAsString(newContent);
        print('Fixed ${entity.path}');
      }
    }
  }

  print('Summary:');
  print('Fixed $fixedLibraryNames library names');
}
