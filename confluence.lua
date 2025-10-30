-- Confluence
-- Ambient granular soundscape generator
--
-- 16-voice polyphonic granular synthesis
-- with modulation, effects, and hardware control
--
-- E1: Page select
-- E2: Parameter 1
-- E3: Parameter 2
-- K2: Alt function
-- K3: Trigger grain / Action

engine.name = "Confluence"

-- Module imports
local Voice = include("lib/voice")
local Buffer = include("lib/buffer")
local Params = include("lib/parameters")
local Modulation = include("lib/modulation")
local Effects = include("lib/effects")
local UI = include("lib/ui")
local GridController = include("lib/grid")
local ArcController = include("lib/arc")
local MidiController = include("lib/midi")

-- Global state
local active_page = 1
local num_pages = 6
local page_names = {"MAIN", "VOICES", "MOD", "FX", "BUFFER", "SETUP"}
local alt_mode = false
local screen_dirty = true
local clock_id

-- Core modules (will be initialized in init())
local voice
local buffer
local params_manager
local modulation
local effects
local ui
local grid_controller
local arc_controller
local midi_controller

-- Initialize script
function init()
    print("Confluence - Initializing...")

    -- Initialize core modules
    voice = Voice.new()
    buffer = Buffer.new()
    effects = Effects.new()
    modulation = Modulation.new()
    params_manager = Params.new(voice, buffer, effects, modulation)
    ui = UI.new(voice, buffer, effects, modulation)

    -- Initialize hardware controllers
    grid_controller = GridController.new(voice, buffer)
    arc_controller = ArcController.new()
    midi_controller = MidiController.new(voice)

    -- Setup parameters
    params_manager:init()

    -- Start UI clock
    clock_id = clock.run(function()
        while true do
            clock.sleep(1/15) -- 15 fps
            if screen_dirty then
                redraw()
            end
        end
    end)

    -- Start modulation system
    modulation:start()

    print("Confluence - Ready")
    screen_dirty = true
end

-- Cleanup on script exit
function cleanup()
    if clock_id then
        clock.cancel(clock_id)
    end
    modulation:stop()
    if grid_controller then
        grid_controller:cleanup()
    end
    if arc_controller then
        arc_controller:cleanup()
    end
    if midi_controller then
        midi_controller:cleanup()
    end
end

-- Encoder input
function enc(n, d)
    if n == 1 then
        -- Page navigation
        active_page = util.clamp(active_page + d, 1, num_pages)
    else
        -- Pass to UI for page-specific handling
        ui:enc(n, d, active_page, alt_mode)
    end
    screen_dirty = true
end

-- Key input
function key(n, z)
    if n == 2 then
        -- Alt mode toggle
        alt_mode = (z == 1)
    elseif n == 3 and z == 1 then
        -- Primary action (page-specific)
        ui:key(n, active_page, alt_mode, voice)
    end
    screen_dirty = true
end

-- Screen redraw
function redraw()
    screen.clear()

    -- Draw page header
    screen.level(15)
    screen.move(0, 8)
    screen.text(page_names[active_page])

    -- Page indicator dots
    for i = 1, num_pages do
        screen.level(i == active_page and 15 or 3)
        screen.move(128 - (num_pages - i + 1) * 8, 8)
        screen.text(".")
    end

    -- Draw page content
    ui:draw(active_page, alt_mode, voice, buffer, effects, modulation)

    screen.update()
    screen_dirty = false
end

-- Grid event callback
g = grid.connect()
g.key = function(x, y, z)
    if grid_controller then
        grid_controller:key(x, y, z)
        screen_dirty = true
    end
end

-- Arc event callback
a = arc.connect()
a.delta = function(n, d)
    if arc_controller then
        arc_controller:delta(n, d)
        screen_dirty = true
    end
end

-- MIDI event callback
function midi_event(data)
    if midi_controller then
        midi_controller:event(data)
        screen_dirty = true
    end
end

-- Set up MIDI
m = midi.connect()
m.event = midi_event
