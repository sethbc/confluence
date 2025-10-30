-- Preset System
-- Scene snapshots and preset management

local Presets = {}
Presets.__index = Presets

function Presets.new(voice, effects, modulation)
    local p = {
        voice = voice,
        effects = effects,
        modulation = modulation,

        -- Preset storage
        presets = {},
        num_presets = 8,
        current_preset = 1,

        -- Morphing
        morphing = false,
        morph_time = 2.0,
        morph_clock = nil,
    }

    -- Initialize empty presets
    for i = 1, p.num_presets do
        p.presets[i] = {
            name = "empty " .. i,
            data = nil
        }
    end

    setmetatable(p, Presets)
    return p
end

-- Capture current state as preset
function Presets:save(preset_num, name)
    if preset_num < 1 or preset_num > self.num_presets then
        return false
    end

    -- Capture all parameter values
    local state = {
        -- Grain parameters
        grain = {
            density = params:get("density"),
            grain_size = params:get("grain_size"),
            pitch = params:get("pitch"),
            spread = params:get("spread"),
            grain_amp = params:get("grain_amp"),
            continuous = params:get("continuous"),
            pan_spread = params:get("pan_spread"),
            grain_envelope = params:get("grain_envelope"),
        },

        -- Effects state
        effects = self.effects:get_state(),

        -- Modulation state
        modulation = {
            lfo1 = {
                shape = params:get("lfo1_shape"),
                rate = params:get("lfo1_rate"),
                depth = params:get("lfo1_depth"),
            },
            lfo2 = {
                shape = params:get("lfo2_shape"),
                rate = params:get("lfo2_rate"),
                depth = params:get("lfo2_depth"),
            },
            lfo3 = {
                shape = params:get("lfo3_shape"),
                rate = params:get("lfo3_rate"),
                depth = params:get("lfo3_depth"),
            },
            random = {
                amount = params:get("random_amount"),
                rate = params:get("random_rate"),
                enabled = params:get("random_enabled"),
            },
        },

        -- Voice states (optional)
        voices = {},
    }

    -- Capture voice states
    for i = 1, 16 do
        local v = self.voice:get_voice(i)
        if v then
            state.voices[i] = {
                position = v.position,
                rate = v.rate,
                size = v.size,
                pan = v.pan,
                amp = v.amp,
                source_type = v.source_type,
                buffer_id = v.buffer_id,
            }
        end
    end

    -- Store preset
    self.presets[preset_num] = {
        name = name or ("preset " .. preset_num),
        data = state
    }

    print("Saved preset " .. preset_num .. ": " .. self.presets[preset_num].name)
    return true
end

-- Load a preset
function Presets:load(preset_num)
    if preset_num < 1 or preset_num > self.num_presets then
        return false
    end

    local preset = self.presets[preset_num]
    if not preset or not preset.data then
        print("Preset " .. preset_num .. " is empty")
        return false
    end

    local state = preset.data

    -- Restore grain parameters
    if state.grain then
        params:set("density", state.grain.density)
        params:set("grain_size", state.grain.grain_size)
        params:set("pitch", state.grain.pitch)
        params:set("spread", state.grain.spread)
        params:set("grain_amp", state.grain.grain_amp)
        params:set("continuous", state.grain.continuous)
        params:set("pan_spread", state.grain.pan_spread)
        params:set("grain_envelope", state.grain.grain_envelope)
    end

    -- Restore effects
    if state.effects then
        self.effects:set_state(state.effects)
    end

    -- Restore modulation
    if state.modulation then
        if state.modulation.lfo1 then
            params:set("lfo1_shape", state.modulation.lfo1.shape)
            params:set("lfo1_rate", state.modulation.lfo1.rate)
            params:set("lfo1_depth", state.modulation.lfo1.depth)
        end
        if state.modulation.lfo2 then
            params:set("lfo2_shape", state.modulation.lfo2.shape)
            params:set("lfo2_rate", state.modulation.lfo2.rate)
            params:set("lfo2_depth", state.modulation.lfo2.depth)
        end
        if state.modulation.lfo3 then
            params:set("lfo3_shape", state.modulation.lfo3.shape)
            params:set("lfo3_rate", state.modulation.lfo3.rate)
            params:set("lfo3_depth", state.modulation.lfo3.depth)
        end
        if state.modulation.random then
            params:set("random_amount", state.modulation.random.amount)
            params:set("random_rate", state.modulation.random.rate)
            params:set("random_enabled", state.modulation.random.enabled)
        end
    end

    -- Restore voice states
    if state.voices then
        for i = 1, 16 do
            local v = state.voices[i]
            if v then
                self.voice:set_voice_param(i, "position", v.position)
                self.voice:set_voice_param(i, "rate", v.rate)
                self.voice:set_voice_param(i, "size", v.size)
                self.voice:set_voice_param(i, "pan", v.pan)
                self.voice:set_voice_param(i, "amp", v.amp)
                self.voice:set_voice_param(i, "source_type", v.source_type)
                self.voice:set_voice_param(i, "buffer_id", v.buffer_id)
            end
        end
    end

    self.current_preset = preset_num
    print("Loaded preset " .. preset_num .. ": " .. preset.name)
    return true
