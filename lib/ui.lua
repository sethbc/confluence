-- UI System
-- Multi-page interface with visualizations

local UI = {}
UI.__index = UI

function UI.new(voice, buffer, effects, modulation)
    local ui = {
        -- Page-specific state
        selected_voice = 1,
        selected_buffer = 1,
        selected_param = 1,
        num_params = {6, 8, 6, 10, 4, 4}, -- params per page
    }

    setmetatable(ui, UI)
    return ui
end

-- Main draw dispatcher
function UI:draw(page, alt_mode, voice, buffer, effects, modulation)
    if page == 1 then
        self:draw_main(voice, modulation)
    elseif page == 2 then
        self:draw_voices(voice)
    elseif page == 3 then
        self:draw_modulation(modulation)
    elseif page == 4 then
        self:draw_effects(effects)
    elseif page == 5 then
        self:draw_buffer(buffer)
    elseif page == 6 then
        self:draw_setup()
    end
end

-- Page 1: Main - grain visualization and key parameters
function UI:draw_main(voice, modulation)
    -- Draw grain activity visualization (16 voices)
    screen.level(2)
    screen.move(0, 20)
    screen.text("VOICES")

    for i = 1, 16 do
        local x = ((i - 1) % 8) * 16
        local y = 28 + (i > 8 and 16 or 0)
        local activity = voice:get_activity(i)

        -- Draw voice indicator
        screen.level(activity > 0 and activity or 2)
        screen.rect(x, y, 14, 12)
        screen.fill()

        -- Voice number
        screen.level(activity > 5 and 0 or 15)
        screen.move(x + 3, y + 9)
        screen.text(i)
    end

    -- Key parameters display
    screen.level(15)
    screen.move(0, 58)
    screen.text("DENSITY: " .. string.format("%.1f", voice.density))

    screen.move(64, 58)
    screen.text("SIZE: " .. string.format("%.2f", voice.global_size))
end

