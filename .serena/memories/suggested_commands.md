# Suggested commands for dart_web3

## Workspace tooling
- `melos bs` or `melos bootstrap` — install dependencies for all packages.
- `melos analyze` — static analysis across all packages (`dart analyze --fatal-infos`).
- `melos format` — check formatting (`dart format --set-exit-if-changed .`).
- `melos test` — run package tests (serial concurrency=1, only packages with `test/`).
- `melos test:coverage` — run tests with coverage (`dart test --coverage=coverage`).
- `melos publish:dry` — dry-run publish for non-private packages.
- `melos clean` — clean packages.

## Dart/Flutter basics
- `dart pub get` in a package for dependencies (usually covered by `melos bs`).
- `dart test` / `dart analyze` within a package for focused runs.

## Repo navigation (macOS/Darwin)
- Standard utilities: `ls`, `find`, `grep -R`, `sed`, `awk`, `git status/diff`.