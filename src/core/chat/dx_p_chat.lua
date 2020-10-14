-- 私聊实现
local cjson = require "cjson.safe"
local session = require "core.gate.dx_session"
local chat_proto = require "core.chat.dx_chat_protocol"
local msg_disp = require "core.gate.dx_msg_dispatcher"

local MSG_NEED_OFFLINE = chat_proto.MSG_NEED_OFFLINE

local CHAT_T_TXT   = chat_proto.CHAT_T_TXT
local CHAT_T_IMG   = chat_proto.CHAT_T_IMG
local CHAT_T_AUDIO = chat_proto.CHAT_T_AUDIO
local CHAT_T_VIDEO = chat_proto.CHAT_T_VIDEO
local CHAT_T_URL   = chat_proto.CHAT_T_URL 

local _M = {}

function _M.on_pchat(msg)
    
    if not msg._chat_type or not msg._to then
        -- chat msg err
        ngx.log(ngx.DEBUG, "on_pchat err msg: " .. cjson.encode(msg))
        return 3, nil, "pchat err msg"
    end
    if msg._chat_type ==  CHAT_T_TXT then
        local payload = msg._payload
        if not payload 
            or not payload.text 
            or type(payload.text) ~= "string" 
            or payload.text == "" then
            -- chat payload err
            ngx.log(ngx.DEBUG, "on_pchat err msg: " .. cjson.encode(msg))
            return 3, nil, "pchat err msg"
        end
        msg._time = ngx.now() * 1000

        local offline = msg._offline or 0
        local sid = session.is_online(msg._to)
        if sid then
            -- 在线
            local len, err = msg_disp.post(msg, msg._to)
            if not len then
                ngx.log(ngx.ERR, "on_pchat post msg err: " .. (err or ""))
                return 3, nil, "pchat post msg"
            end
        else
            if offline == MSG_NEED_OFFLINE then
                -- TODO: 离线消息处理
                ngx.log(ngx.DEBUG, "on_pchat offline msg: " .. cjson.encode(msg))
                
            end
            return 0, nil, "ok"
        end
        
    elseif msg._chat_type ==  CHAT_T_IMG then
    elseif msg._chat_type ==  CHAT_T_AUDIO then
    elseif msg._chat_type ==  CHAT_T_VIDEO then
    elseif msg._chat_type ==  CHAT_T_URL then
    else
        ngx.log(ngx.ERR, "on_pchat post msg _chat_type err")
        return 3, nil, "pchat post msg"
    end
    return 0, nil, "ok"
end

return _M