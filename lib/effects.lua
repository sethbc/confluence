-- Effects Module
-- Manages reverb, delay, and filter effects

local Effects = {}
Effects.__index = Effects

function Effects.new()
    local e = {
        -- Reverb parameters
        reverb = {
            mix = 0.3,
            room = 0.7,
            damp = 0.5,
        },

        -- Delay parameters
        delay = {
            time = 0.375,
            feedback = 0.5,
            mix = 0.3,
        },

        -- Filter parameters
        filter = {
            freq = 5000,
            res = 0.5,
            type = 0,  -- 0=lowpass, 1=highpass, 2=bandpass
            mix = 1.0,
        },

        filter_enabled = false,
    }

    setmetatable(e, Effects)
    return e
end

-- Reverb controls
function Effects:set_reverb_mix(mix)
    self.reverb.mix = util.clamp(mix, 0, 1)
    self:update_reverb()
end

function Effects:set_reverb_room(room)
    self.reverb.room = util.clamp(room, 0, 1)
    self:update_reverb()
end

function Effects:set_reverb_damp(damp)
    self.reverb.damp = util.clamp(damp, 0, 1)
    self:update_reverb()
end

function Effects:update_reverb()
    engine.setReverb(
        self.reverb.mix,
        self.reverb.room,
        self.reverb.damp
    )
end

-- Delay controls
function Effects:set_delay_time(time)
    self.delay.time = util.clamp(time, 0.01, 2.0)
    self:update_delay()
end

function Effects:set_delay_feedback(feedback)
    self.delay.feedback = util.clamp(feedback, 0, 0.95)
    self:update_delay()
end

function Effects:set_delay_mix(mix)
    self.delay.mix = util.clamp(mix, 0, 1)
    self:update_delay()
end

function Effects:update_delay()
    engine.setDelay(
        self.delay.time,
        self.delay.feedback,
        self.delay.mix
    )
end

-- Filter controls
function Effects:set_filter_freq(freq)
    self.filter.freq = util.clamp(freq, 20, 20000)
    self:update_filter()
end

function Effects:set_filter_res(res)
    self.filter.res = util.clamp(res, 0, 1)
    self:update_filter()
end

function Effects:set_filter_type(type)
    self.filter.type = util.clamp(type, 0, 2)
    self:update_filter()
end

function Effects:set_filter_mix(mix)
    self.filter.mix = util.clamp(mix, 0, 1)
    self:update_filter()
end

function Effects:update_filter()
    local effective_mix = self.filter_enabled and self.filter.mix or 0
    engine.setFilter(
        self.filter.freq,
        self.filter.res,
        self.filter.type,
        effective_mix
    )
end

-- Get effect parameters for display
function Effects:get_reverb()
    return self.reverb
end

function Effects:get_delay()
    return self.delay
end

function Effects:get_filter()
    return self.filter
end

-- Preset management
function Effects:get_state()
    return {
        reverb = {
            mix = self.reverb.mix,
            room = self.reverb.room,
            damp = self.reverb.damp,
        },
        delay = {
            time = self.delay.time,
            feedback = self.delay.feedback,
            mix = self.delay.mix,
        },
        filter = {
            freq = self.filter.freq,
            res = self.filter.res,
            type = self.filter.type,
            mix = self.filter.mix,
        },
        filter_enabled = self.filter_enabled,
    }
end

function Effects:set_state(state)
    if state.reverb then
        self.reverb = state.reverb
        self:update_reverb()
    end

    if state.delay then
        self.delay = state.delay
        self:update_delay()
    end

    if state.filter then
        self.filter = state.filter
        self.filter_enabled = state.filter_enabled or false
        self:update_filter()
    end
end

return Effects
