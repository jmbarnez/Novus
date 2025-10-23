<!--
Guidance for AI coding agents working on the Space Drone Adventure codebase.
Keep this short and actionable. Prefer small, self-contained changes and follow
the project's explicit conventions described below.
-->

# Copilot instructions — Space Drone Adventure

Quick, focused guidance so an AI assistant can be immediately productive.

- Project type: Love2D game (Lua 5.1+) using a custom Entity-Component-System (ECS).
- Entry points: `main.lua` and `conf.lua` at repo root; most game logic in `src/`.

Key architecture notes
- ECS is central: `src/ecs.lua` manages entities, components, and queries. Systems live in `src/systems/` and operate on entities by component sets.
- Systems are ordered; follow the documented execution order in `docs/ARCHITECTURE.md` (Input → Physics → Boundary → Trail → Camera → Render).
- Rendering uses an offscreen Canvas entity (`Canvas` component). See `src/systems/render/canvas.lua` for drawing, scaling, and optional cel-shader post-processing.

Development & run workflow
- Run locally with Love2D: from repo root run `love .` (or use `RUN.bat` / `BUILD.bat` on Windows).
- Packaging: `BUILD.bat` creates a .zip/.love using `Compress-Archive` or 7zip.

Project-specific conventions (follow exactly)
- Filenames: snake_case. Module tables: PascalCase.
- Requires: always use explicit paths, e.g. `require('src.ecs')` or `require('src.systems.camera')`.
- No automated tests: the repository intentionally uses manual testing (run the game). Do not add test frameworks unless explicitly requested.
- Logging: limited—use sparing `print()` calls only for initialization confirmations. Do not add verbose logging.
- Error handling: codebase prefers failing loudly over silent fallbacks. Avoid adding silent guards that hide errors.

Patterns & examples to mimic
- Turret cooldowns live in turret module files (`src/items/*.lua`) and are the single source of truth (see README example: `COOLDOWN` field).
- Camera and canvas transforms: `src/scaling.lua` and `src/systems/render/canvas.lua` set canvas offsets and scale; update both when changing coordinate math.
- AI: see `docs/ai/README.md` and `src/systems/ai.lua` for the unified behavior registry pattern — add new behaviors by registering into the behavior table.

Integration points & gotchas
- Global state: some singletons and debug flags live in `_G` (e.g., `_G.postProcessCanvas`). If you change global behavior, search for `_G.` usages.
- Shader toggles: `src/shader_manager.lua` controls cel-shader enablement. When changing shader inputs, update `setScreenSize` and uniform usage accordingly.
- Conf.lua must remain at repo root for Love2D to detect config values.

If you edit systems
- Keep changes small and isolated. Update `docs/ARCHITECTURE.md` or `docs/DEVELOPMENT.md` only for substantial architectural changes.
- Preserve execution order and component-based query semantics. Use `ECS.getEntitiesWith({...})` and `ECS.getComponent(id, name)` consistently.

When in doubt
- Run the game to validate behavior (`love .` or `RUN.bat`) and test the change manually.
- Prefer minimal diffs: change one system or module at a time and verify visually.

Files to reference quickly
- `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`, `docs/ai/README.md`
- `src/ecs.lua`, `src/scaling.lua`, `src/shader_manager.lua`, `src/systems/render/canvas.lua`

End of guidance — ask for clarification when a change touches multiple systems or cross-cutting concerns.
