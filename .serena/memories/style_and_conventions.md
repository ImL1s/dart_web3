# Style and conventions for dart_web3

- Uses Dart with `package:lints/recommended.yaml` plus strict analyzer settings: `strict-casts`, `strict-inference`, `strict-raw-types`.
- Analyzer treats `missing_return`, `missing_required_param`, `must_be_immutable` as errors; `todo`, `deprecated_member_use` as warnings. Excludes generated files (`*.g.dart`, `*.freezed.dart`, `generated/**`, `build/**`, `.dart_tool/**`).
- Lints emphasize explicitness and safety (e.g., `always_declare_return_types`, `avoid_dynamic_calls`, `avoid_returning_null_for_future`, `avoid_positional_boolean_parameters`, etc.).
- Modular workspace: packages under `packages/` (core, client, signer, provider, chains, abi, crypto, etc.) plus meta-package `dart_web3/`.
- Code should remain type-safe, avoid dynamic/implicit casts, and follow Dart formatting (`dart format`).