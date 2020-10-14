-- 消息网关实现

local ws_ser = require "core.net.dx_ws_server"
local session = require "core.gate.dx_session"
local msg_disp = require "core.gate.dx_msg_dispatcher"
local semaphore = require "ngx.semaphore"

local _M = {}

local mt = { __index = _M }

function _M:new()
    local o = {}
    o.finish = true
    return setmetatable(o, mt)
end

local function is_loop(self)
    local sid = session.is_online(ngx.ctx.client_id)
    return sid and ngx.ctx.session_id and (ngx.ctx.session_id == sid) and (not self.finish)
end

local function ws_recv_loop(self, on_recv)
    repeat
        self.sema:post(1)
        local msg, err = self.dx_ws:recv()
        if not msg then
            if err ~= "close" then
                ngx.log(ngx.ERR, "failed to recv in ws_recv_loop: ", err)
            end
            break
        end

        local code = 0
        local answer = nil
        code, answer, err = on_recv(msg.payload)

        if code ~= 0 then
            break
        end

        if answer then
            local bytes = nil
            bytes, err = self.dx_ws:send(answer)
            if not bytes then
                ngx.log(ngx.ERR, "answer failed to send in ws_recv_loop: ", err)
                break
            end
        end
    until not is_loop(self)
    return
end

local function ws_push_loop(self)
    -- 先让给receive loop 执行,等待上线
    while not session.is_online(ngx.ctx.client_id) and (not self.finish) do
        self.sema:wait(1)
    end

    while is_loop(self) do
        local msg, _ = msg_disp.take()
        while msg do
            local bytes, err = self.dx_ws:send(msg)
            if not bytes then
                -- TODO: 将消息放回队列，保证消息不丢失
                ngx.log(ngx.ERR, "failed to send in ws_push_loop: ", err)
                return
            end
            msg, _  = msg_disp.take()
        end
        -- 让给receive loop 执行
        self.sema:wait(1)
    end
    return
end

--[[
    第一个参数: 函数类型，给业务层响应接收到的消息
        函数原型: code, answer, err = on_recv(msg)
        返回值: code: 0:成功,1:主动close;
               answer: 需要发送的内容
               err: 错误信息
    第二个参数: 函数类型，
        函数原型：before_offline()
        返回值: 无
    第三个参数: table类型，属性参数，websocket的启动设置参数
        原型: {
            timeout: websocket的超时参数
            max_payload_len: websocket payload最大长度
            keepalive: 本服务保活时间
        }
--]] 
function _M:start_ws(on_recv, before_offline, opts)
    opts = opts or {}
    local sema, err = semaphore.new()
    if not sema then
        ngx.log(ngx.ERR, "failed to create semaphore: ", err)
        return
    end
    self.sema = sema

    self.dx_ws = ws_ser:new()
    local ws_rt = nil
    ws_rt, err = self.dx_ws:start(opts)
    if not ws_rt then
        ngx.log(ngx.ERR, "failed to start websocket: ", err)
        return
    end

    self.finish = false

    if not ngx.ctx.ws_push_thread then
        ngx.ctx.ws_push_thread = ngx.thread.spawn(ws_push_loop, self)
    end

    ws_recv_loop(self, on_recv)

    self.finish = true

    -- 确保所有挂起的线程都获得执行的机会
    while self.sema:count() < 1 do
        self.sema:post(1)
    end
    
    before_offline()

    -- 清除消息队列里面没有发完的消息
    msg_disp.del_msg_box()

    if session.is_online(ngx.ctx.client_id) == ngx.ctx.session_id then
        -- 下线自己
        session.offline(ngx.ctx.client_id)
    end

    ngx.log(ngx.INFO, "before wait ws_push_thread")
    if ngx.ctx.ws_push_thread then
        ngx.thread.wait(ngx.ctx.ws_push_thread)
        ngx.log(ngx.INFO, "after wait ws_push_thread")
    end

end

return _M
