// This file is intentionally simplified.
// Full mock providers require proper type definitions from the main app.
// For now, use simple provider overrides directly in test files.

/// Placeholder for mock providers.
/// 
/// To create mock providers, use Riverpod's overrideWith directly:
/// 
/// ```dart
/// ProviderScope(
///   overrides: [
///     someProvider.overrideWith((ref) => MockNotifier()),
///   ],
///   child: const App(),
/// )
/// ```
library;
