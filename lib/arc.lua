-- Arc Controller
-- 4-encoder control with LED ring feedback

local Arc = {}
Arc.__index = Arc

function Arc.new()
    local a = {
        device = arc.connect(),

        -- Parameter mappings (param_id for each encoder)
        mappings = {
            {"density", 0, 50},           -- Encoder 1: Density
            {"pitch", 0.25, 4.0},         -- Encoder 2: Pitch
            {"grain_size", 0.01, 2.0},    -- Encoder 3: Grain size
            {"spread", 0, 1.0},           -- Encoder 4: Spread
        },

        -- Page system for different parameter sets
        page = 1,
        pages = {
            -- Page 1: Grain parameters
            {
                {"density", 0, 50},
                {"pitch", 0.25, 4.0},
                {"grain_size", 0.01, 2.0},
                {"spread", 0, 1.0},
            },
            -- Page 2: Effects
            {
                {"reverb_mix", 0, 1.0},
                {"delay_mix", 0, 1.0},
                {"filter_freq", 20, 20000},
                {"filter_res", 0, 1.0},
            },
            -- Page 3: Modulation
            {
                {"lfo1_rate", 0.01, 20},
                {"lfo2_rate", 0.01, 20},
                {"lfo3_rate", 0.01, 20},
                {"random_amount", 0, 1.0},
            },
        },

        -- LED refresh
        refresh_clock = nil,
        dirty = true,

        -- Sensitivity
        sensitivity = 0.5,
    }

    setmetatable(a, Arc)

    -- Load current page mappings
    a.mappings = a.pages[a.page]

    -- Start LED refresh
    a:start_refresh()

    return a
end

-- Start LED refresh clock
function Arc:start_refresh()
    if self.refresh_clock then
        clock.cancel(self.refresh_clock)
    end

    self.refresh_clock = clock.run(function()
        while true do
            if self.dirty and self.device then
                self:refresh()
            end
            clock.sleep(1/15) -- 15 fps
        end
    end)
end

-- Arc encoder delta handler
function Arc:delta(n, d)
    if not self.device then return end

    -- Get parameter mapping for this encoder
    local mapping = self.mappings[n]
    if not mapping then return end

    local param_id = mapping[1]
    local min_val = mapping[2]
    local max_val = mapping[3]

    -- Get current parameter value
    local current = params:get(param_id)

    -- Calculate delta based on parameter range
    local range = max_val - min_val
    local delta = (d / 256) * range * self.sensitivity

    -- Apply delta
    local new_val = util.clamp(current + delta, min_val, max_val)
    params:set(param_id, new_val)

    self.dirty = true
end

-- Refresh LED rings
function Arc:refresh()
    if not self.device then return end

    -- Clear all rings
    for n = 1, 4 do
        self.device:all(n, 0)
    end

    -- Draw parameter values
    for n = 1, 4 do
        local mapping = self.mappings[n]
        if mapping then
            local param_id = mapping[1]
            local min_val = mapping[2]
            local max_val = mapping[3]

            -- Get parameter value
            local value = params:get(param_id)

            -- Normalize to 0-1
            local normalized
            if max_val > min_val * 10 then
                -- Use exponential scaling for wide ranges
                normalized = util.linexp(min_val, max_val, 0, 1, value)
            else
                -- Use linear scaling
                normalized = util.linlin(min_val, max_val, 0, 1, value)
            end

            -- Convert to LED position (0-63)
            local led_pos = math.floor(normalized * 63)

            -- Draw arc
            self:draw_arc(n, led_pos)
        end
    end

    self.device:refresh()
    self.dirty = false
end

-- Draw arc on LED ring
function Arc:draw_arc(ring, position)
    -- Draw filled arc from 0 to position
    for i = 0, 63 do
        local brightness = 0

        if i <= position then
            -- Calculate brightness gradient
            local dist_from_pos = math.abs(i - position)

            if dist_from_pos == 0 then
                brightness = 15 -- Brightest at current position
            elseif i == position - 1 or i == position - 2 then
                brightness = 12
            elseif i >= position - 8 then
                brightness = 8
            else
                brightness = 4
            end
        end

        self.device:led(ring, i, brightness)
    end

    -- Add indicator dot at current position
    self.device:led(ring, position, 15)
end

-- Change page
function Arc:set_page(page_num)
    if page_num >= 1 and page_num <= #self.pages then
        self.page = page_num
        self.mappings = self.pages[self.page]
        self.dirty = true
    end
end

-- Next page
function Arc:next_page()
    self.page = (self.page % #self.pages) + 1
    self.mappings = self.pages[self.page]
    self.dirty = true
end

-- Previous page
function Arc:prev_page()
    self.page = self.page - 1
    if self.page < 1 then
        self.page = #self.pages
    end
    self.mappings = self.pages[self.page]
    self.dirty = true
end

-- Set encoder mapping
function Arc:set_mapping(encoder, param_id, min_val, max_val)
    if encoder >= 1 and encoder <= 4 then
        self.mappings[encoder] = {param_id, min_val, max_val}
        self.dirty = true
    end
end

-- Set sensitivity
function Arc:set_sensitivity(sens)
    self.sensitivity = util.clamp(sens, 0.1, 2.0)
end

-- Cleanup
function Arc:cleanup()
    if self.refresh_clock then
        clock.cancel(self.refresh_clock)
    end
    if self.device then
        for n = 1, 4 do
            self.device:all(n, 0)
        end
        self.device:refresh()
    end
end

return Arc
