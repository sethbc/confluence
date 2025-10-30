-- Modulation System
-- Manages LFOs and randomization for parameter modulation

local Modulation = {}
Modulation.__index = Modulation

local NUM_LFOS = 3

function Modulation.new()
    local m = {
        -- LFO state
        lfos = {},

        -- Randomization
        random_enabled = false,
        random_amount = 0.1,
        random_rate = 0.5,
        random_phase = 0,

        -- Modulation clock
        mod_clock = nil,
        update_rate = 1/30, -- 30 Hz update rate

        -- Modulation destinations
        destinations = {
            density = {source = 1, amount = 0},
            pitch = {source = 2, amount = 0},
            grain_size = {source = 3, amount = 0},
            spread = {source = 0, amount = 0},
            filter_freq = {source = 0, amount = 0},
        }
    }

    -- Initialize LFOs
    for i = 1, NUM_LFOS do
        m.lfos[i] = {
            shape = 1,        -- 1=sine, 2=tri, 3=square, 4=rampup, 5=rampdown, 6=random
            rate = 0.5,       -- Hz
            depth = 0.5,      -- Modulation depth
            phase = 0,        -- Current phase (0-1)
            value = 0,        -- Current value (-1 to 1)
            last_random = 0,  -- For random shape
        }
    end

    setmetatable(m, Modulation)
    return m
end

-- Start modulation clock
function Modulation:start()
    if self.mod_clock then
        clock.cancel(self.mod_clock)
    end

    self.mod_clock = clock.run(function()
        while true do
            self:update()
            clock.sleep(self.update_rate)
        end
    end)
end

-- Stop modulation clock
function Modulation:stop()
    if self.mod_clock then
        clock.cancel(self.mod_clock)
        self.mod_clock = nil
    end
end

-- Update all LFOs
function Modulation:update()
    local dt = self.update_rate

    -- Update each LFO
    for i = 1, NUM_LFOS do
        local lfo = self.lfos[i]

        -- Advance phase
        lfo.phase = lfo.phase + (lfo.rate * dt)
        lfo.phase = lfo.phase % 1.0

        -- Calculate value based on shape
        lfo.value = self:calculate_lfo_value(lfo)
    end

    -- Update random modulation
    if self.random_enabled then
        self.random_phase = self.random_phase + (self.random_rate * dt)
        if self.random_phase >= 1.0 then
            self.random_phase = 0
            -- Trigger random changes (handled by voice manager)
        end
    end
end

-- Calculate LFO value based on shape
function Modulation:calculate_lfo_value(lfo)
    local phase = lfo.phase
    local value = 0

    if lfo.shape == 1 then
        -- Sine
        value = math.sin(phase * math.pi * 2)

    elseif lfo.shape == 2 then
        -- Triangle
        if phase < 0.5 then
            value = (phase * 4) - 1
        else
            value = 3 - (phase * 4)
        end

    elseif lfo.shape == 3 then
        -- Square
        value = phase < 0.5 and -1 or 1

    elseif lfo.shape == 4 then
        -- Ramp up
        value = (phase * 2) - 1

    elseif lfo.shape == 5 then
        -- Ramp down
        value = 1 - (phase * 2)

    elseif lfo.shape == 6 then
        -- Random (sample and hold)
        if phase < 0.1 then  -- Update at start of cycle
            lfo.last_random = (math.random() * 2) - 1
        end
        value = lfo.last_random
    end

    return value * lfo.depth
end

-- Get LFO value
function Modulation:get_lfo_value(lfo_id)
    if lfo_id < 1 or lfo_id > NUM_LFOS then
        return 0
    end
    return self.lfos[lfo_id].value
end

-- Get bipolar LFO value (-1 to 1)
function Modulation:get_lfo_bipolar(lfo_id)
    return self:get_lfo_value(lfo_id)
end

-- Get unipolar LFO value (0 to 1)
function Modulation:get_lfo_unipolar(lfo_id)
    return (self:get_lfo_value(lfo_id) + 1) / 2
end

-- Set LFO parameter
function Modulation:set_lfo_shape(lfo_id, shape)
    if lfo_id >= 1 and lfo_id <= NUM_LFOS then
        self.lfos[lfo_id].shape = shape
    end
end

function Modulation:set_lfo_rate(lfo_id, rate)
    if lfo_id >= 1 and lfo_id <= NUM_LFOS then
        self.lfos[lfo_id].rate = rate
    end
end

function Modulation:set_lfo_depth(lfo_id, depth)
    if lfo_id >= 1 and lfo_id <= NUM_LFOS then
        self.lfos[lfo_id].depth = depth
    end
end

-- Reset LFO phase
function Modulation:reset_lfo(lfo_id)
    if lfo_id >= 1 and lfo_id <= NUM_LFOS then
        self.lfos[lfo_id].phase = 0
    end
end

-- Reset all LFOs
function Modulation:reset_all()
    for i = 1, NUM_LFOS do
        self:reset_lfo(i)
    end
end

-- Get modulation for a parameter
function Modulation:get_modulation(param_name)
    local dest = self.destinations[param_name]
    if not dest or dest.source == 0 or dest.amount == 0 then
        return 0
    end

    return self:get_lfo_value(dest.source) * dest.amount
end

-- Set modulation routing
function Modulation:set_destination(param_name, source, amount)
    if self.destinations[param_name] then
        self.destinations[param_name].source = source
        self.destinations[param_name].amount = amount
    end
end

-- Get LFO info for display
function Modulation:get_lfo_info(lfo_id)
    if lfo_id < 1 or lfo_id > NUM_LFOS then
        return nil
    end
    return self.lfos[lfo_id]
end

-- Apply modulation to parameter value
function Modulation:apply(base_value, param_name, min_val, max_val)
    local mod = self:get_modulation(param_name)
    local range = max_val - min_val
    local modulated = base_value + (mod * range * 0.5)
    return util.clamp(modulated, min_val, max_val)
end

return Modulation