-- Page 2: Voices - per-voice control
function UI:draw_voices(voice)
    local v = voice:get_voice(self.selected_voice)

    if not v then return end

    screen.level(15)
    screen.move(0, 20)
    screen.text("VOICE " .. self.selected_voice)

    -- Voice parameters
    local params = {
        {"Position", string.format("%.2f", v.position)},
        {"Rate", string.format("%.2f", v.rate)},
        {"Size", string.format("%.3f", v.size)},
        {"Pan", string.format("%.2f", v.pan)},
        {"Amp", string.format("%.2f", v.amp)},
        {"Source", v.source_type == 0 and "Buffer" or "Osc"},
        {"Buffer", tostring(v.buffer_id)},
        {"Envelope", ({"Sine", "Perc", "Linen", "Trap"})[v.envelope + 1]},
    }

    for i = 1, math.min(6, #params) do
        local y = 28 + (i - 1) * 7
        screen.level(i == self.selected_param and 15 or 8)
        screen.move(0, y)
        screen.text(params[i][1] .. ": " .. params[i][2])
    end

    -- Activity indicator
    local activity = voice:get_activity(self.selected_voice)
    if activity > 0 then
        screen.level(activity)
        screen.rect(120, 20, 8, 44)
        screen.fill()
    end
end

-- Page 3: Modulation - LFO visualization
function UI:draw_modulation(modulation)
    screen.level(15)
    screen.move(0, 20)
    screen.text("MODULATION")

    -- Draw 3 LFOs
    for i = 1, 3 do
        local lfo = modulation:get_lfo_info(i)
        if lfo then
            local y_base = 24 + (i - 1) * 13

            -- LFO label
            screen.level(10)
            screen.move(0, y_base)
            screen.text("LFO" .. i)

            -- Draw waveform
            screen.level(6)
            for x = 0, 90 do
                local phase = x / 90
                local test_lfo = {
                    shape = lfo.shape,
                    phase = phase,
                    depth = 1.0,
                    rate = lfo.rate,
                    last_random = lfo.last_random
                }
                local value = modulation:calculate_lfo_value(test_lfo)
                local y = y_base + 4 - (value * 4)
                screen.pixel(x + 24, y)
            end
            screen.fill()

            -- Current value indicator
            local current_x = 24 + (lfo.phase * 90)
            local current_y = y_base + 4 - (lfo.value * 4)
            screen.level(15)
            screen.circle(current_x, current_y, 1)
            screen.fill()

            -- Rate and depth
            screen.level(8)
            screen.move(118, y_base)
            screen.text_right(string.format("%.2fHz", lfo.rate))
        end
    end
end

-- Page 4: Effects - effect parameters
function UI:draw_effects(effects)
    screen.level(15)
    screen.move(0, 20)
    screen.text("EFFECTS")

    local reverb = effects:get_reverb()
    local delay = effects:get_delay()
    local filter = effects:get_filter()

    local params = {
        {"Reverb Mix", string.format("%.2f", reverb.mix)},
        {"Reverb Room", string.format("%.2f", reverb.room)},
        {"Reverb Damp", string.format("%.2f", reverb.damp)},
        {"", ""},
        {"Delay Time", string.format("%.3fs", delay.time)},
        {"Delay Fdbk", string.format("%.2f", delay.feedback)},
        {"Delay Mix", string.format("%.2f", delay.mix)},
        {"", ""},
        {"Filter Freq", string.format("%.0fHz", filter.freq)},
        {"Filter Res", string.format("%.2f", filter.res)},
    }

    for i = 1, #params do
        if params[i][1] ~= "" then
            local y = 28 + (i - 1) * 6
            screen.level(i == self.selected_param and 15 or 8)
            screen.move(0, y)
            screen.text(params[i][1])
            screen.move(120, y)
            screen.text_right(params[i][2])
        end
    end
end

-- Page 5: Buffer - sample management
function UI:draw_buffer(buffer)
    screen.level(15)
    screen.move(0, 20)
    screen.text("BUFFER " .. self.selected_buffer)

    local buf_info = buffer:get_info(self.selected_buffer)

    if buf_info then
        screen.level(10)
        screen.move(0, 30)
        screen.text("Name: " .. buf_info.name)

        screen.move(0, 38)
        if buf_info.recording then
            screen.text("RECORDING...")
        elseif buf_info.loaded then
            screen.text("Loaded")
        else
            screen.text("Empty")
        end
    end

    -- File browser
    screen.level(8)
    screen.move(0, 50)
    screen.text("File:")

    screen.level(15)
    screen.move(0, 58)
    local filename = buffer:get_current_file()
    if #filename > 21 then
        filename = "..." .. string.sub(filename, -18)
    end
    screen.text(filename)
end

-- Page 6: Setup - configuration
function UI:draw_setup()
    screen.level(15)
    screen.move(0, 20)
    screen.text("SETUP")

    screen.level(10)
    screen.move(0, 32)
    screen.text("Grid: " .. (grid.device and "connected" or "disconnected"))

    screen.move(0, 40)
    screen.text("Arc: " .. (arc.device and "connected" or "disconnected"))

    screen.move(0, 48)
    screen.text("MIDI: " .. (midi.devices and #midi.devices .. " device(s)" or "none"))
end

-- Encoder input handler
function UI:enc(n, d, page, alt_mode)
    if page == 1 then
        self:enc_main(n, d)
    elseif page == 2 then
        self:enc_voices(n, d)
    elseif page == 3 then
        self:enc_modulation(n, d)
    elseif page == 4 then
        self:enc_effects(n, d)
    elseif page == 5 then
        self:enc_buffer(n, d)
    elseif page == 6 then
        self:enc_setup(n, d)
    end
end

function UI:enc_main(n, d)
    if n == 2 then
        params:delta("density", d)
    elseif n == 3 then
        params:delta("grain_size", d)
    end
end

function UI:enc_voices(n, d)
    if n == 2 then
        self.selected_voice = util.clamp(self.selected_voice + d, 1, 16)
    elseif n == 3 then
        self.selected_param = util.clamp(self.selected_param + d, 1, 8)
    end
end

function UI:enc_modulation(n, d)
    if n == 2 then
        params:delta("lfo1_rate", d * 0.01)
    elseif n == 3 then
        params:delta("lfo1_depth", d * 0.01)
    end
end

function UI:enc_effects(n, d)
    if n == 2 then
        self.selected_param = util.clamp(self.selected_param + d, 1, 10)
    elseif n == 3 then
        -- Adjust selected parameter
        local param_names = {
            "reverb_mix", "reverb_room", "reverb_damp", "",
            "delay_time", "delay_feedback", "delay_mix", "",
            "filter_freq", "filter_res"
        }
        if param_names[self.selected_param] ~= "" then
            params:delta(param_names[self.selected_param], d * 0.01)
        end
    end
end

function UI:enc_buffer(n, d)
    if n == 2 then
        self.selected_buffer = util.clamp(self.selected_buffer + d, 1, 8)
    elseif n == 3 then
        -- Navigate files
        -- This will be implemented when buffer module is ready
    end
end

function UI:enc_setup(n, d)
    -- Configuration options
end

-- Key input handler
function UI:key(n, page, alt_mode, voice)
    if n == 3 then
        if page == 1 then
            -- Trigger random grain
            voice:trigger_random()
        elseif page == 2 then
            -- Trigger selected voice
            voice:trigger_global(self.selected_voice)
        elseif page == 5 then
            -- Load buffer or start recording
            -- To be implemented
        end
    end
end

return UI
