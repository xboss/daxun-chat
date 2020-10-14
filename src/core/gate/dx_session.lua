
local _M = {}

-- 过期时间是连接keepalive的2倍
local online_expire = (ngx.ctx.keepalive or 30) * 2

-- 映射关系：client_id -> session_id
local online_table = ngx.shared.dx_online_table

local function gen_session_id(client_id)
    -- session_id的格式：version:nodeid:workerid:clientid:timestamp 暂时nodeid保留用来扩展集群，默认为0；
    local ngx_worker_id = ngx.worker.id()
    local session_id = string.format("%s:%s:%s:%s:%s", 1, 0, ngx_worker_id, client_id, ngx.now() * 1000)
    return session_id
end

function _M.online(client_id)
    -- 生成session_id
    local session_id = gen_session_id(client_id)
    ngx.ctx.session_id = session_id
    ngx.ctx.client_id = client_id

    -- 注册到online table
    local ok, err = online_table:safe_set(client_id, session_id, online_expire)
    if not ok then
        ngx.log(ngx.ERR, "online_table:set not ok. client_id: " .. client_id, err)
        return nil, err
    end

    return session_id, "ok"
end

function _M.offline(client_id)
    -- 从online table 注销
    ngx.ctx.session_id = nil
    ngx.ctx.client_id = nil
    online_table:delete(client_id)
end

function _M.kick(client_id)
    -- 从online table 注销
    online_table:delete(client_id)
end

function _M.refresh_online(client_id)
    if not client_id then
        return nil
    end
    local sid = online_table:get(client_id)
    if not sid then
        return nil
    end
    online_table:expire(client_id, online_expire)
    return sid
end

function _M.is_online(client_id)
    if not client_id then
        return nil
    end
    local sid = online_table:get(client_id)
    if not sid then
        return nil
    end
    return sid
end

return _M