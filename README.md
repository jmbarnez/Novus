# Space Drone Adventure

A Love2D-based space exploration game built with a modern Entity Component System (ECS) architecture.

## 🚀 Quick Start

1. **Prerequisites**
   - [Love2D 11.3+](https://love2d.org/)
   - Lua 5.1+

2. **Running the Game**
   ```bash
   love .
   ```

3. **Controls**
   - `WASD` - Thrust controls
   - `ESC` - Quit game

## 📁 Project Structure

```
Space Drone Adventure/
├── main.lua              # Love2D entry point
├── conf.lua              # Love2D configuration
├── src/                  # Game source code
│   ├── core.lua          # Core game logic
│   ├── ecs.lua           # ECS implementation
│   ├── components.lua    # Component definitions
│   ├── systems.lua       # System aggregator
│   ├── constants.lua     # Game constants
│   └── systems/          # Individual ECS systems
└── docs/                 # Documentation
    ├── ARCHITECTURE.md   # System architecture
    └── DEVELOPMENT.md    # Development guidelines
```

## 🏗️ Architecture

This project uses a modern **Entity Component System (ECS)** architecture designed for scalability and maintainability:

- **Entities**: Game objects identified by unique IDs
- **Components**: Pure data structures (Position, Velocity, Physics, etc.)
- **Systems**: Logic that operates on entities with specific components

### Key Features

- ✅ **Modular Design**: Clean separation of concerns
- ✅ **Scalable ECS**: Handles hundreds of entities efficiently
- ✅ **Particle System**: Dynamic trail effects
- ✅ **Camera System**: Smooth following with canvas rendering
- ✅ **Input System**: Responsive player controls
- ✅ **Physics System**: Realistic movement and boundaries

## 📚 Documentation

- **[Architecture Overview](docs/ARCHITECTURE.md)** - Detailed system architecture and design decisions
- **[Development Guide](docs/DEVELOPMENT.md)** - Coding standards and best practices

## 🛠️ Turret Modules & Cooldown Logic

All turret cooldowns are defined exclusively in their turret module files (e.g., `src/turret_modules/basic_cannon.lua`).

- The `COOLDOWN` field in each turret module is the only source of truth for firing rate.
- Ship designs and other files should not define or override turret cooldowns.
- The game engine always queries cooldown via `TurretRange.getFireCooldown(moduleName)`.

Example turret module:
```lua
local BasicCannon = {
   name = "basic_cannon",
   COOLDOWN = 0.7,
   -- ...other fields...
}
```

## 🛠️ Development

### Core Principles

- **Logical Organization**: Group related functionality together
- **No Fallbacks**: Systems must work perfectly or fail immediately
- **Comprehensive Comments**: Document every function and design decision
- **Modular Design**: One clear responsibility per module

### Code Style

- **snake_case** for file names
- **PascalCase** for module tables
- **Descriptive names** for all identifiers
- **Explicit imports** with full paths

## 🎮 Game Features

- **Smooth Physics**: Realistic space movement with friction and speed limits
- **Dynamic Camera**: Follows player with smooth interpolation
- **Particle Trails**: Visual feedback for movement
- **UI System**: Health and speed indicators
- **Boundary System**: World constraints and collision detection

## 🔧 Configuration

Game settings are centralized in `src/constants.lua`:

- Screen dimensions (1920x1080)
- Player physics parameters
- Trail particle settings
- UI element dimensions

## 📈 Performance

The ECS architecture is designed for high performance:

- **Efficient Queries**: Indexed component types with O(n) set intersection queries (not O(nm))
- **System Ordering**: Deterministic execution order
- **Memory Management**: Automatic cleanup of destroyed entities
- **Canvas Rendering**: Off-screen rendering for smooth visuals

For detailed information on the query optimization, see [ECS Query Optimization](docs/ECS_OPTIMIZATION.md).

## 🤝 Contributing

1. Follow the development guidelines in `docs/DEVELOPMENT.md`
2. Maintain the ECS architecture principles
3. Add comprehensive comments to all new code
4. Update documentation for any architectural changes

## 📄 License

This project is open source. See individual files for specific licensing information.

---

**Built with ❤️ using Love2D and Lua**
