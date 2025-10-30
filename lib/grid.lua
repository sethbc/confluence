-- Grid Controller
-- Adaptive grid interface for 256, 128, and 64 key grids

local Grid = {}
Grid.__index = Grid

function Grid.new(voice, buffer)
    local g = {
        device = grid.connect(),
        voice = voice,
        buffer = buffer,

        -- Grid configuration
        cols = 16,
        rows = 8,
        grid_type = "none", -- "256", "128", "64"

        -- State
        held_keys = {},
        voice_states = {},

        -- LED refresh
        refresh_clock = nil,
        dirty = true,
    }

    -- Initialize voice states
    for i = 1, 16 do
        g.voice_states[i] = false
    end

    setmetatable(g, Grid)

    -- Detect grid and start refresh
    g:detect_grid()
    g:start_refresh()

    return g
end

-- Detect grid size
function Grid:detect_grid()
    if self.device then
        self.cols = self.device.cols or 16
        self.rows = self.device.rows or 8

        if self.cols == 16 and self.rows == 8 then
            self.grid_type = "128"
        elseif self.cols == 16 and self.rows == 16 then
            self.grid_type = "256"
        elseif self.cols == 8 and self.rows == 8 then
            self.grid_type = "64"
        end

        print("Grid detected: " .. self.grid_type)
    else
        self.grid_type = "none"
    end
end

-- Start LED refresh clock
function Grid:start_refresh()
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

-- Grid key handler
function Grid:key(x, y, z)
    if not self.device then return end

    if self.grid_type == "128" then
        self:key_128(x, y, z)
    elseif self.grid_type == "256" then
        self:key_256(x, y, z)
    elseif self.grid_type == "64" then
        self:key_64(x, y, z)
    end

    self.dirty = true
end

-- 128 grid layout (16x8)
function Grid:key_128(x, y, z)
    -- Top 2 rows: 16 voice triggers
    if y <= 2 then
        local voice = x + ((y - 1) * 8)
        if voice <= 16 then
            if z == 1 then
                -- Key down - trigger grain
                self.voice:trigger_global(voice)
                self.voice_states[voice] = true
            else
                -- Key up
                self.voice_states[voice] = false
            end
        end

    -- Row 4: Density control (position-based)
    elseif y == 4 then
        if z == 1 then
            local density = util.linlin(1, 16, 0, 50, x)
            params:set("density", density)
        end

    -- Row 5: Grain size control
    elseif y == 5 then
        if z == 1 then
            local size = util.linexp(1, 16, 0.01, 2.0, x)
            params:set("grain_size", size)
        end

    -- Row 6: Pitch control
    elseif y == 6 then
        if z == 1 then
            local pitch = util.linexp(1, 16, 0.25, 4.0, x)
            params:set("pitch", pitch)
        end

    -- Row 8: Utility functions
    elseif y == 8 then
        if z == 1 then
            if x == 1 then
                -- Toggle continuous mode
                self.voice:toggle_continuous()
            elseif x == 16 then
                -- Trigger random grain
                self.voice:trigger_random()
            end
        end
    end
end

-- 256 grid layout (16x16)
function Grid:key_256(x, y, z)
    -- Top 2 rows: 16 voice triggers (same as 128)
    if y <= 2 then
        local voice = x + ((y - 1) * 8)
        if voice <= 16 then
            if z == 1 then
                self.voice:trigger_global(voice)
                self.voice_states[voice] = true
            else
                self.voice_states[voice] = false
            end
        end

    -- Rows 5-12: 8x16 pattern sequencer (future expansion)
    elseif y >= 5 and y <= 12 then
        -- Pattern grid - to be implemented
        -- Could be used for grain pattern recording/playback

    -- Bottom rows: Parameter control
    elseif y == 14 then
        if z == 1 then
            local density = util.linlin(1, 16, 0, 50, x)
            params:set("density", density)
        end

    elseif y == 15 then
        if z == 1 then
            local pitch = util.linexp(1, 16, 0.25, 4.0, x)
            params:set("pitch", pitch)
        end

    elseif y == 16 then
        if z == 1 then
            local size = util.linexp(1, 16, 0.01, 2.0, x)
            params:set("grain_size", size)
        end
    end
