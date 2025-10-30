-- Buffer Manager
-- Manages audio buffers for sample playback and recording

local Buffer = {}
Buffer.__index = Buffer

local NUM_BUFFERS = 8

function Buffer.new()
    local b = {
        num_buffers = NUM_BUFFERS,

        -- Buffer state
        buffers = {},

        -- Recording state
        recording = false,
        record_buffer = 1,
        record_duration = 10,
        record_level = 1.0,

        -- File browser
        file_path = _path.audio,
        file_list = {},
        file_index = 1,
    }

    -- Initialize buffer state
    for i = 1, NUM_BUFFERS do
        b.buffers[i] = {
            name = "empty",
            duration = 0,
            loaded = false,
            recording = false,
        }
    end

    setmetatable(b, Buffer)

    -- Initialize file list
    b:update_file_list()

    return b
end

-- Load a sample into a buffer from file path
function Buffer:load(buffer_id, file_path)
    if buffer_id < 1 or buffer_id > self.num_buffers then
        print("Invalid buffer ID: " .. buffer_id)
        return
    end

    -- Get filename for display
    local filename = file_path:match("([^/]+)$") or file_path

    print("Loading " .. filename .. " into buffer " .. buffer_id)

    -- Send load command to engine
    engine.loadBuffer(buffer_id - 1, file_path)

    -- Update buffer state
    self.buffers[buffer_id].name = filename
    self.buffers[buffer_id].loaded = true

    -- TODO: Get actual duration from buffer (would need engine callback)
    self.buffers[buffer_id].duration = 0
end

-- Load currently selected file from browser
function Buffer:load_selected(buffer_id)
    if #self.file_list > 0 and self.file_index >= 1 and self.file_index <= #self.file_list then
        local file_path = self.file_path .. self.file_list[self.file_index]
        self:load(buffer_id, file_path)
    end
end

-- Start recording to a buffer
function Buffer:start_recording(buffer_id, duration, level)
    if buffer_id < 1 or buffer_id > self.num_buffers then
        return
    end

    duration = duration or self.record_duration
    level = level or self.record_level

    print("Recording to buffer " .. buffer_id .. " for " .. duration .. "s")

    -- Send record command to engine
    engine.recordToBuffer(buffer_id - 1, duration, level)

    -- Update state
    self.buffers[buffer_id].recording = true
    self.recording = true
    self.record_buffer = buffer_id

    -- Auto-stop after duration
    clock.run(function()
        clock.sleep(duration)
        self:stop_recording(buffer_id)
    end)
end

-- Stop recording
function Buffer:stop_recording(buffer_id)
    if buffer_id < 1 or buffer_id > self.num_buffers then
        return
    end

    print("Stopped recording to buffer " .. buffer_id)

    -- Update state
    self.buffers[buffer_id].recording = false
    self.buffers[buffer_id].loaded = true
    self.buffers[buffer_id].name = "recording " .. buffer_id
    self.recording = false
end

-- Clear a buffer
function Buffer:clear(buffer_id)
    if buffer_id < 1 or buffer_id > self.num_buffers then
        return
    end

    print("Clearing buffer " .. buffer_id)

    -- Send clear command to engine
    engine.clearBuffer(buffer_id - 1)

    -- Reset state
    self.buffers[buffer_id].name = "empty"
    self.buffers[buffer_id].duration = 0
    self.buffers[buffer_id].loaded = false
end

-- Clear all buffers
function Buffer:clear_all()
    for i = 1, self.num_buffers do
        self:clear(i)
    end
end

-- Update file list from audio directory
function Buffer:update_file_list()
    self.file_list = {}
    local list = util.scandir(self.file_path)

    -- Filter for audio files
    for _, file in ipairs(list) do
        local ext = file:match("%.([^%.]+)$")
        if ext then
            ext = ext:lower()
            if ext == "wav" or ext == "aif" or ext == "aiff" or ext == "flac" then
                table.insert(self.file_list, file)
            end
        end
    end

    table.sort(self.file_list)

    if #self.file_list > 0 then
        self.file_index = util.clamp(self.file_index, 1, #self.file_list)
    end
end

-- Navigate file list
function Buffer:navigate_files(delta)
    if #self.file_list > 0 then
        self.file_index = util.clamp(self.file_index + delta, 1, #self.file_list)
    end
end

-- Get current file name
function Buffer:get_current_file()
    if #self.file_list > 0 and self.file_index >= 1 and self.file_index <= #self.file_list then
        return self.file_list[self.file_index]
    end
    return "no files"
end

-- Get buffer info
function Buffer:get_info(buffer_id)
    if buffer_id < 1 or buffer_id > self.num_buffers then
        return nil
    end
    return self.buffers[buffer_id]
end

-- Get all buffers info
function Buffer:get_all_info()
    return self.buffers
end

-- Check if recording
function Buffer:is_recording()
    return self.recording
end

-- Set record duration
function Buffer:set_record_duration(duration)
    self.record_duration = util.clamp(duration, 0.1, 60)
end

-- Set record level
function Buffer:set_record_level(level)
    self.record_level = util.clamp(level, 0.0, 2.0)
end

return Buffer
