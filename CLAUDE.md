# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Confluence is a norns script implementing a 16-voice polyphonic granular synthesis engine. It's written in Lua (norns scripting layer) with a SuperCollider engine (audio synthesis), following the standard norns architecture.

## Norns Development Environment

### Platform Constraints
- **No traditional testing framework**: norns scripts are tested by running on actual hardware or via the norns shield/maiden interface
- **Runtime globals**: `params`, `clock`, `engine`, `screen`, `midi`, `grid`, `arc` are provided by the norns runtime - they will show as undefined in Lua linters but are valid
- **No package manager**: Dependencies are managed via norns' built-in libraries and `include()` statements
- **File paths**: Use norns path helpers like `_path.audio`, `_path.data` for cross-platform compatibility

### Running/Testing
Since this is a norns script, testing requires:
1. Copy to norns at `~/dust/code/confluence/`
2. Restart norns or run `SYSTEM > RESET`
3. Select script from norns menu
4. Test via maiden REPL: http://norns.local/maiden (or via USB at norns.local)

SuperCollider engine compilation happens automatically when the script loads. Watch maiden for engine compilation errors.

## Architecture

### Dual-Layer System
1. **SuperCollider Engine** (`lib/Engine_Confluence.sc`): Audio synthesis, runs in scsynth
2. **Lua Script Layer**: UI, control logic, hardware integration, runs in matron

Communication: Lua → SuperCollider via `engine.commandName(args)` (OSC under the hood)

### Module Organization

**Core Audio/Synthesis:**
- `lib/Engine_Confluence.sc` - SuperCollider engine with 16 grain synthesizers, effects chain, buffer management
- `lib/voice.lua` - Voice allocation, grain triggering, continuous generation clock
- `lib/buffer.lua` - Audio buffer loading, recording, file management

**Parameter & Modulation:**
- `lib/parameters.lua` - norns params system integration (33+ parameters in 4 groups)
- `lib/modulation.lua` - 3 LFOs with 30Hz update rate, runs its own clock
- `lib/effects.lua` - Effects state management, sends updates to SC engine

**UI & Hardware:**
- `lib/ui.lua` - 6-page screen interface, encoder/key handlers
- `lib/grid.lua` - Adaptive layouts for 256/128/64 grids, 15fps LED refresh
- `lib/arc.lua` - 4-encoder control with 3 parameter pages, 15fps LED refresh
- `lib/midi.lua` - Note triggers, CC mapping, pitchbend

**State Management:**
- `lib/presets.lua` - 8 preset slots, morphing, state capture/restore

### Critical Patterns

**Clock Management:**
Each module manages its own clock coroutines:
- `voice.lua`: Grain generation clock + activity decay
- `modulation.lua`: LFO update clock (30Hz)
- `grid.lua` / `arc.lua`: LED refresh clocks (15fps)
- Main script: Screen redraw clock (15fps)

Always cancel clocks in cleanup functions to prevent orphaned coroutines.

**Engine Communication:**
SuperCollider commands are defined in `Engine_Confluence.sc` via `this.addCommand()`.
Lua calls them via `engine.commandName()`:
```lua
-- Defined in SC: this.addCommand(\triggerGrain, "iffffff", {...})
-- Called in Lua:
engine.triggerGrain(voice_id, position, rate, size, pan, amp, source_type)
```

**Parameter Actions:**
Parameters in `parameters.lua` have `action` functions that execute when values change. These bridge the norns params system to module state and engine commands.

**Hardware Device Detection:**
Grid/Arc/MIDI devices are connected via `device = grid.connect()` etc. Check `device` existence before use, as hardware may not be connected.

## Key Implementation Details

### Voice Allocation
- 16 voices with round-robin allocation for MIDI
- Each voice can be triggered manually or automatically
- Continuous mode uses density parameter (grains/sec) to schedule triggers
- Activity tracking for UI visualization (15-level brightness)

### Buffer System
- 8 buffers, 60 seconds each, allocated in SuperCollider
- Buffers are 0-indexed in SC, 1-indexed in Lua (conversion happens in voice.lua)
- Recording uses SuperCollider's RecordBuf UGen with doneAction

### Modulation
- LFOs run continuously even when depth is 0 (for responsive UI)
- Phase advances based on `update_rate * rate` per tick
- Six waveform types with different phase → value calculations
- Modulation destinations are prepared but not all are fully routed yet

### Effects Chain Signal Flow
```
Grain Synths → fxBus → Filter → delayBus → Delay → reverbBus → Reverb → Output
```
Each effect is a separate synth in SuperCollider, connected via audio buses.

### Grid Layout Strategy
Three layouts adapt to hardware:
- **64 (8x8)**: Voices on rows 1-2, combined controls on row 7, utilities on row 8
- **128 (16x8)**: Voices on rows 1-2, separate parameter strips on rows 4-6, utilities on row 8
- **256 (16x16)**: Voices on rows 1-2, future pattern grid rows 5-12, parameters on rows 14-16

LED brightness indicates: voice activity (0-15), parameter values (0-15), utility states (4/15 for off/on).

## Development Considerations

### Adding Parameters
1. Add to `lib/parameters.lua` in appropriate group
2. Set `action` function to update module state and/or call engine command
3. Update UI display in `lib/ui.lua` if showing on screen
4. Consider adding to preset system in `lib/presets.lua` state capture

### Adding Engine Features
1. Define SynthDef in `Engine_Confluence.sc` `addSynthDefs` method
2. Add command in `addCommands` with type signature
3. Call from Lua via `engine.commandName()`
4. Remember: SC is 0-indexed, Lua is 1-indexed - convert as needed

### Adding Hardware Controls
Grid/Arc/MIDI modules are self-contained. To add functionality:
- Grid: Add handler in appropriate layout function (`key_128`, etc.)
- Arc: Add parameter to a page in `pages` table
- MIDI: Add CC mapping to `cc_mappings` table

### Known Incomplete Features
Referenced in README "Known Limitations":
- Preset export/import (file I/O stubs exist in presets.lua)
- Modulation routing matrix UI (routing structure exists but not exposed)
- Buffer waveform display (visualization not implemented)
- Grid 256 pattern sequencer (grid space allocated but not implemented)

## norns Conventions

### File Structure
```
confluence.lua          # Entry point with init(), cleanup(), enc(), key(), redraw()
lib/                    # All modules
data/                   # Auto-created by norns for user data (ignored in git)
```

### Initialization Order
1. `engine.name = "Confluence"` must be set before any includes
2. Include all modules
3. `init()` function runs automatically
4. Engine loads and compiles in background
5. `cleanup()` called on script exit

### Parameter System
- Use `params:add_group()` to organize
- Parameter IDs are strings, accessed via `params:get("id")` and `params:set("id", value)`
- `params:bang()` triggers all actions to initialize state
- PSETs are automatically saved/loaded by norns

### Screen Drawing
- Always `screen.clear()` at start of `redraw()`
- Always `screen.update()` at end
- Use `screen_dirty` flag to avoid unnecessary redraws
- norns screen is 128x64 pixels, monochrome with 16 brightness levels

This architecture supports future expansion: modulation routing UI, pattern recorder for Grid 256, waveform displays, and preset file management.