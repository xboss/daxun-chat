local dx_session = require "core.gate.dx_session"
local cjson = require "cjson.safe"

local _M = {}

-- 映射关系：session_id -> msg_queue
local msg_box = ngx.shared.dx_msg_box

function _M.post(msg, to_cid)
    if not to_cid then
        return nil, "client_id err"
    end
    local sid = dx_session.is_online(to_cid)
    if not sid then
        return nil, "client_id offline"
    end
    local len, err = msg_box:lpush(sid, cjson.encode(msg))
    if not len then
        ngx.log(ngx.ERR, "ngx.shared.dx_msg_box lpush: ", err)
        return nil, "ngx.shared.dx_msg_box lpush err"
    end
    return len, "ok"
end

function _M.take()
    local msg, err = msg_box:rpop(ngx.ctx.session_id)
    if not msg then
        return nil, err
    end
    return msg, "ok"
end

function _M.del_msg_box()
    msg_box:delete(ngx.ctx.session_id)
end

return _M