# Improving the Proj Mechanism in Exer

## Executive Summary

The current `proj` mechanism in Exer provides automated build/run task generation from `exec.toml` configuration files. While functional for simple scenarios, it has significant limitations in compiler support, build tool integration, and customization flexibility. This document proposes a phased improvement plan that maintains backward compatibility while adding powerful new capabilities.

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Identified Limitations](#identified-limitations)
3. [Proposed Solutions](#proposed-solutions)
4. [Implementation Roadmap](#implementation-roadmap)
5. [Technical Specifications](#technical-specifications)
6. [Migration Strategy](#migration-strategy)
7. [TODO List](#todo-list)

## Current Architecture Analysis

### Overview

The proj mechanism consists of several interconnected modules:

```
proj/
├── init.lua       # Main entry point, orchestrates the system
├── parser.lua     # Parses exec.toml configuration
├── compiler.lua   # Hardcoded compiler definitions
├── tasks.lua      # Generates build/run tasks from apps
├── find.lua       # Locates exec.toml files
├── valid.lua      # Validates configuration
└── vars.lua       # Variable expansion (${file}, ${name}, etc.)
```

### Current Flow

1. **Configuration Loading**: `proj.load()` finds and parses `exec.toml`
2. **App Processing**: Apps are converted to three task types:
   - Build task (using predefined compiler commands)
   - Run task (based on output type)
   - Build & Run task (combination)
3. **Task Generation**: Tasks are generated with hardcoded patterns
4. **Integration**: Tasks appear in the picker alongside other options

### Supported Features

- **Languages**: C, C++, Java, Kotlin, Go, Rust (6 total)
- **App Types**: binary, class, jar, script
- **Variable Expansion**: ${file}, ${name}, ${root}, etc.
- **Build Arguments**: Passed to compiler commands
- **Run Arguments**: Passed to executables

## Identified Limitations

### 1. Limited Compiler Support

**Current State**: Only 6 languages with hardcoded compiler commands
```lua
-- compiler.lua
COMPILERS = {
  c = { binary = "gcc %s -o %s %s" },
  cpp = { binary = "g++ %s -o %s %s" },
  java = { class = "javac %s -d %s %s" },
  -- etc.
}
```

**Issues**:
- No support for: Swift, Zig, Crystal, Nim, Pascal, D, etc.
- Cannot use alternative compilers (clang, icc, msvc)
- No support for cross-compilation
- Missing debug/release build variants

### 2. No Build Tool Integration

**Current State**: Ignores existing build systems
**Missing**: Make, CMake, Gradle, Maven, Cargo, npm scripts, etc.

This creates redundancy when projects already have build configurations.

### 3. Lack of Customization

**Current State**: Users cannot override compiler commands
**Needed**: Ability to define custom build commands per project

### 4. Rigid Type System

**Current State**: Fixed app types (binary, class, jar, script)
**Missing**: Libraries, frameworks, web apps, mobile apps, etc.

### 5. Single-Step Build Limitation

**Current State**: One compile command per app
**Needed**: Multi-step builds, pre/post processing, asset compilation

### 6. Poor Error Handling

**Current State**: Silent failures in many cases
**Needed**: Clear error messages and debugging support

### 7. No Caching

**Current State**: Rebuilds everything every time
**Needed**: Incremental builds, dependency tracking

## Proposed Solutions

### Solution 1: Enhanced Compiler Definition System

Add a flexible compiler configuration system:

```toml
# In exec.toml or global config
[exer.compilers]
# Override existing
c.binary = "clang ${files} -o ${output} ${args}"
c.debug = "gcc ${files} -g -O0 -o ${output} ${args}"

# Add new languages
swift.binary = "swiftc ${files} -o ${output} ${args}"
zig.binary = "zig build-exe ${files} -o ${output} ${args}"
```

**Pros**:
- User customizable
- Supports multiple build variants
- Easy to add new languages

**Cons**:
- Still requires manual configuration
- Doesn't leverage existing build tools

### Solution 2: Build Tool Detection and Integration

Automatically detect and use existing build systems:

```lua
-- Proposed detection order
function detectBuildSystem(workDir)
  if exists("Makefile") then return "make"
  elseif exists("CMakeLists.txt") then return "cmake"
  elseif exists("build.gradle") then return "gradle"
  elseif exists("Cargo.toml") then return "cargo"
  elseif exists("package.json") then return "npm"
  -- fallback to proj mechanism
end
```

**Pros**:
- Leverages existing configurations
- No redundancy
- Professional workflow support

**Cons**:
- Complex implementation
- May conflict with user expectations

### Solution 3: Custom Command Support

Allow direct command specification in apps:

```toml
[[exer.apps]]
name = "my_app"
entry = "src/main.c"

# Option 1: Override with custom commands
build_cmd = "make -C build release"
run_cmd = "./build/bin/my_app"
clean_cmd = "make clean"

# Option 2: Use predefined type
type = "binary"
output = "dist/my_app"
```

**Pros**:
- Maximum flexibility
- Simple to implement
- Clear user intent

**Cons**:
- More verbose configuration
- No automatic inference

### Solution 4: Hybrid Approach (Recommended)

Combine all approaches with clear precedence:

1. **Custom commands** (if specified)
2. **Build tool** (if detected)
3. **Custom compiler** (if configured)
4. **Default compiler** (fallback)

```toml
[[exer.apps]]
name = "my_app"
entry = "src/main.c"

# All optional - system chooses best approach
build_cmd = "custom command"     # Highest priority
build_tool = "make"              # Override detection
compiler = "clang"               # Use specific compiler
type = "binary"                  # Use default pattern
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

1. **Refactor compiler.lua**
   - Extract compiler definitions to configuration
   - Add compiler variant support (debug/release)
   - Implement compiler override mechanism

2. **Enhance parser.lua**
   - Support new configuration fields
   - Maintain backward compatibility
   - Add validation for new fields

### Phase 2: Custom Commands (Week 3-4)

1. **Update tasks.lua**
   - Check for custom commands first
   - Fall back to generated commands
   - Support command arrays and strings

2. **Add build profiles**
   - Debug/Release/Custom profiles
   - Per-profile command overrides
   - Environment variable support

### Phase 3: Build Tool Integration (Week 5-6)

1. **Create build tool detector**
   - Modular detection system
   - Priority configuration
   - Caching for performance

2. **Implement build tool adapters**
   - Make, CMake, Cargo, npm, etc.
   - Unified interface
   - Error handling

### Phase 4: Advanced Features (Week 7-8)

1. **Multi-step builds**
   - Pre/post build commands
   - Asset processing
   - Command chaining

2. **Dependency tracking**
   - File modification detection
   - Incremental builds
   - Build cache

### Phase 5: Polish and Documentation (Week 9-10)

1. **Error handling improvements**
   - Clear error messages
   - Debugging aids
   - Recovery suggestions

2. **Documentation and examples**
   - Migration guide
   - Best practices
   - Common patterns

## Technical Specifications

### New Configuration Schema

```toml
# exec.toml
[exer]
# Global settings
default_compiler = "gcc"
build_tool_priority = ["make", "cmake", "custom"]

[exer.compilers]
# Compiler definitions
c.binary.debug = "gcc ${files} -g -O0 -o ${output} ${args}"
c.binary.release = "gcc ${files} -O3 -o ${output} ${args}"
swift.binary = "swiftc ${files} -o ${output} ${args}"

[[exer.apps]]
name = "my_app"
entry = "src/main.c"
output = "dist/my_app"

# All optional
type = "binary"                    # For automatic inference
profile = "release"                # Build profile
compiler = "clang"                 # Override compiler
build_tool = "make"                # Force specific build tool
build_cmd = "make release"         # Custom build command
run_cmd = "./dist/my_app"         # Custom run command
clean_cmd = "make clean"          # Clean command
test_cmd = "make test"            # Test command
env = { CC = "clang" }            # Environment variables

# Multi-step commands
pre_build = ["mkdir -p dist"]
post_build = ["strip ${output}"]

# Build-specific files
files = ["src/*.c", "!src/test_*.c"]  # Glob patterns with exclusions
includes = ["include", "vendor/include"]
libs = ["m", "pthread"]
```

### API Changes

```lua
-- proj/compiler.lua
M.getCompiler = function(lang, type, profile)
  -- Check user config first
  local userCompiler = config.getCompiler(lang, type, profile)
  if userCompiler then return userCompiler end
  
  -- Check build tool
  local buildTool = M.detectBuildTool()
  if buildTool then return M.getBuildToolAdapter(buildTool) end
  
  -- Fall back to defaults
  return M.getDefaultCompiler(lang, type)
end

-- proj/tasks.lua
M.generateBuildTask = function(app, lang)
  -- Priority: custom_cmd > build_tool > compiler
  if app.build_cmd then
    return M.createCustomTask(app.build_cmd)
  end
  
  if app.build_tool or M.detectBuildTool() then
    return M.createBuildToolTask(app)
  end
  
  return M.createCompilerTask(app, lang)
end
```

### Build Tool Adapters

```lua
-- proj/build_tools/make.lua
return {
  detect = function(workDir)
    return io.fileExists(workDir .. "/Makefile")
  end,
  
  getBuildCmd = function(app, profile)
    local target = app.make_target or app.name
    return "make " .. target
  end,
  
  getRunCmd = function(app)
    return "./" .. app.output
  end,
  
  getCleanCmd = function(app)
    return "make clean"
  end
}
```

## Migration Strategy

### Backward Compatibility

1. **Existing configs continue to work**
   - Old format maps to new internal structure
   - Warning messages for deprecated features
   - Automatic migration suggestions

2. **Gradual adoption**
   - New features are opt-in
   - Can mix old and new syntax
   - Clear documentation

### Migration Path

```toml
# Old format (still works)
[[exer.apps]]
name = "old_app"
entry = "main.c"
output = "old_app"
type = "binary"

# New format (enhanced)
[[exer.apps]]
name = "new_app"
entry = "main.c"
output = "new_app"
build_cmd = "clang main.c -o new_app -O3"  # Override everything
```

### Deprecation Timeline

1. **Version 1.0**: Current behavior (baseline)
2. **Version 1.1**: New features added, old format supported
3. **Version 1.2**: Deprecation warnings for old format
4. **Version 2.0**: Old format removed (6 months later)

## TODO List

### High Priority

- [ ] **Refactor compiler.lua to support configuration** (Phase 1)
  - [ ] Extract hardcoded compilers to config structure
  - [ ] Add profile support (debug/release)
  - [ ] Implement override mechanism
  
- [ ] **Add custom command support** (Phase 2)
  - [ ] Update parser to handle new fields
  - [ ] Modify tasks.lua to check custom commands first
  - [ ] Add validation for command syntax

- [ ] **Implement build tool detection** (Phase 3)
  - [ ] Create modular detection system
  - [ ] Add Make and CMake adapters
  - [ ] Test with real projects

### Medium Priority

- [ ] **Enhance error handling**
  - [ ] Add detailed error messages
  - [ ] Implement fallback mechanisms
  - [ ] Create debugging mode

- [ ] **Add more language support**
  - [ ] Swift, Zig, Crystal, Nim
  - [ ] Research compilation patterns
  - [ ] Add to default compilers

- [ ] **Create build profiles**
  - [ ] Debug/Release/Custom
  - [ ] Per-profile settings
  - [ ] Profile selection UI

### Low Priority

- [ ] **Implement caching system**
  - [ ] Track file modifications
  - [ ] Cache build outputs
  - [ ] Incremental build support

- [ ] **Add dependency management**
  - [ ] Parse include/import statements
  - [ ] Build dependency graph
  - [ ] Optimize build order

- [ ] **Create project templates**
  - [ ] Language-specific templates
  - [ ] Build tool templates
  - [ ] Quick start guides

### Documentation

- [ ] **Write migration guide**
- [ ] **Create example configurations**
- [ ] **Document best practices**
- [ ] **Add troubleshooting section**

### Testing

- [ ] **Create comprehensive test suite**
- [ ] **Test backward compatibility**
- [ ] **Performance benchmarks**
- [ ] **Real-world project testing**

## Conclusion

The proposed improvements will transform the proj mechanism from a simple hardcoded system into a flexible, extensible build orchestration framework. By maintaining backward compatibility and providing a gradual migration path, users can adopt new features at their own pace while enjoying immediate benefits from enhanced functionality.

The hybrid approach recommended here balances simplicity with power, allowing both beginners and advanced users to work efficiently within their preferred workflows.
