# AI System Documentation

## Overview

The AI system has been completely refactored into a **clean, modular, behavior-based architecture** with **zero legacy patterns**.

## Quick Navigation

### For Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Add a behavior in 5 minutes
- **[Architecture Guide](ARCHITECTURE.md)** - Understand how the system works
- **[Behavior Patterns](PATTERNS.md)** - Common behavior examples

### For Understanding Details
- **[Complete Refactoring](REFACTORING_COMPLETE.md)** - What changed and why
- **[Clean Design](CLEAN_ARCHITECTURE.md)** - Benefits of unified architecture

---

## What Is the AI System?

The AI system controls all enemy entities in the game:
- **Combat AI** - Patrol, chase, and orbit the player
- **Mining AI** - Mine asteroids autonomously
- **Behavior-based** - Easy to add new behaviors
- **Registry pattern** - Clean, extensible design

## Key Components

### Single AI Component
```lua
{
    type = "combat" | "mining",
    state = "patrol" | "chase" | "orbit",
    detectionRadius = 1200,
    patrolPoints = {...},
}
```

### Three Built-in Behaviors
1. **Patrol** - Wander or follow waypoints
2. **Chase** - Pursue player to get in range
3. **Orbit** - Maintain distance while attacking

### Unified AISystem
- Detects player
- Updates AI state
- Dispatches to appropriate behavior
- Handles both combat and mining AI

---

## Common Tasks

### Adding a New Behavior
See **[Quick Start Guide](QUICK_START.md)** for step-by-step instructions.

### Understanding How AI Works
See **[Architecture Guide](ARCHITECTURE.md)** for detailed explanation.

### Seeing Examples
See **[Behavior Patterns](PATTERNS.md)** for code examples.

### Learning About Changes
See **[Complete Refactoring](REFACTORING_COMPLETE.md)** for what was refactored.

---

## Files in This Directory

- `README.md` - This file
- `QUICK_START.md` - Fast guide to adding behaviors
- `ARCHITECTURE.md` - System architecture explanation
- `PATTERNS.md` - Common behavior implementation patterns
- `REFACTORING_COMPLETE.md` - Summary of all changes
- `CLEAN_ARCHITECTURE.md` - Benefits of the unified design

---

## System Files

```
src/
├── components/ai.lua           # Unified AI component
├── systems/
│   ├── ai.lua                  # Main AI system
│   ├── ai_behaviors.lua        # Behavior implementations
│   └── ai_turret_helper.lua    # Turret utilities
└── systems/enemy_mining.lua    # Mining-specific logic
```

---

## Quick Facts

✅ **Single unified component** - All AI state in one place  
✅ **One system** - No arbiter complexity  
✅ **Behavior registry** - Easy to extend  
✅ **Zero legacy patterns** - Clean architecture  
✅ **Fully backward compatible** - No breaking changes  

---

## State Flow

```
No Player Detected
        ↓
    PATROL
        ↓
   Player Detected
        ↓
   Is close enough?
     ↙        ↘
   YES        NO
    ↓          ↓
  ORBIT     CHASE
    ↓          ↓
  Fire        Move closer
  & orbit      & aim
```

---

## Getting Help

| Question | Answer |
|----------|--------|
| How do I add a behavior? | See [Quick Start Guide](QUICK_START.md) |
| How does the system work? | See [Architecture Guide](ARCHITECTURE.md) |
| Can you show me examples? | See [Behavior Patterns](PATTERNS.md) |
| What changed from before? | See [Complete Refactoring](REFACTORING_COMPLETE.md) |
| Why is this better? | See [Clean Architecture](CLEAN_ARCHITECTURE.md) |

---

**The AI system is production-ready and easy to extend!** 🚀
