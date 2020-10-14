local ws_server = require "resty.websocket.server"
local dx_proto = require "core.net.dx_protocol"

local _M = {}
local mt = { __index = _M }

function _M:new()
    return setmetatable({}, mt)
end

function _M:start(opts)
    opts = opts or {}
    local err = nil
    -- 启动websocket
    self.ws, err = ws_server:new {
        timeout = opts.timeout or 5000, -- 单位毫秒
        max_payload_len = opts.max_payload_len or 65535
    }

    if not self.ws then
        ngx.log(ngx.ERR, "failed to new websocket: ", err)
        return nil, "failed to new websocket: " .. (err or "")
    end

    ngx.ctx.keepalive = opts.keepalive or 10 -- 单位秒

    return self.ws, "ok"
end

function _M:send(payload)
    local raw, err = dx_proto.pack(payload)
    if not raw then
        return nil, err
    end
    local bytes = nil
    bytes, err = self.ws:send_binary(raw)
    return bytes, err
end

function _M:recv()
    local data, typ, err = self.ws:recv_frame()
    -- 如果连接损坏 退出
    if self.ws.fatal then
        ngx.log(ngx.ERR, "recv_frame fatal: ", err)
        return nil, "recv_frame fatal: " .. (err or "")
    end

    while err == "again" do
        ngx.log(ngx.DEBUG, "recv_frame again: ", err)
        local cur_data
        cur_data, typ, err = self.ws:recv_frame()
        data = (data or "") .. cur_data
    end

    if not data then
        if err then
            ngx.log(ngx.ERR, "recv_data no data ", err)
            return nil, "recv_data no data " .. (err or "")
        end
    elseif typ == "close" then
        return nil, "close"
    elseif typ == "ping" then
    elseif typ == "pong" then
    elseif typ == "continuation" then
    elseif typ == "text" then
    elseif typ == "binary" then
        -- 收到信息后的业务逻辑
        local msg = nil
        msg, err = dx_proto.unpack(data)
        if not msg then
            return nil, err
        end
        return msg, "ok"
    end
    ngx.log(ngx.ERR, "ws_server recv_data err ", err)
    return nil, "ws_server recv_data err"
end

function _M:sendclose()
    self.ws:send_close()
end

return _M