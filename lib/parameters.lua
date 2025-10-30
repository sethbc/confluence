-- Parameter System
-- Manages all norns parameters and connects them to modules

local Params = {}
Params.__index = Params

function Params.new(voice, buffer, effects, modulation)
    local p = {
        voice = voice,
        buffer = buffer,
        effects = effects,
        modulation = modulation,
    }

    setmetatable(p, Params)
    return p
end

function Params:init()
    -- Clear existing params
    params:clear()

    -- GRAIN PARAMETERS
    params:add_group("GRAIN", 8)

    params:add{
        type = "control",
        id = "density",
        name = "Density",
        controlspec = controlspec.new(0, 50, "lin", 0.1, 8, "grains/sec"),
        action = function(x)
            self.voice:set_density(x)
        end
    }

    params:add{
        type = "control",
        id = "grain_size",
        name = "Grain Size",
        controlspec = controlspec.new(0.01, 2.0, "exp", 0.01, 0.1, "sec"),
        action = function(x)
            self.voice:set_size(x)
        end
    }

    params:add{
        type = "control",
        id = "pitch",
        name = "Pitch",
        controlspec = controlspec.new(0.25, 4.0, "exp", 0.01, 1.0, "x"),
        action = function(x)
            self.voice:set_pitch(x)
        end
    }

    params:add{
        type = "control",
        id = "spread",
        name = "Position Spread",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.1),
        action = function(x)
            self.voice:set_spread(x)
        end
    }

    params:add{
        type = "control",
        id = "grain_amp",
        name = "Grain Amp",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.7),
        action = function(x)
            self.voice:set_amp(x)
        end
    }

    params:add{
        type = "option",
        id = "continuous",
        name = "Continuous Mode",
        options = {"Off", "On"},
        default = 2,
        action = function(x)
            self.voice.continuous_mode = (x == 2)
        end
    }

    params:add{
        type = "control",
        id = "pan_spread",
        name = "Pan Spread",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.0),
        action = function(x)
            engine.setGlobalParam("panSpread", x)
        end
    }

    params:add{
        type = "option",
        id = "grain_envelope",
        name = "Grain Envelope",
        options = {"Sine", "Perc", "Linen", "Trapezoid"},
        default = 1,
        action = function(x)
            engine.setGlobalParam("envType", x - 1)
        end
    }

    -- EFFECTS PARAMETERS
    params:add_group("EFFECTS", 11)

    -- Reverb
    params:add{
        type = "control",
        id = "reverb_mix",
        name = "Reverb Mix",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.3),
        action = function(x)
            if self.effects then
                self.effects:set_reverb_mix(x)
            end
        end
    }

    params:add{
        type = "control",
        id = "reverb_room",
        name = "Reverb Room",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.7),
        action = function(x)
            if self.effects then
                self.effects:set_reverb_room(x)
            end
        end
    }

    params:add{
        type = "control",
        id = "reverb_damp",
        name = "Reverb Damp",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.5),
        action = function(x)
            if self.effects then
                self.effects:set_reverb_damp(x)
            end
        end
    }

    -- Delay
    params:add{
        type = "control",
        id = "delay_time",
        name = "Delay Time",
        controlspec = controlspec.new(0.01, 2.0, "exp", 0.01, 0.375, "sec"),
        action = function(x)
            if self.effects then
                self.effects:set_delay_time(x)
            end
        end
    }

    params:add{
        type = "control",
        id = "delay_feedback",
        name = "Delay Feedback",
        controlspec = controlspec.new(0, 0.95, "lin", 0.01, 0.5),
        action = function(x)
            if self.effects then
                self.effects:set_delay_feedback(x)
            end
        end
    }

    params:add{
        type = "control",
        id = "delay_mix",
        name = "Delay Mix",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.3),
        action = function(x)
            if self.effects then
                self.effects:set_delay_mix(x)
            end
        end
    }

    -- Filter
    params:add{
        type = "control",
        id = "filter_freq",
        name = "Filter Freq",
        controlspec = controlspec.new(20, 20000, "exp", 1, 5000, "Hz"),
        action = function(x)
            if self.effects then
                self.effects:set_filter_freq(x)
            end
        end
    }

    params:add{
        type = "control",
        id = "filter_res",
        name = "Filter Res",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.5),
        action = function(x)
            if self.effects then
                self.effects:set_filter_res(x)
            end
        end
    }

    params:add{
        type = "option",
        id = "filter_type",
        name = "Filter Type",
        options = {"Lowpass", "Highpass", "Bandpass"},
        default = 1,
        action = function(x)
            if self.effects then
                self.effects:set_filter_type(x - 1)
            end
        end
    }

    params:add{
        type = "control",
        id = "filter_mix",
        name = "Filter Mix",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 1.0),
        action = function(x)
            if self.effects then
                self.effects:set_filter_mix(x)
            end
        end
    }

    params:add{
        type = "option",
        id = "filter_enabled",
        name = "Filter Enable",
        options = {"Off", "On"},
        default = 1,
        action = function(x)
            if self.effects then
                self.effects.filter_enabled = (x == 2)
            end
        end
    }

    -- MODULATION PARAMETERS
    params:add_group("MODULATION", 12)

    -- LFO 1
    params:add{
        type = "option",
        id = "lfo1_shape",
        name = "LFO 1 Shape",
        options = {"Sine", "Triangle", "Square", "Ramp Up", "Ramp Down", "Random"},
        default = 1,
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_shape(1, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo1_rate",
        name = "LFO 1 Rate",
        controlspec = controlspec.new(0.01, 20, "exp", 0.01, 0.5, "Hz"),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_rate(1, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo1_depth",
        name = "LFO 1 Depth",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.5),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_depth(1, x)
            end
        end
    }

    -- LFO 2
    params:add{
        type = "option",
        id = "lfo2_shape",
        name = "LFO 2 Shape",
        options = {"Sine", "Triangle", "Square", "Ramp Up", "Ramp Down", "Random"},
        default = 2,
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_shape(2, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo2_rate",
        name = "LFO 2 Rate",
        controlspec = controlspec.new(0.01, 20, "exp", 0.01, 1.0, "Hz"),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_rate(2, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo2_depth",
        name = "LFO 2 Depth",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.3),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_depth(2, x)
            end
        end
    }

    -- LFO 3
    params:add{
        type = "option",
        id = "lfo3_shape",
        name = "LFO 3 Shape",
        options = {"Sine", "Triangle", "Square", "Ramp Up", "Ramp Down", "Random"},
        default = 6,
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_shape(3, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo3_rate",
        name = "LFO 3 Rate",
        controlspec = controlspec.new(0.01, 20, "exp", 0.01, 0.1, "Hz"),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_rate(3, x)
            end
        end
    }

    params:add{
        type = "control",
        id = "lfo3_depth",
        name = "LFO 3 Depth",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.2),
        action = function(x)
            if self.modulation then
                self.modulation:set_lfo_depth(3, x)
            end
        end
    }

    -- Randomization
    params:add{
        type = "control",
        id = "random_amount",
        name = "Random Amount",
        controlspec = controlspec.new(0, 1.0, "lin", 0.01, 0.1),
        action = function(x)
            if self.modulation then
                self.modulation.random_amount = x
            end
        end
    }

    params:add{
        type = "control",
        id = "random_rate",
        name = "Random Rate",
        controlspec = controlspec.new(0.01, 10, "exp", 0.01, 0.5, "Hz"),
        action = function(x)
            if self.modulation then
                self.modulation.random_rate = x
            end
        end
    }

    params:add{
        type = "option",
        id = "random_enabled",
        name = "Random Enable",
        options = {"Off", "On"},
        default = 1,
        action = function(x)
            if self.modulation then
                self.modulation.random_enabled = (x == 2)
            end
        end
    }

    -- BUFFER PARAMETERS
    params:add_group("BUFFER", 2)

    params:add{
        type = "control",
        id = "record_duration",
        name = "Record Duration",
        controlspec = controlspec.new(0.1, 60, "exp", 0.1, 10, "sec"),
        action = function(x)
            self.buffer:set_record_duration(x)
        end
    }

    params:add{
        type = "control",
        id = "record_level",
        name = "Record Level",
        controlspec = controlspec.new(0, 2.0, "lin", 0.01, 1.0),
        action = function(x)
            self.buffer:set_record_level(x)
        end
    }

    -- Default action for all params
    params:bang()

    print("Parameters initialized")
end

return Params
