-- 用来做性能测试
-- 需要配置成自己的源码目录
package.path = "../src/?.lua;"
    .. "/usr/local/openresty/lualib/?.lua;"
    .. package.path

local dx_proto = require "core.net.dx_protocol"
local chat_proto = require "core.chat.dx_chat_protocol"
local cjson = require "cjson.safe"
local client = require "resty.websocket.client"
local semaphore = require "ngx.semaphore"

--- postman ---
local postman = {}
function postman:new()
    local o = {}
    o.msg_box = ngx.shared.msg_box
    return setmetatable(o, { __index = postman })
end

function postman:post(id, msg)
    local len, err = self.msg_box:lpush(id, cjson.encode(msg))
    if not len then
        ngx.log(ngx.ERR, "ngx.shared.msg_box: ", err)
        return nil, "ngx.shared.msg_box: " .. err
    end
    return len, "ok"
end

function postman:take(id)
    if id == nil then
        return nil, "id err"
    end

    local msg, err = self.msg_box:rpop(id)
    if not msg then
        return nil, err
    end
    return msg, "ok"
end

--- postman ---

--- dx_cli ---
local dx_cli = {}

function dx_cli:new()
    local o = {}
    o.is_running = false
    o.ping_thread = nil
    o.post_thread = nil
    o.send_thread = nil
    o.ws = nil
    o.ticket = nil
    o.to_id = nil
    o.keepalive = 1
    o.send_interval = 1
    o.sema = semaphore.new()
    o.postman = postman:new()
    return setmetatable(o, { __index = dx_cli })
end

function dx_cli:log(text)
    print(self.ticket .. ":" .. text)
end

function dx_cli:send(msg)
    local raw = dx_proto.pack(msg)
    assert(raw)
    local bytes, err = self.ws:send_binary(raw)
    if not bytes then
        self:log("failed to send frame: " .. err)
        -- return
    end
    self:log("send: " .. raw)
end

function dx_cli:send_loop()
    while self.is_running do
        local msg, _ = self.postman:take(self.ticket)
        while msg do
            self:send(msg)
            msg, _  = self.postman:take(self.ticket)
        end
        -- 让给receive执行
        self.sema:wait(1)
    end
end

function dx_cli:ping()
    -- {"_type":2,"_time":1602128760415,"_ver":1}
    while self.is_running do
        local ping = {
            _type = chat_proto.MSG_T_PING,
            _ver = chat_proto.VER_1,
            _time = ngx.now() * 1000
        }
        self.postman:post(self.ticket, ping)
        ngx.sleep(self.keepalive)
    end
end

function dx_cli:post_loop()
    -- {"_from":"88","_type":4,"_to":"99","_chat_type":0,"_payload":{"text":"dfasfasdf跌幅达时空裂缝。。。sdfsad"},"_ver":1,"_time":1602131323987,"_offline":0}
    -- while self.is_running do
    for i = 1, self.send_cnt do
        local content = "ttttttt" .. ngx.now()
        local msg = {
            _type = chat_proto.MSG_T_PCHAT,
            _ver = chat_proto.VER_1,
            _time = ngx.now() * 1000,
            _from = self.ticket,
            _to = self.to_id,
            _chat_type = chat_proto.CHAT_T_TXT,
            _offline = 0,
            _payload = {
                text = content
            }
        }
        self.postman:post(self.ticket, msg)
        ngx.sleep(self.send_interval)
    end
end

