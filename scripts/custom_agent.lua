package.path = package.path .. ";/usr/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/src/luarocks-3.8.0/lua_modules/share/lua/5.1/?.lua"
package.cpath = package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/src/luarocks-3.8.0/lua_modules/lib/lua/5.1/?.so"
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("dkjson")  -- Using dkjson for JSON encoding/decoding

-- Open the log file
local log_file_path = "/home/ubuntu/source/freeswitch/scripts/temp.log"
local log_file, log_err = io.open(log_file_path, "a")
if not log_file then
    error("Could not open log file for writing: " .. log_err)
end
-- Function to log messages to a file
local function log_to_file(level, message)
    log_file:write(string.format("[%s] %s: %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, message))
    log_file:flush()  -- Ensure the message is written immediately
end

log_to_file("INFO", "Starting custom_agent.lua script.\n")

if not session:ready() then
    freeswitch.consoleLog("ERR", "Session is not ready.\n")
    return
end
local call_uuid = session:getVariable("uuid")
local call_to = session:getVariable("destination_number")
log_to_file("INFO", "Call UUID: " .. call_uuid .. "\n")
local call_from = session:getVariable("caller_id_number")
log_to_file("INFO", "Call To: " .. call_to .. "\n")
log_to_file("INFO", "Call From: " .. call_from .. "\n")
-- Function to send a request to the agent server and get the response
local function get_agent_response(record_url)
    local agent_payload = json.encode({ path = record_url, callUuid = call_uuid, callTo = call_to, callFrom = call_from })
    local response_body = {}
    local res, code, response_headers, status = http.request{
        url = "http://localhost:7001/vocodeApi",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#agent_payload)
        },
        source = ltn12.source.string(agent_payload),
        sink = ltn12.sink.table(response_body)
    }
    local response_str = table.concat(response_body)
    freeswitch.consoleLog("INFO", "Agent server response: " .. response_str .. "\n")
    local response_json = json.decode(response_str)
    if code ~= 200 then
        freeswitch.consoleLog("ERR", "Failed to get response from agent server. HTTP code: " .. tostring(code) .. " Status: " .. tostring(status) .. "\n")
        return nil
    end
    if response_json and response_json.path then
        return response_json.path
    else
        freeswitch.consoleLog("ERR", "Agent server response did not contain the expected 'path' field.\n")
        return nil
    end
end

local function play_response_file(response_file_path)
    freeswitch.consoleLog("INFO", "Checking response file: " .. response_file_path .. "\n")
    local file = io.open(response_file_path, "rb")
    if not file then
        local handle = io.popen("ls -l " .. response_file_path .. " 2>&1")
        local result = handle:read("*a")
        handle:close()
        freeswitch.consoleLog("ERR", "Failed to open response audio file: " .. response_file_path .. "\nDetails: " .. result)
        return false
    end
    file:close()
    -- Adding a delay to ensure the file is ready for playback
    freeswitch.consoleLog("INFO", "Adding a small delay before playback to ensure the file is ready.\n")
    freeswitch.msleep(500)  -- Sleeps for 500 milliseconds (0.5 seconds)
    freeswitch.consoleLog("INFO", "Playing response audio file to caller: " .. response_file_path .. "\n")
    session:streamFile(response_file_path)
    return true
end

local function record_user_input()
    local record_file_path = "/home/ubuntu/backend/recordings/" .. call_uuid .. ".wav"
    local silence_threshold = 10
    local silence_secs = 5
    if not session:ready() then
        freeswitch.consoleLog("ERR", "Session is not ready.\n")
        return nil
    end
    freeswitch.consoleLog("INFO", "Starting recording to file: " .. record_file_path .. "\n")
    local record_command = string.format("%s %d %d", record_file_path, silence_secs, silence_threshold)
    session:execute("record", record_command)
    if not session:ready() then
        freeswitch.consoleLog("ERR", "Session is no longer ready after recording.\n")
        return nil
    end
    local file = io.open(record_file_path, "rb")
    if not file then
        freeswitch.consoleLog("ERR", "Failed to open the recorded file.\n")
        return nil
    end
    local file_content = file:read("*all")
    file:close()
    if file_content == "" then
        freeswitch.consoleLog("ERR", "Recorded file is empty: " .. record_file_path .. "\n")
        return nil
    end
    freeswitch.consoleLog("INFO", "Successfully recorded audio to file: " .. record_file_path .. "\n")
    return record_file_path
end

local function main_interaction()
    freeswitch.consoleLog("INFO", "Starting main interaction loop.\n")
    local response_file_path = get_agent_response("")
    -- session:waitForAnswer(20000);
    while session:ready() do
        if response_file_path ~= "" then
            if not play_response_file(response_file_path) then
                break
            end
        end
        local user_record_path = record_user_input()
        if not user_record_path then break end
        response_file_path = get_agent_response(user_record_path)
    end
end

main_interaction()

freeswitch.consoleLog("INFO", "Finished custom_agent.lua script.\n")
