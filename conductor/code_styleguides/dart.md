# Dart Code Style Guide

## General Principles
- **Formatting**: Always use `dart format` for code formatting.
  - Line length: 80 characters.
  - Indentation: 2 spaces.
  - Braces: Use K&R style for brace placement.
  - Flow Control: Use curly braces for all flow control statements (e.g., `if`, `else`, `for`, `while`).

## Naming Conventions
- **Types**: Use `UpperCamelCase` for:
  - Classes (e.g., `HttpClient`)
  - Enums (e.g., `ConnectionStatus`)
  - Typedefs (e.g., `Predicate<T>`)
  - Extensions (e.g., `StringMethods`)
- **Members**: Use `lowerCamelCase` for:
  - Variables (e.g., `itemCount`)
  - Functions (e.g., `fetchData`)
  - Parameters (e.g., `userId`)
  - Constants (e.g., `defaultTimeout`)
- **Files & Libraries**: Use `lowercase_with_underscores` for:
  - Source files (e.g., `http_client.dart`)
  - Directories (e.g., `lib/src/utils/`)
  - Library names (e.g., `my_package.utils`)
  - Import prefixes (e.g., `import 'package:lib/lib.dart' as my_lib;`)
- **Privacy**: Use a leading underscore (`_`) to mark members as private to the library.

## Ordering
- **Imports**:
  1. `dart:` imports (e.g., `import 'dart:async';`)
  2. `package:` imports (e.g., `import 'package:http/http.dart';`)
  3. Relative imports (e.g., `import 'src/utils.dart';`)
- **Exports**: Place exports in a separate section after all imports.
- **Sorting**: Sort sections alphabetically.

## Best Practices
- **Variables**:
  - Prefer `final` for variables that don't change.
  - Prefer `const` for compile-time constants.
  - Avoid global variables.
- **Types**:
  - Avoid `dynamic` unless absolutely necessary.
  - Use `var` only when the type is obvious or not important.
- **Collections**:
  - Use literal syntax for initialization (e.g., `[]`, `{}`, `<String>{}`).
  - Use collection if/for instead of methods like `addAll`.
- **Booleans**:
  - Avoid comparing to `true` or `false` (e.g., use `if (isEmpty)` instead of `if (isEmpty == true)`).
- **Strings**:
  - Use adjacent strings for multi-line literals instead of `+`.
  - Use interpolation (`'$variable'`) instead of concatenation.

## Comments
- Use `///` for documentation comments (doc comments).
- Use `//` for implementation comments.
- Start doc comments with a single-sentence summary.
