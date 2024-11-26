-- Update package paths for Lua modules
package.path = package.path .. ";/usr/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/src/luarocks-3.8.0/lua_modules/share/lua/5.1/?.lua"
package.cpath = package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/src/luarocks-3.8.0/lua_modules/lib/lua/5.1/?.so"

-- Import WebSocket and FreeSWITCH Session modules
local websocket = require("websocket")
-- local session = freeswitch.Session()

-- Log file path
local log_file_path = "/home/ubuntu/source/freeswitch/scripts/temp.log"

-- Function to log messages to a file
local function log_to_file(level, message)
    local log_file, log_err = io.open(log_file_path, "a")
    if not log_file then
        freeswitch.consoleLog("ERR", "Could not open log file: " .. tostring(log_err) .. "\n")
        return
    end
    log_file:write(string.format("[%s] %s: %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, message))
    log_file:flush()
    log_file:close()
end

log_to_file("INFO", "Starting Lua WebSocket script.")

-- Ensure the session is valid
if not session then
    log_to_file("ERROR", "Session object is nil. This script must be executed in the context of an active call.")
    return
end

log_to_file("DEBUG", "Session object initialized.")

if not session:ready() then
    log_to_file("INFO", "Session is not ready. Attempting to answer the call.")
    session:answer()
    freeswitch.msleep(500) -- Wait for 500 milliseconds
    if not session:ready() then
        log_to_file("ERROR", "Session is still not ready after answering the call.")
        return
    end
end

-- Retrieve session variables
local call_uuid = session:getVariable("uuid")
if not call_uuid or call_uuid == "" then
    log_to_file("ERROR", "Session variable 'uuid' is missing or empty.")
    return
end
log_to_file("INFO", "Call UUID: " .. tostring(call_uuid))

local agent = session:getVariable("agent")
if not agent or agent == "" then
    log_to_file("WARNING", "Session variable 'agent' is missing or empty. Defaulting to 'general'.")
    agent = "general" -- Default fallback value
end
log_to_file("INFO", "Agent: " .. tostring(agent))

-- WebSocket Connection Logic
log_to_file("INFO", "Attempting to connect to WebSocket server.")
local client = websocket.client.sync()
local ok, err = client:connect("ws://localhost:8000/", "echo-protocol")
if not ok then
    log_to_file("ERROR", "WebSocket connection failed: " .. tostring(err))
    return
end
log_to_file("INFO", "WebSocket connection successful.")

-- Sending Metadata
local metadata = string.format('{"call_uuid": "%s", "agent": "%s"}', call_uuid, agent)
log_to_file("DEBUG", "Sending metadata: " .. metadata)
local success, send_err = client:send(metadata)
if not success then
    log_to_file("ERROR", "Failed to send metadata: " .. tostring(send_err))
    client:close()
    return
end
log_to_file("INFO", "Metadata sent successfully.")

-- Receiving WebSocket Response
log_to_file("INFO", "Waiting for WebSocket response.")
local response, receive_err = client:receive()
if not response then
    log_to_file("ERROR", "Failed to receive WebSocket response: " .. tostring(receive_err))
    client:close()
    return
end
log_to_file("INFO", "Received WebSocket response: " .. response)

-- Cleanup
client:close()
log_to_file("INFO", "WebSocket connection closed.")
log_to_file("INFO", "Lua WebSocket script finished.")