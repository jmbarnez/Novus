# Space Drone Adventure - Architecture Overview

> **Version**: 1.0  
> **Last Updated**: December 2024  
> **Maintainer**: Development Team

## Table of Contents

- [Project Structure](#project-structure)
- [ECS Architecture](#ecs-architecture)
- [Game Entities](#game-entities)
- [Data Flow](#data-flow-ecs)
- [Migration Status](#migration-status)
- [System Execution Order](#system-execution-order)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Scalability Benefits](#scalability-benefits)

## Project Structure

```
test2/
├── conf.lua              # LÖVE configuration (must stay in root)
├── main.lua              # Love2D entry point (delegates to core)
├── src/                  # All game modules
│   ├── main.lua          # Love2D entry point (duplicate for compatibility)
│   ├── core.lua          # Core game logic and initialization
│   ├── ecs.lua           # Entity Component System core
│   ├── components.lua    # Component type definitions
│   ├── systems.lua       # ECS system aggregator
│   ├── constants.lua     # Game configuration constants
│   ├── parallax.lua      # Legacy parallax (being migrated)
│   └── systems/          # Individual ECS systems
│       ├── boundary.lua  # Boundary constraint system
│       ├── camera.lua    # Camera following system
│       ├── input.lua     # Input processing system
│       ├── physics.lua   # Physics simulation system
│       ├── render.lua    # Rendering system
│       ├── trail.lua     # Particle trail system
│       └── ui.lua        # User interface system
└── docs/                 # Documentation
    ├── ARCHITECTURE.md   # This file
    └── DEVELOPMENT.md    # Development guidelines
```

## ECS Architecture

### Entity Component System (ECS)
- **Entities**: Game objects identified by unique IDs
- **Components**: Pure data structures attached to entities
- **Systems**: Logic that operates on entities with specific components

### Core ECS Modules

#### ECS Core (`ecs.lua`)
- **Entity Management**: Creation, destruction, and component attachment
- **Component Storage**: Efficient storage and retrieval by type
- **System Registry**: Registration and execution of systems
- **Query System**: Find entities with specific component combinations

#### Core Game Logic (`core.lua`)
- **Game Initialization**: Entity creation and system registration
- **State Management**: Game state coordination
- **Input Delegation**: Love2D input handling
- **System Orchestration**: ECS system execution coordination

#### Components (`components.lua`)
- **Position**: 2D coordinates in world space
- **Velocity**: Movement vector and speed
- **Acceleration**: Force application
- **Renderable**: Visual representation (shape, color, size)
- **InputControlled**: Player control mapping
- **Physics**: Mass, friction, speed limits
- **CameraTarget**: Camera following behavior
- **Boundary**: World boundary constraints
- **Canvas**: Off-screen rendering surface
- **Health**: Entity health and damage tracking
- **TrailEmitter**: Particle trail emission control
- **TrailParticle**: Individual trail particle data
- **StarField**: Parallax background starfield data
- **UI**: User interface element data
- **UITag**: UI element marker component

#### Systems (`systems/` directory)
- **InputSystem**: Processes player input → acceleration
- **PhysicsSystem**: Applies physics (velocity, position, limits)
- **BoundarySystem**: Enforces world boundaries
- **CameraSystem**: Smooth camera following
- **RenderSystem**: Handles all visual rendering
- **UISystem**: User interface rendering
- **TrailSystem**: Particle trail management and rendering

## Game Entities

### Player Entity
**Components**: Position, Velocity, Acceleration, Physics, InputControlled, Renderable, Boundary, CameraTarget, TrailEmitter, Health

### Camera Entity
**Components**: Position, Camera

### Canvas Entity
**Components**: Canvas

### StarField Entity
**Components**: StarField *(legacy parallax implementation)*

### UI Entity
**Components**: UI, UITag

## Data Flow (ECS)

```
Input Events → InputSystem → Acceleration Component
                           ↓
Acceleration → PhysicsSystem → Velocity → Position
                            ↓
Position + CameraTarget → CameraSystem → Camera Position
                                               ↓
Position + TrailEmitter → TrailSystem → Trail Particles
                                               ↓
All Components → RenderSystem → Canvas → Visual Output
```

## Migration Status

### ✅ Fully Migrated to ECS
- Player physics and movement
- Input handling
- Camera following
- UI rendering
- Particle trail system
- Canvas-based rendering

### 🔄 Partially Migrated
- Starfield background (still using legacy parallax.lua)

### ❌ Legacy (To Be Migrated)
- Detailed starfield rendering in RenderSystem
- Advanced camera features
- Complex UI elements

## System Execution Order

1. **InputSystem** - Process player input
2. **PhysicsSystem** - Apply physics simulation
3. **BoundarySystem** - Enforce world boundaries
4. **TrailSystem** - Update particle trails
5. **CameraSystem** - Update camera position
6. **RenderSystem** - Render all visual elements

## Dependencies

- **LÖVE Framework**: 2D game engine with ECS support
- **Lua 5.1+**: Scripting language with table support
- **No external libraries**: Pure LÖVE/Lua ECS implementation

## Configuration

### Love2D Configuration (`conf.lua`)
- Title and version
- Console output enabled for logging

### Game Constants (`src/constants.lua`)
- Screen dimensions (1920x1080)
- Player physics settings
- Trail particle settings
- UI element dimensions

## Scalability Benefits

- **Easy to add new entity types**: Just add components
- **Performance**: Only process entities with relevant components
- **Modularity**: Systems can be added/removed independently
- **Data-driven**: Game behavior defined by component combinations
- **Future-proof**: Designed to handle hundreds/thousands of entities
