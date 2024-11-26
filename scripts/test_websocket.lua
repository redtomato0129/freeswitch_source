local websocket = require("websocket")

-- WebSocket server URL
local websocket_url = "ws://localhost:8000/"

-- Connect to WebSocket server
local client = websocket.client.sync()
local ok, err = client:connect(websocket_url, "echo-protocol")

if not ok then
    error("Failed to connect to WebSocket server: " .. tostring(err))
end

print("Connected to WebSocket server.")
