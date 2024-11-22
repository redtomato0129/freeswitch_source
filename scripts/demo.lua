
local api = freeswitch.API()
local json = require"cjson"

local function log(message)
    if message then
        freeswitch.consoleLog("ERR", message .. "\n")
    end
end

session:answer()

if (session:ready()) then
    local uuid = session:get_uuid()
    session:execute("set", "media_bug=media_bug")
    session.setVariable(session, "record_sample_rate", "16000")

    local event_listener = freeswitch.EventConsumer("all")
    while session:ready() do
        local event = event_listener:pop()
        if event then
            local call_state_number = event:getHeader("Channel-Call-State-Number")

            if call_state_number == "4" or call_state_number == 4 then
                api:execute("uuid_audio_fork", uuid .. " send_text 'media_bug' actived")
                log("call is actived, Just sent the text message")
                session:execute("record_session", record_url)
                break
            end
        end
        session:sleep(10)
    end

    while session:ready() do
        session:execute("playback", "silence_stream://60000")
    end

    session:hangup()
end