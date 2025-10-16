
# Space Drone Adventure

## Project Overview

This is a 2D space exploration game built with the LÖVE framework and Lua. It uses a modern Entity Component System (ECS) architecture, which is designed for scalability and maintainability. The game features a player-controlled drone, asteroids, a parallax-scrolling starfield, and a basic UI.

## Building and Running

To run the game, you need to have LÖVE 11.3+ installed. You can then run the game from the project's root directory using the following command:

```bash
love .
```

## Development Conventions

The project follows a strict set of development conventions, which are documented in `docs/DEVELOPMENT.md`. Here are some of the key points:

*   **Code Style:**
    *   File names are in `snake_case`.
    *   Module tables are in `PascalCase`.
    *   Variable and function names are descriptive and avoid abbreviations.
*   **Architecture:**
    *   The project uses an Entity Component System (ECS) architecture.
    *   Entities are simple IDs.
    *   Components are pure data tables.
    *   Systems contain all the game logic.
*   **Error Handling:**
    *   The project follows a "fail-fast" approach. No error handling or fallback systems are implemented.
*   **Testing:**
    *   There are no automated tests. The project relies on manual testing.
*   **Documentation:**
    *   All code should be thoroughly commented.
    *   Design decisions and trade-offs should be documented.

## Key Files

*   `main.lua`: The main entry point for the LÖVE game.
*   `conf.lua`: The configuration file for LÖVE.
*   `src/core.lua`: The core game logic, including entity creation and system registration.
*   `src/ecs.lua`: The implementation of the Entity Component System.
*   `src/components.lua`: Definitions for all the components used in the game.
*   `src/systems.lua`: An aggregator for all the game's systems.
*   `src/systems/`: This directory contains the individual systems that implement the game's logic.
*   `docs/`: This directory contains documentation for the project.