function dx_cli:run(ticket, keepalive, recv_cnt, send_cnt, send_interval, to, uri)
    self.ticket = ticket
    self.keepalive = keepalive
    self.recv_cnt = recv_cnt
    self.send_cnt = send_cnt
    self.send_interval = send_interval
    self.uri = uri
    self.to_id = to

    local err = nil
    self.ws, err = client:new{
        timeout = 500000, -- 单位毫秒
        max_payload_len = 65535}
    local ok = nil
    ok, err = self.ws:connect(self.uri)
    if not ok then
        self:log("failed to connect: " .. err)
        return
    end
    self:log("connected..." .. self.uri)

    self.is_running = true

    -- auth
    -- {"_payload":{"ticket":"99"},"_type":3,"_time":1602126017218,"_ver":1}
    local auth_msg = {
        _type = chat_proto.MSG_T_AUTH,
        _ver = chat_proto.VER_1,
        _time = ngx.now() * 1000,
        _payload = {ticket = self.ticket}
    }
    self:send(cjson.encode(auth_msg))
    local data = nil
    local typ = nil
    data, typ, err = self.ws:recv_frame()
    if not data then
        self:log("failed to receive the frame: " .. err)
        self.is_running = false
        -- goto close_conn
        return
    end

    local msg = nil
    msg, err = dx_proto.unpack(data)
    --  {"_payload":{"uid":"99","cd":0},"_type":3,"_time":1602126017218,"_ver":1}
    self:log(cjson.encode(msg))
    assert(msg)
    assert(msg.payload)
    local chat_msg = cjson.decode(msg.payload)
    assert(chat_msg._payload)
    assert(chat_msg._type)
    assert(chat_msg._payload.uid)
    assert(chat_msg._payload.cd)
    if chat_msg._payload.cd ~= 0 then
        self:log("auth error cd:" .. chat_msg._payload.cd)
        self.is_running = false
        -- goto close_conn
        return
    end
    self:log("auth ok " .. cjson.encode(msg))

    -- send_loop thread
    if not self.send_thread then
        self.send_thread = ngx.thread.spawn(self.send_loop, self)
    end

    -- ping thread
    if not self.ping_thread then
        self.ping_thread = ngx.thread.spawn(self.ping, self)
    end

    -- post_loop thread
    if not self.post_thread then
        self.post_thread = ngx.thread.spawn(self.post_loop, self)
    end

    -- receive data
    for i = 1, recv_cnt do
        self.sema:post(1)
        data, typ, err = self.ws:recv_frame()
        if not data then
            self:log("failed to receive the frame: " .. err)
            break
        end
        -- self:log(i .. " recv: " .. data)
    end

    
    self.is_running = false

    -- self:log("before wait ping_thread " .. type(self.ping_thread))
    if self.ping_thread then
        ngx.thread.wait(self.ping_thread)
        -- self:log("after wait ping_thread " .. type(self.ping_thread))
    end

    -- self:log("before wait post_thread " .. type(self.post_thread))
    if self.post_thread then
        ngx.thread.wait(self.post_thread)
        -- self:log("after wait post_thread " .. type(self.post_thread))
    end

    -- self:log("before wait send_thread " .. type(self.send_thread))
    if self.send_thread then
        ngx.thread.wait(self.send_thread)
        -- self:log("after wait send_thread " .. type(self.send_thread))
    end

    -- close
    local bytes = nil
    bytes, err = self.ws:send_close()
    if not bytes then
        self:log("failed to send close frame: " .. err)
    end
    self.ws:close()
end

--- dx_cli ---


-- 启动命令及参数：
-- resty clitest.lua uri ticket [to] [keepalive] [send_interval] [recv_cnt] [client_cnt]
-- 示例：resty --shdict 'msg_box 32m' -c 9998 --main-include main_conf.conf clitest.lua ws://127.0.0.1:8008/chat 1 2 1 1 10 10 1
if arg[1] == '-h' then
    print(
        [[
            resty --shdict 'msg_box 32m' -c 9998 --main-include main_conf.conf clitest.lua uri ticket [to] [keepalive] [send_interval] [recv_cnt] [send_cnt] [client_cnt]
            功能：用来做性能测试
            参数说明：
            uri: websocket地址
            ticket: 用来鉴权的票据，目前只能是数字，配合client_cnt参数，用来性能测试
            to: 如果是0表示以ticket + 1的规则自动生成；如果大于0表示指定值
            keepalive： ping命令的间隔时间，浮点类型 1表示一秒，0.5表示500ms
            send_interval: 发送频率，即时间间隔，浮点类型 1表示一秒，0.5表示500ms
            recv_cnt: 总共接受多少条消息停止
            send_cnt: 总共发送多少条消息后停止
            client_cnt: 开启多少个客户端
        ]]
    )
end
-- 获得参数
local uri = arg[1] -- or "ws://127.0.0.1:8008/chat"
local t = arg[2]
local to = arg[3] or 0
local keepalive = arg[4] or 1
local send_interval = arg[5] or 1
local recv_cnt = arg[6] or 1
local send_cnt = arg[7] or 1
local client_cnt = arg[8] or 1

assert(uri)
assert(t)


local benchmark_thread = {}
for i = t, client_cnt + t do
    local cli = dx_cli:new()
    local ticket = i
    if to == 0 then
        to = i + 1
    end
    -- benchmark thread
    if not benchmark_thread[i] then
        benchmark_thread[i] = ngx.thread.spawn(cli.run, cli, ticket, keepalive, recv_cnt, send_cnt, send_interval, to, uri)
        print("start benchmark_thread[" .. i .. "] ")
    end
end

for i = t, client_cnt + t do
    -- print("before wait benchmark_thread[" .. i .. "] " .. type(benchmark_thread[i]))
    if benchmark_thread[i] then
        ngx.thread.wait(benchmark_thread[i])
        -- print("after wait benchmark_thread[" .. i .. "] " .. type(benchmark_thread[i]))
    end
end

