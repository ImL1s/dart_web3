# Task completion checklist for dart_web3

1) Ensure dependencies set up (`melos bootstrap` if needed).
2) Run static analysis: `melos analyze`.
3) Run formatter check or format: `melos format` (or `dart format .`).
4) Run tests: `melos test` (serial across packages; limit to packages with `test/`). For coverage, use `melos test:coverage`.
5) Before publishing, optional `melos publish:dry`. 
6) Clean workspace if needed: `melos clean`.

Confirm git status is clean and diff reviewed before completing tasks.