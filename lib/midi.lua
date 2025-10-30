-- MIDI Controller
-- MIDI input for note triggers and CC parameter mapping

local Midi = {}
Midi.__index = Midi

function Midi.new(voice)
    local m = {
        voice = voice,

        -- MIDI device
        device = midi.connect(),

        -- CC mappings (CC number -> parameter)
        cc_mappings = {
            [1] = "density",          -- Mod wheel
            [7] = "grain_amp",        -- Volume
            [10] = "spread",          -- Pan
            [74] = "filter_freq",     -- Brightness/Filter
            [71] = "filter_res",      -- Resonance
            [91] = "reverb_mix",      -- Reverb
            [93] = "delay_mix",       -- Chorus/Delay
        },

        -- Note to voice mapping
        note_to_voice = {},

        -- MPE support
        mpe_enabled = false,
        mpe_voices = {},

        -- Voice allocation
        next_voice = 1,
        held_notes = {},
    }

    setmetatable(m, Midi)

    print("MIDI initialized")
    return m
end

-- Main MIDI event handler
function Midi:event(data)
    local msg = midi.to_msg(data)

    if msg.type == "note_on" then
        self:note_on(msg)
    elseif msg.type == "note_off" then
        self:note_off(msg)
    elseif msg.type == "cc" then
        self:cc(msg)
    elseif msg.type == "pitchbend" then
        self:pitchbend(msg)
    end
end

-- Note on handler
function Midi:note_on(msg)
    if msg.vel == 0 then
        self:note_off(msg)
        return
    end

    -- Allocate voice for this note
    local voice_id = self:allocate_voice(msg.note)

    if voice_id then
        -- Calculate parameters from MIDI note
        local position = (msg.note % 12) / 12  -- Position based on pitch class
        local rate = self:midi_to_rate(msg.note)
        local amp = msg.vel / 127

        -- Trigger grain
        self.voice:trigger(voice_id, position, rate, nil, nil, amp)

        -- Track note
        self.held_notes[msg.note] = voice_id
        self.note_to_voice[msg.note] = voice_id
    end
end

-- Note off handler
function Midi:note_off(msg)
    local voice_id = self.note_to_voice[msg.note]

    if voice_id then
        -- Release voice
        self.note_to_voice[msg.note] = nil
        self.held_notes[msg.note] = nil
    end
end

-- CC handler
function Midi:cc(msg)
    local param_id = self.cc_mappings[msg.cc]

    if param_id then
        -- Get parameter spec
        local param = params:lookup_param(param_id)

        if param then
            -- Normalize CC value (0-127) to parameter range
            local normalized = msg.val / 127

            -- Get parameter range
            local spec = param.controlspec
            if spec then
                local value = spec:map(normalized)
                params:set(param_id, value)
            end
        end
    end
end

-- Pitchbend handler
function Midi:pitchbend(msg)
    -- Apply pitchbend to global pitch
    -- Pitchbend range: -8192 to 8191
    local bend_amount = msg.val / 8192  -- -1 to ~1
    local pitch_shift = 2 ^ (bend_amount * 2 / 12)  -- ±2 semitones

    -- Apply to global pitch (preserve base pitch)
    local base_pitch = params:get("pitch")
    params:set("pitch", base_pitch * pitch_shift)
end

-- Allocate voice for note (round-robin)
function Midi:allocate_voice(note)
    -- Check if we already have a voice for this note
    if self.note_to_voice[note] then
        return self.note_to_voice[note]
    end

    -- Round-robin allocation
    local voice_id = self.next_voice
    self.next_voice = (self.next_voice % 16) + 1

    return voice_id
end

-- Convert MIDI note to playback rate
function Midi:midi_to_rate(note)
    -- Middle C (60) = rate 1.0
    local semitones = note - 60
    return 2 ^ (semitones / 12)
end

-- Set CC mapping
function Midi:set_cc_mapping(cc_num, param_id)
    self.cc_mappings[cc_num] = param_id
end

-- Clear CC mapping
function Midi:clear_cc_mapping(cc_num)
    self.cc_mappings[cc_num] = nil
end

-- Get current CC mappings
function Midi:get_cc_mappings()
    return self.cc_mappings
end

-- MIDI learn mode (future expansion)
function Midi:learn_cc(param_id)
    -- To be implemented: listen for next CC and map it to param_id
end

-- Cleanup
function Midi:cleanup()
    -- Clear any held notes
    self.held_notes = {}
    self.note_to_voice = {}
end

return Midi
