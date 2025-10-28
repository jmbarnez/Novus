# Contributing

Thanks for wanting to contribute! This file contains the minimal, practical guidance to keep contributions useful and small.

## Tests

- This repository contains a `tests/` folder with small Lua-based tests (e.g. `tests/ecs_core_test.lua`). Tests are plain Lua files that can be executed directly with the system `lua` interpreter.

- Run tests from the repository root so module paths resolve correctly (the runner adds `./src/` to `package.path`).


- Quick ways to run the tests on Windows:
  - Run the bundled batch wrapper: `RUN_TESTS.bat` (requires `lua` on PATH).
  - Or run the Lua runner directly:

```powershell
lua tests\run_tests.lua
```

- On Unix-like systems run:

```bash
lua tests/run_tests.lua
```

- Please add fast, deterministic unit tests for changes that affect core logic (ECS, entity pools, deterministic algorithms). Keep integration tests minimal and document manual steps for visual checks.

## Documentation

- Update docs when you change public behavior, APIs, or project structure. Small doc updates can be included in the same PR as code changes.
- Keep docs high-level and avoid absolute rules unless they are enforced by CI or policies. Prefer short rationale and examples.

## Pull request checklist

- Include a short description of the change and the motivation.
- Add or update tests for behavior changes where practical.
- Update documentation for public-facing changes or repo structure changes.
- Run quick smoke checks: run the game, run unit tests under `tests/` when possible, and ensure no obvious errors.

## Style and linters

- Use existing project conventions (snake_case file names, PascalCase module tables). If you add a new convention or tool, document it in `CONTRIBUTING.md` or a follow-up doc.

If you need help running tests or setting up tooling, open an issue and we'll add a short guide.

Thank you — small, focused PRs get reviewed faster.
