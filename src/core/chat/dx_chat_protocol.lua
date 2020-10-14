local cjson = require "cjson.safe"

local _M = {}

_M.VER_1 = 1
_M.MSG_NEED_OFFLINE = 1

_M.MSG_T_RESERVED = 0
_M.MSG_T_PING = 1
_M.MSG_T_PONG = 2
_M.MSG_T_AUTH = 3
_M.MSG_T_PCHAT = 4
_M.MSG_T_GCHAT = 5
_M.MSG_T_INST = 6

_M.CHAT_T_TXT = 0
_M.CHAT_T_IMG = 1
_M.CHAT_T_AUDIO = 2
_M.CHAT_T_VIDEO = 3
_M.CHAT_T_URL = 4

--[[
    数据包格式：
    _ver:[required] 1
    _type:[required] 网络消息类型；0:reserved; 1:ping; 2:pong; 3:auth; 4:private chat msg; 5:group chat msg; 6:instant msg
    _time:[required] long，时间戳，精确到毫秒，服务器收到的时间
    _id:[optional] reserved
    _from:[optional]
    _to:[optional]
    _offline:[optional] 是否存储离线消息；0:不存储；1:需要存储
    _chat_type:[optional] 聊天消息类型；0：文本；1：图片；2：音频；3：视频；4：链接
    _payload:[optional]
--]]
function _M.encode(msg_obj)
    local msg_raw = cjson.encode(msg_obj)
    return msg_raw
end

function _M.decode(msg_raw)
    local msg_obj = cjson.decode(msg_raw)
    return msg_obj
end

function _M.verify_msg(msg_obj)
    -- 必须项的check
    if not msg_obj or not msg_obj._ver
        or type(msg_obj._ver) ~= "number"
        or not msg_obj._type
        or type(msg_obj._type) ~= "number"
        or not msg_obj._time
        or type(msg_obj._time) ~= "number" then
        return nil
    end

    if msg_obj._offline then
        if type(msg_obj._offline) ~= "number" then
            return nil
        end
    end
    if msg_obj._chat_type then
        if type(msg_obj._chat_type) ~= "number" then
            return nil
        end
    end
    if msg_obj._payload then
        if type(msg_obj._payload) ~= "table" then
            return nil
        end
    end
    return true
end

function _M.gen_ping()
    local msg = {_ver = _M.VER_1, _type = _M.MSG_T_PING, _time = ngx.now() * 1000}
    return msg
end

function _M.gen_pong()
    local msg = {_ver = _M.VER_1, _type = _M.MSG_T_PONG, _time = ngx.now() * 1000}
    return msg
end

function _M.gen_auth(payload)
    local msg = {
        _ver = _M.VER_1,
        _type = _M.MSG_T_AUTH,
        _time = ngx.now() * 1000,
        _payload = payload
    }
    return msg
end

function _M.gen_priv_chat(from, to, chat_type, data)
    local msg = {
        _ver = _M.VER_1,
        _type = _M.MSG_T_PCHAT,
        _from = from,
        _to = to,
        _chat_type = chat_type,
        _time = ngx.now() * 1000,
        _payload = data
    }
    return msg
end

function _M.gen_grp_chat(from, to, chat_type, data)
    local msg = {
        _ver = _M.VER_1,
        _type = _M.MSG_T_GCHAT,
        _from = from,
        _to = to,
        _chat_type = chat_type,
        _time = ngx.now() * 1000,
        _payload = data
    }
    return msg
end

function _M.gen_inst_chat(from, to, chat_type, data)
    local msg = {
        _ver = _M.VER_1,
        _type = _M.MSG_T_INST,
        _from = from,
        _to = to,
        _chat_type = chat_type,
        _time = ngx.now() * 1000,
        _payload = data
    }
    return msg
end

return _M
