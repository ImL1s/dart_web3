# Repository Guidelines

## Project Structure & Module Organization
- `dart_web3/` is the monorepo root (Melos), containing `melos.yaml` and `pubspec.yaml`.
- `dart_web3/packages/` holds individual packages; each package follows `lib/` and optional `test/` and `example/`.
- `dart_web3/dart_web3/` is the meta-package that re-exports modules.
- Top-level `docs/` and `references/` contain research and upstream references; they are not required for builds.
- `conductor/` holds planning and workflow notes.

## Build, Test, and Development Commands
Run from `dart_web3/` unless noted.
- `dart pub global activate melos` installs Melos.
- `melos bootstrap` installs package dependencies and links the workspace.
- `melos analyze` runs `dart analyze` with strict lints.
- `melos format` enforces `dart format --set-exit-if-changed`.
- `melos test` runs `dart test` in packages with `test/`.
- `melos test:coverage` writes `coverage/` per package.

## Coding Style & Naming Conventions
- Follow `dart_web3/analysis_options.yaml` (lints/recommended plus stricter rules).
- Use 2-space indentation and `dart format`; single quotes and trailing commas are preferred.
- Public APIs should be type-annotated; avoid `dynamic` where possible.
- Files: `lower_snake_case.dart`; types and extensions: `UpperCamelCase`; members: `lowerCamelCase`.

## Testing Guidelines
- Framework: `package:test`.
- Place tests in `packages/<pkg>/test` and name files `*_test.dart`.
- Keep unit tests focused per module; add integration tests within the package when needed.
- CI runs a core subset; run full `melos test` locally before release.

## Commit & Pull Request Guidelines
- Use Conventional Commits as seen in history: `docs: ...`, `chore(ci): ...`, `feat(scope): ...`, `fix(scope): ...`.
- Keep commits scoped to one change; update related docs or examples when APIs change.
- PRs should describe affected packages, include test results, and link issues/trackers when available.

## Security & Configuration Tips
- Do not commit private keys, mnemonics, or real RPC credentials; use placeholders in examples.
- When adding a new package, include `pubspec.yaml`, a `lib/` entrypoint, and update relevant README links.