end

-- Morph between two presets
function Presets:morph(from_preset, to_preset, duration)
    if from_preset < 1 or from_preset > self.num_presets then
        return false
    end
    if to_preset < 1 or to_preset > self.num_presets then
        return false
    end

    local preset_a = self.presets[from_preset]
    local preset_b = self.presets[to_preset]

    if not preset_a.data or not preset_b.data then
        print("Cannot morph: one or both presets are empty")
        return false
    end

    -- Cancel existing morph
    if self.morph_clock then
        clock.cancel(self.morph_clock)
    end

    self.morphing = true
    duration = duration or self.morph_time

    -- Morph clock
    self.morph_clock = clock.run(function()
        local steps = 30
        local step_time = duration / steps

        for step = 0, steps do
            local t = step / steps  -- 0 to 1

            -- Interpolate grain parameters
            if preset_a.data.grain and preset_b.data.grain then
                params:set("density",
                    self:lerp(preset_a.data.grain.density, preset_b.data.grain.density, t))
                params:set("grain_size",
                    self:lerp(preset_a.data.grain.grain_size, preset_b.data.grain.grain_size, t))
                params:set("pitch",
                    self:lerp(preset_a.data.grain.pitch, preset_b.data.grain.pitch, t))
                params:set("spread",
                    self:lerp(preset_a.data.grain.spread, preset_b.data.grain.spread, t))
            end

            clock.sleep(step_time)
        end

        -- Ensure we end at exact target
        self:load(to_preset)
        self.morphing = false
        self.morph_clock = nil

        print("Morph complete")
    end)

    return true
end

-- Linear interpolation
function Presets:lerp(a, b, t)
    return a + (b - a) * t
end

-- Get preset info
function Presets:get_preset_info(preset_num)
    if preset_num < 1 or preset_num > self.num_presets then
        return nil
    end
    return self.presets[preset_num]
end

-- Get all preset names
function Presets:get_preset_names()
    local names = {}
    for i = 1, self.num_presets do
        names[i] = self.presets[i].name
    end
    return names
end

-- Clear preset
function Presets:clear(preset_num)
    if preset_num < 1 or preset_num > self.num_presets then
        return false
    end

    self.presets[preset_num] = {
        name = "empty " .. preset_num,
        data = nil
    }

    print("Cleared preset " .. preset_num)
    return true
end

-- Export preset to file
function Presets:export(preset_num, filename)
    if preset_num < 1 or preset_num > self.num_presets then
        return false
    end

    local preset = self.presets[preset_num]
    if not preset.data then
        print("Cannot export empty preset")
        return false
    end

    -- TODO: Implement file export using norns file I/O
    -- tab.save(preset.data, _path.data .. "confluence/" .. filename .. ".preset")

    print("Export preset " .. preset_num .. " (not yet implemented)")
    return true
end

-- Import preset from file
function Presets:import(preset_num, filename)
    if preset_num < 1 or preset_num > self.num_presets then
        return false
    end

    -- TODO: Implement file import using norns file I/O
    -- local data = tab.load(_path.data .. "confluence/" .. filename .. ".preset")

    print("Import preset to " .. preset_num .. " (not yet implemented)")
    return true
end

-- Randomize current parameters
function Presets:randomize()
    -- Randomize grain parameters within reasonable ranges
    params:set("density", math.random() * 30 + 5)  -- 5-35
    params:set("grain_size", math.random() * 0.3 + 0.05)  -- 0.05-0.35
    params:set("pitch", math.random() * 2 + 0.5)  -- 0.5-2.5
    params:set("spread", math.random() * 0.5)  -- 0-0.5

    -- Randomize LFO rates
    params:set("lfo1_rate", math.random() * 2 + 0.1)
    params:set("lfo2_rate", math.random() * 3 + 0.1)
    params:set("lfo3_rate", math.random() * 1 + 0.05)

    print("Randomized parameters")
end

return Presets
