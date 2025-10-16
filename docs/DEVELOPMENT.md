# Space Drone Adventure - Development Guide

> **Version**: 1.0  
> **Last Updated**: December 2024  
> **Maintainer**: Development Team

## Table of Contents

- [Core Principles](#core-principles)
- [Organization Guidelines](#organization-guidelines)
- [Code Organization Patterns](#code-organization-patterns)
- [Development Workflow](#development-workflow)
- [Quality Focus](#quality-focus)
- [Modern Documentation Standards](#modern-documentation-standards)
- [Success Criteria](#success-criteria)

## Core Principles

### Logical Organization First
- **Focus on logical grouping of related functionality**
- **Keep systems coherent and understandable**
- **Split when it makes logical sense, not based on arbitrary limits**
- **Prioritize readability and maintainability over file size restrictions**

### No Fallbacks
- **Never implement error handling or backup systems**
- **Systems must work perfectly or fail immediately**
- **No try-catch, no default values, no graceful degradation**
- If something breaks, let it break loudly and clearly

### Simple Logging
- **Log only to show systems operating normally**
- Use print statements sparingly for critical system confirmations
- Example: `print("Camera initialized")` after successful setup
- **Never log errors or warnings** - let failures be obvious through crashes

### No Testing
- **Never write unit tests, integration tests, or any automated testing**
- **Manual testing only** - run the game and observe behavior
- Testing frameworks are forbidden
- Debug by running the code and fixing what breaks

### Lots of Comments
- **Comment every function, every significant code block**
- **Explain the why, not just the what**
- **Document design decisions and trade-offs**
- Comments should be comprehensive and educational

### Modular Design
- **One clear responsibility per module**
- **Logical separation of concerns**
- **Each module should be independently understandable**
- **Group related functions and data together**

### Logical Separation
- **Physical separation**: Different concerns in different files
- **Logical separation**: Clear boundaries between systems
- **Import separation**: Explicit requires with full paths
- **No cross-contamination**: Systems should not know about each other's internals

### No Hard-coded Values (Except for Testing)
- **Never hard-code numbers, strings, or configuration**
- **Extract all values to named constants or configuration objects**
- **Exception**: Hard-coded values are acceptable during initial development/testing phases
- **Later**: Replace test hard-codes with proper configuration systems

## Organization Guidelines

### Directory Structure
```
project/
├── conf.lua              # LÖVE config (framework requirement)
├── main.lua              # Love2D entry point
├── src/                  # All custom code
│   ├── main.lua          # Love2D entry point (duplicate)
│   ├── core.lua          # Core game logic
│   ├── ecs.lua           # ECS core implementation
│   ├── components.lua    # Component definitions
│   ├── systems.lua       # System aggregator
│   ├── constants.lua     # Game constants
│   ├── parallax.lua      # Legacy parallax system
│   └── systems/          # Individual ECS systems
│       ├── boundary.lua  # Boundary system
│       ├── camera.lua    # Camera system
│       ├── input.lua     # Input system
│       ├── physics.lua   # Physics system
│       ├── render.lua    # Render system
│       ├── trail.lua     # Trail system
│       └── ui.lua        # UI system
└── docs/                 # Documentation
    ├── ARCHITECTURE.md   # System overview
    └── DEVELOPMENT.md    # This guide
```

### When to Split Files
- **When responsibilities become distinct**
- **When one file becomes hard to navigate**
- **When logical groupings emerge naturally**
- **When it improves code organization and understanding**

### When to Keep Together
- **Related functions that work as a unit**
- **Data structures and their manipulation functions**
- **Systems that are tightly coupled conceptually**
- **When separation would reduce clarity**

### Naming Conventions
- **snake_case** for file names: `camera_system.lua`
- **PascalCase** for module tables: `local CameraSystem = {}`
- **Descriptive names**: `parallax_starfield.lua` not `stars.lua`
- **No abbreviations** unless universally understood

### Import Strategy
```lua
-- GOOD: Explicit, namespaced imports with full paths
local CameraSystem = require('src.systems.camera')
local PhysicsSystem = require('src.systems.physics')
local ECS = require('src.ecs')
local Components = require('src.components')

-- BAD: Generic imports or incorrect paths
local cam = require('camera')
local phys = require('physics')
local CameraSystem = require('src.camera_system')  -- Wrong path
```

## Code Organization Patterns

### Module Template
```lua
-- [System Name] module
-- [Brief description of what this system does]
-- [List of responsibilities and design decisions]

local SystemName = {}

-- [Comprehensive function documentation]
function SystemName.new([parameters])
    -- Implementation with lots of comments
end

-- [Related functions grouped together]
function SystemName.update([parameters])
    -- Implementation
end

function SystemName.draw([parameters])
    -- Implementation
end

return SystemName
```

### Logical Function Grouping
```lua
-- GOOD: Related functions grouped by purpose
local PhysicsSystem = {}

-- Creation and initialization
function PhysicsSystem.new() end

-- Force and movement calculations
function PhysicsSystem.applyForce() end
function PhysicsSystem.updateVelocity() end
function PhysicsSystem.integrate() end

-- Collision and boundary handling
function PhysicsSystem.checkBoundaries() end
function PhysicsSystem.handleCollisions() end

-- Rendering and visualization
function PhysicsSystem.draw() end
```

## Development Workflow

### 1. Identify Logical Boundaries
- **Define what the system does conceptually**
- **List the main operations and data it manages**
- **Consider how it relates to other systems**
- **Think about natural divisions of functionality**

### 2. Create Coherent Modules
- **Start with a single file for new systems**
- **Add functions as they naturally fit together**
- **Split only when logical divisions become clear**
- **Maintain clear relationships between functions**

### 3. Organize for Readability
- **Group related functions together**
- **Order functions logically (creation → updates → rendering)**
- **Use clear, descriptive names**
- **Add comprehensive comments**

### 4. Split When It Makes Sense
- **Look for distinct responsibilities that could be separate**
- **Consider if a file is becoming hard to navigate**
- **Think about reusability of subsystems**
- **Ensure splits improve, not complicate, understanding**

## Quality Focus

### Readability Metrics
- **Clear function organization within files**
- **Logical progression of functionality**
- **Comprehensive documentation**
- **Obvious relationships between components**

### Coherence Score
- **Related functions are together**
- **Data and its manipulators are co-located**
- **System boundaries are clear and logical**
- **Cross-system dependencies are minimal and obvious**

### Maintenance Ease
- **Easy to find related functionality**
- **Clear where to add new features**
- **Obvious how systems interact**
- **Simple to understand the overall architecture**

## Success Criteria

✅ **Code is logically organized and easy to navigate**
✅ **Related functionality is grouped together**
✅ **Systems have clear, coherent boundaries**
✅ **Comments explain the logical organization**
✅ **File structure supports understanding**
✅ **No arbitrary size restrictions**
✅ **Focus on conceptual clarity over metrics**

## Modern Documentation Standards

### Documentation Style Guide

#### Formatting Standards
- **Consistent Markdown**: Use standard Markdown syntax throughout
- **Clear Headers**: Use descriptive header hierarchy (H1 → H2 → H3)
- **Code Blocks**: Use syntax highlighting for code examples
- **Lists**: Use consistent bullet points and numbering
- **Tables**: Use tables for structured data presentation

#### Content Guidelines
- **Clarity**: Write in simple, clear language
- **Conciseness**: One idea per sentence, one main idea per paragraph
- **Consistency**: Use consistent terminology throughout
- **Completeness**: Document all public APIs and interfaces
- **Accuracy**: Keep documentation synchronized with code changes

#### Version Control Integration
- **Git Integration**: Track documentation changes with code changes
- **Commit Messages**: Include documentation updates in commit messages
- **Branch Strategy**: Update docs in feature branches alongside code
- **Review Process**: Include documentation in code review process

#### Accessibility Considerations
- **Screen Readers**: Use proper heading structure and alt text
- **Color Contrast**: Ensure sufficient contrast for text readability
- **Navigation**: Provide clear table of contents and internal links
- **Language**: Use clear, simple language accessible to all skill levels

#### Collaborative Tools
- **Real-time Updates**: Use collaborative platforms for team documentation
- **Feedback Integration**: Include feedback mechanisms for documentation improvements
- **Review Schedules**: Establish regular documentation review cycles
- **Change Tracking**: Maintain changelog for significant documentation updates

### Documentation Maintenance

#### Regular Updates
- **Code Synchronization**: Update docs when code changes
- **Review Cycles**: Monthly documentation accuracy reviews
- **User Feedback**: Incorporate user feedback and questions
- **Version Alignment**: Keep documentation version aligned with code version

#### Quality Assurance
- **Accuracy Checks**: Verify all code examples work correctly
- **Link Validation**: Ensure all internal and external links work
- **Formatting Consistency**: Check for consistent formatting throughout
- **Content Completeness**: Ensure all features are documented