end

-- 64 grid layout (8x8)
function Grid:key_64(x, y, z)
    -- Top 2 rows: 16 voice triggers (8 per row)
    if y <= 2 then
        local voice = x + ((y - 1) * 8)
        if z == 1 then
            self.voice:trigger_global(voice)
            self.voice_states[voice] = true
        else
            self.voice_states[voice] = false
        end

    -- Row 7: Combined controls
    elseif y == 7 then
        if z == 1 then
            if x <= 4 then
                -- Density (4 steps)
                local density = util.linlin(1, 4, 0, 50, x)
                params:set("density", density)
            else
                -- Pitch (4 steps)
                local pitch = util.linexp(5, 8, 0.5, 2.0, x)
                params:set("pitch", pitch)
            end
        end

    -- Row 8: Utilities
    elseif y == 8 then
        if z == 1 then
            if x == 1 then
                self.voice:toggle_continuous()
            elseif x == 8 then
                self.voice:trigger_random()
            end
        end
    end
end

-- Refresh LEDs
function Grid:refresh()
    if not self.device then return end

    self.device:all(0) -- Clear all LEDs

    if self.grid_type == "128" then
        self:refresh_128()
    elseif self.grid_type == "256" then
        self:refresh_256()
    elseif self.grid_type == "64" then
        self:refresh_64()
    end

    self.device:refresh()
    self.dirty = false
end

-- 128 grid LED pattern
function Grid:refresh_128()
    -- Voice triggers with activity
    for i = 1, 16 do
        local x = ((i - 1) % 8) + 1
        local y = math.floor((i - 1) / 8) + 1
        local activity = self.voice:get_activity(i)
        local brightness = activity > 0 and 15 or 4

        if self.voice_states[i] then
            brightness = 15
        end

        self.device:led(x, y, brightness)
    end

    -- Parameter rows - show current value
    local density_x = util.round(util.linlin(0, 50, 1, 16, params:get("density")))
    for x = 1, 16 do
        self.device:led(x, 4, x <= density_x and 8 or 2)
    end

    local size_val = params:get("grain_size")
    local size_x = util.round(util.linexp(0.01, 2.0, 1, 16, size_val))
    for x = 1, 16 do
        self.device:led(x, 5, x <= size_x and 8 or 2)
    end

    -- Utility row
    self.device:led(1, 8, self.voice.continuous_mode and 15 or 4)
    self.device:led(16, 8, 8)
end

-- 256 grid LED pattern
function Grid:refresh_256()
    -- Voice triggers (same as 128)
    for i = 1, 16 do
        local x = ((i - 1) % 8) + 1
        local y = math.floor((i - 1) / 8) + 1
        local activity = self.voice:get_activity(i)
        local brightness = activity > 0 and 15 or 4

        if self.voice_states[i] then
            brightness = 15
        end

        self.device:led(x, y, brightness)
    end

    -- Parameter rows at bottom
    local density_x = util.round(util.linlin(0, 50, 1, 16, params:get("density")))
    for x = 1, 16 do
        self.device:led(x, 14, x <= density_x and 10 or 2)
    end
end

-- 64 grid LED pattern
function Grid:refresh_64()
    -- Voice triggers
    for i = 1, 16 do
        local x = ((i - 1) % 8) + 1
        local y = math.floor((i - 1) / 8) + 1
        local activity = self.voice:get_activity(i)
        local brightness = activity > 0 and 15 or 4

        if self.voice_states[i] then
            brightness = 15
        end

        self.device:led(x, y, brightness)
    end

    -- Utility indicators
    self.device:led(1, 8, self.voice.continuous_mode and 15 or 4)
    self.device:led(8, 8, 8)
end

-- Cleanup
function Grid:cleanup()
    if self.refresh_clock then
        clock.cancel(self.refresh_clock)
    end
    if self.device then
        self.device:all(0)
        self.device:refresh()
    end
end

return Grid
