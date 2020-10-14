local dx_gate = require "core.gate.dx_gate"
local session = require "core.gate.dx_session"
local chat_proto = require "core.chat.dx_chat_protocol"
local pchat = require "core.chat.dx_p_chat"
local gchat = require "core.chat.dx_g_chat"
local cjson = require "cjson.safe"

local _M = {}

local MSG_NEED_OFFLINE = chat_proto.MSG_NEED_OFFLINE

local MSG_T_PING =  chat_proto.MSG_T_PING
local MSG_T_PONG =  chat_proto.MSG_T_PONG
local MSG_T_AUTH =  chat_proto.MSG_T_AUTH
local MSG_T_PCHAT = chat_proto.MSG_T_PCHAT
local MSG_T_GCHAT = chat_proto.MSG_T_GCHAT
local MSG_T_INST =  chat_proto.MSG_T_INST

--[[
    数据包格式:
    auth payload:
    ticket: [c2s]
    uid: [s2c]
    cd: [s2c], 0:ok, 1:error
--]]
local function on_auth(msg)
    -- 验证消息格式
    local payload = msg._payload
    if not payload then
        return 2, cjson.encode(chat_proto.gen_auth({cd = 1})), "no payload"
    end
    if not payload.ticket or payload.ticket == "" then
        return 2, cjson.encode(chat_proto.gen_auth({cd = 2})), "no ticket"
    end
    -- TODO: 验票
    local uid = payload.ticket
    
    local sid = session.is_online(uid)
    if sid then
        -- TODO: 已经在线处理
        session.kick(uid)
        -- ngx.log(ngx.DEBUG, "------on_auth uid already online sid: " .. sid)
    end
    -- 上线
    session.online(uid)
    -- ack
    local ack = chat_proto.gen_auth({uid = uid, cd = 0})
    return 0, cjson.encode(ack), "ok"
end

local function on_ping(msg)
    local uid = ngx.ctx.client_id
    local pong = chat_proto.gen_pong()
    local sid = session.refresh_online(uid)
    return 0, cjson.encode(pong), "ok"
end

local function before_offline()
    -- TODO:
    -- TODO: 将未发送完的消息放入离线池
end

local function on_recv(msg_raw)
    -- 解析消息类型
    local msg = chat_proto.decode(msg_raw)
    if not chat_proto.verify_msg(msg) then
        return 1, nil, "bad chat msg format"
    end

    session.refresh_online(ngx.ctx.client_id)
    if msg._type == MSG_T_AUTH then
        return on_auth(msg)
    elseif msg._type == MSG_T_PING then
        return on_ping(msg)
    elseif msg._type == MSG_T_PONG then
    elseif msg._type == MSG_T_PCHAT then
        return pchat.on_pchat(msg)
    elseif msg._type == MSG_T_GCHAT then
        return gchat.on_gchat(msg)
    elseif msg._type == MSG_T_INST then
    else
        return 1, nil, "bad chat msg type"
    end

    return 0, nil, "ok"
end

function _M.run()
    local gate = dx_gate:new()
    gate:start_ws(on_recv, before_offline, {})
end

return _M