-- Voice Manager
-- Manages 16 grain voices with manual and automatic triggering

local Voice = {}
Voice.__index = Voice

local NUM_VOICES = 16

function Voice.new()
    local v = {
        num_voices = NUM_VOICES,

        -- Voice state
        voices = {},

        -- Global parameters
        density = 8.0,          -- Grains per second
        global_pitch = 1.0,     -- Global pitch multiplier
        global_size = 0.1,      -- Global grain size (seconds)
        global_amp = 0.7,       -- Global amplitude
        spread = 0.1,           -- Position spread/randomization

        -- Continuous grain generation
        continuous_mode = true,
        generation_clock = nil,

        -- Activity tracking
        activity = {},
    }

    -- Initialize voice state
    for i = 1, NUM_VOICES do
        v.voices[i] = {
            active = false,
            position = 0.0,
            rate = 1.0,
            size = 0.1,
            pan = 0.0,
            amp = 0.7,
            envelope = 0,         -- 0=sine, 1=perc, 2=linen, 3=trapezoid
            source_type = 0,      -- 0=buffer, 1=sine, 2=saw, 3=pulse, 4=input
            buffer_id = 0,
            last_trigger = 0,
        }
        v.activity[i] = 0
    end

    setmetatable(v, Voice)

    -- Start continuous grain generation clock
    v:start_generation()

    return v
end

-- Trigger a grain on a specific voice
function Voice:trigger(voice_id, position, rate, size, pan, amp, source_type)
    if voice_id < 1 or voice_id > self.num_voices then
        return
    end

    local v = self.voices[voice_id]

    -- Use provided values or voice defaults
    position = position or v.position
    rate = rate or v.rate * self.global_pitch
    size = size or v.size
    pan = pan or v.pan
    amp = amp or v.amp * self.global_amp
    source_type = source_type or v.source_type

    -- Send trigger to engine
    engine.triggerGrain(
        voice_id - 1,  -- Engine uses 0-indexed voices
        position,
        rate,
        size,
        pan,
        amp,
        source_type
    )

    -- Update voice state
    v.active = true
    v.last_trigger = util.time()

    -- Set activity indicator (will decay)
    self.activity[voice_id] = 15

    -- Auto-deactivate after grain duration
    clock.run(function()
        clock.sleep(size)
        v.active = false
    end)
end

-- Trigger a grain with global parameters
function Voice:trigger_global(voice_id)
    if voice_id < 1 or voice_id > self.num_voices then
        return
    end

    local v = self.voices[voice_id]

    -- Add randomization to position
    local pos = v.position + (math.random() - 0.5) * self.spread
    pos = util.clamp(pos, 0, 1)

    -- Add slight randomization to rate
    local rate = v.rate * self.global_pitch * (0.95 + math.random() * 0.1)

    -- Use global size with voice variation
    local size = self.global_size + (math.random() - 0.5) * 0.02

    self:trigger(voice_id, pos, rate, size, v.pan, v.amp * self.global_amp, v.source_type)
end

-- Trigger a random voice
function Voice:trigger_random()
    local voice_id = math.random(1, self.num_voices)
    self:trigger_global(voice_id)
end

-- Start continuous grain generation
function Voice:start_generation()
    if self.generation_clock then
        clock.cancel(self.generation_clock)
    end

    self.generation_clock = clock.run(function()
        while true do
            if self.continuous_mode and self.density > 0 then
                -- Calculate interval based on density
                local interval = 1.0 / self.density

                -- Trigger a random voice
                self:trigger_random()

                -- Wait for next grain
                clock.sleep(interval)
            else
                -- If not continuous, check less frequently
                clock.sleep(0.1)
            end

            -- Decay activity indicators
            for i = 1, self.num_voices do
                if self.activity[i] > 0 then
                    self.activity[i] = math.max(0, self.activity[i] - 1)
                end
            end
        end
    end)
end

-- Stop continuous generation
function Voice:stop_generation()
    if self.generation_clock then
        clock.cancel(self.generation_clock)
        self.generation_clock = nil
    end
end

-- Set voice parameter
function Voice:set_voice_param(voice_id, param, value)
    if voice_id < 1 or voice_id > self.num_voices then
        return
    end

    self.voices[voice_id][param] = value

    -- If it's a real-time parameter, update the engine
    if param == "buffer_id" then
        engine.setBufferForVoice(voice_id - 1, value)
    end
end

-- Set global parameter
function Voice:set_global_param(param, value)
    self[param] = value
end

-- Get voice state
function Voice:get_voice(voice_id)
    if voice_id < 1 or voice_id > self.num_voices then
        return nil
    end
    return self.voices[voice_id]
end

-- Get voice activity level (for visualization)
function Voice:get_activity(voice_id)
    if voice_id < 1 or voice_id > self.num_voices then
        return 0
    end
    return self.activity[voice_id]
end

-- Toggle continuous mode
function Voice:toggle_continuous()
    self.continuous_mode = not self.continuous_mode
    return self.continuous_mode
end

-- Set density (grains per second)
function Voice:set_density(density)
    self.density = util.clamp(density, 0, 100)
end

-- Set global pitch
function Voice:set_pitch(pitch)
    self.global_pitch = util.clamp(pitch, 0.25, 4.0)
end

-- Set global size
function Voice:set_size(size)
    self.global_size = util.clamp(size, 0.001, 2.0)
end

-- Set global amplitude
function Voice:set_amp(amp)
    self.global_amp = util.clamp(amp, 0.0, 1.0)
end

-- Set spread (randomization)
function Voice:set_spread(spread)
    self.spread = util.clamp(spread, 0.0, 1.0)
end

-- Mute all voices
function Voice:mute_all()
    for i = 1, self.num_voices do
        self.voices[i].amp = 0
    end
end

-- Reset all voices to defaults
function Voice:reset_all()
    for i = 1, self.num_voices do
        local v = self.voices[i]
        v.position = (i - 1) / self.num_voices  -- Spread across buffer
        v.rate = 1.0
        v.size = 0.1
        v.pan = 0.0
        v.amp = 0.7
        v.envelope = 0
        v.source_type = 0
        v.buffer_id = 0
    end
end

return Voice
