# Confluence

An ambient granular soundscape generator for monome norns.

A comprehensive 16-voice polyphonic granular synthesis engine with modulation, effects, and full hardware integration for Grid, Arc, and MIDI.

## Features

### Granular Synthesis
- 16 independent grain voices with polyphonic control
- Configurable grain parameters: size, density, pitch, position, pan
- Multiple grain envelope shapes (sine, percussion, linen, trapezoid)
- Continuous automatic grain generation or manual triggering
- Position spread and randomization for evolving textures

### Audio Sources
- Live audio input recording to buffers
- Sample playback from audio files
- Multiple buffer support (8 buffers)
- Generated audio sources (sine, saw, pulse oscillators)
- Real-time buffer switching per voice

### Modulation System
- 3 independent LFOs with multiple waveforms
  - Sine, triangle, square, ramp up, ramp down, random
  - Variable rate (0.01 - 20 Hz)
  - Adjustable depth per LFO
- Randomization engine with configurable amount and rate
- Modulation routing matrix (future expansion)

### Effects Chain
- **Reverb**: FreeVerb with mix, room size, and damping controls
- **Delay**: Stereo delay with time, feedback, and mix
- **Filter**: Multi-mode filter (lowpass, highpass, bandpass) with frequency and resonance

### Hardware Integration

#### Grid Support (Adaptive Layout)
- **256 (16x16)**: Full pattern grid, parameter controls, voice triggers
- **128 (16x8)**: Voice triggers, parameter strips, utility controls
- **64 (8x8)**: Compact layout with essential controls
- LED feedback showing voice activity and parameter values

#### Arc Support
- 4-encoder continuous control with LED ring feedback
- 3 configurable pages:
  - Page 1: Grain parameters (density, pitch, size, spread)
  - Page 2: Effects (reverb, delay, filter)
  - Page 3: Modulation (LFO rates, random amount)
- Visual parameter value indication on LED rings

#### MIDI Integration
- Note input triggers grains with velocity sensitivity
- Note-to-rate conversion (MIDI note 60 = rate 1.0)
- CC parameter mapping (customizable):
  - CC1 (Mod Wheel) → Density
  - CC7 (Volume) → Grain Amplitude
  - CC10 (Pan) → Position Spread
  - CC74 (Brightness) → Filter Frequency
  - CC71 (Resonance) → Filter Resonance
  - CC91 (Reverb) → Reverb Mix
  - CC93 (Chorus) → Delay Mix
- Pitchbend support (±2 semitones)

### Preset System
- 8 preset slots for scene snapshots
- Save/recall all parameter states
- Morphing between presets with adjustable duration
- Randomization function for instant variation
- Export/import presets (planned feature)

## User Interface

### Pages (E1 to navigate)

1. **MAIN**: Grain activity visualization + key parameters
   - 16 voice activity indicators
   - Density and grain size controls

2. **VOICES**: Per-voice detailed control
   - Select voice (E2)
   - Adjust voice parameters (E3)
   - Manual voice trigger (K3)

3. **MODULATION**: LFO visualization and control
   - Real-time waveform display for 3 LFOs
   - Rate and depth adjustment
   - Visual phase indicators

4. **EFFECTS**: Effects parameters
   - Reverb, delay, and filter controls
   - Visual parameter display

5. **BUFFER**: Sample management
   - Buffer selection and loading
   - File browser for audio samples
   - Recording controls
   - Buffer status display

6. **SETUP**: Hardware configuration
   - Connected device status
   - Configuration options

### Controls

- **E1**: Page navigation
- **E2**: Parameter 1 (page-specific)
- **E3**: Parameter 2 (page-specific)
- **K2**: Alt mode (hold)
- **K3**: Trigger/Action (page-specific)

## Installation

1. Copy the `confluence` folder to your norns dust folder:
   ```
   ~/dust/code/confluence/
   ```

2. Restart norns or run `SYSTEM > RESET` from the norns menu

3. Select `CONFLUENCE` from the script selection menu

## Quick Start

1. Load an audio sample or record live input:
   - Navigate to **BUFFER** page (E1)
   - Browse files (E3) and press K3 to load
   - Or start recording with the record function

2. Adjust grain parameters:
   - Navigate to **MAIN** page
   - Adjust density (E2) and grain size (E3)
   - Press K3 to manually trigger grains

3. Add modulation:
   - Navigate to **MODULATION** page
   - Adjust LFO rates and depths
   - Watch the waveform visualization

4. Add effects:
   - Navigate to **EFFECTS** page
   - Adjust reverb, delay, and filter parameters

5. Connect hardware:
   - Grid: Auto-detected, provides hands-on control
   - Arc: Auto-detected, provides continuous parameter control
   - MIDI: Play notes to trigger grains with velocity

## Parameters

All parameters are accessible via the norns PARAMETERS menu and are organized into groups:

- **GRAIN**: Density, size, pitch, spread, amplitude, envelope
- **EFFECTS**: Reverb, delay, and filter parameters
- **MODULATION**: LFO shapes, rates, depths, randomization
- **BUFFER**: Recording duration and level

Parameters support PSET saving for quick recall of configurations.

## Architecture

### File Structure
```
confluence/
├── confluence.lua              # Main script
├── lib/
│   ├── Engine_Confluence.sc    # SuperCollider engine
│   ├── voice.lua               # Grain voice management
│   ├── buffer.lua              # Audio buffer system
│   ├── parameters.lua          # Parameter management
│   ├── modulation.lua          # Modulation engine
│   ├── effects.lua             # Effects system
│   ├── ui.lua                  # Screen UI
│   ├── grid.lua                # Grid integration
│   ├── arc.lua                 # Arc integration
│   ├── midi.lua                # MIDI integration
│   └── presets.lua             # Preset management
├── data/                       # User data (auto-created)
└── README.md
```

### Engine Architecture

The SuperCollider engine (`Engine_Confluence.sc`) provides:
- 16 independent grain synthesizers
- Audio buffer management (8 buffers, 60 seconds each)
- Effects processing chain (filter → delay → reverb)
- Multiple audio source types (buffers, oscillators, live input)
- Real-time parameter control via OSC

## Tips and Tricks

1. **Creating Evolving Textures**: Use slow LFO rates (0.01-0.1 Hz) on grain size and position for gradually shifting soundscapes

2. **Rhythmic Patterns**: Use higher densities (20-50 grains/sec) with short grain sizes (0.01-0.05s) for rhythmic textures

3. **Ambient Pads**: Low density (1-5 grains/sec), large grain size (0.5-2s), high reverb mix

4. **Grid Performance**: Use the 128/256 grid for live triggering of individual voices while adjusting parameters

5. **MIDI Expression**: Connect a MIDI keyboard for expressive grain triggering with velocity and note-based positioning

6. **Buffer Switching**: Record multiple buffers and switch between them per-voice for complex layered textures

## Known Limitations

- Preset export/import not yet implemented
- Modulation routing matrix is prepared but not fully exposed in UI
- Waveform display for buffers not yet implemented
- Pattern sequencer for Grid 256 planned but not yet implemented

## Credits

Built for monome norns using:
- SuperCollider for audio engine
- norns Lua scripting environment
- FreeVerb, CombL, and standard UGens

## License

MIT License - Feel free to modify and extend!