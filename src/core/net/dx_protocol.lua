local bit = require "bit"
local ffi = require "ffi"

local byte = string.byte
local char = string.char
local sub = string.sub
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local ffi_new = ffi.new
local ffi_string = ffi.string

local _M = {}

--[[ 协议格式（二进制）：
    HEADER(6bytes):
     length(4bytes,无符号):剩余长度
     version(1byte):协议的版本号
     flags(1byte):协议标志位（保留）
    PAYLOAD:
     payload(允许为空)
    包体总长度(4 + length)
--]]
local VER_1 = 0x01

function _M.recv_pack(sock)

    -- 获取header
    local data, err = sock:receive(6)
    if not data then
        return nil, "failed to receive the header: " .. (err or "")
    end
    local len1, len2, len3, len4, ver, flags = byte(data, 1, 6)
    -- 判断协议版本号
    if band(ver, VER_1) ~= VER_1 then
        return nil, "recv_pack dx protocol version error"
    end
    -- 计算剩余长度
    local remain_len = bxor(lshift(len1, 24), bxor(lshift(len2, 16), bxor(lshift(len3, 8), len4)))
    if remain_len < 2 then
        return nil, "dx protocol remain length error"
    end
    -- 计算payload长度
    local payload_len = remain_len - 2
    if payload_len == 0 then
        return {remain_len = remain_len, ver = ver, flags = flags, payload = nil}, "ok"
    end
    local payload = nil
    payload, err = sock:receive(payload_len)
    if not payload then
        return nil, "failed to receive the payload: " .. (err or "")
    end
    return {remain_len = remain_len, ver = ver, flags = flags, payload = payload}, "ok"

end

function _M.unpack(raw)
    if raw == nil or raw == "" then
        return nil, "bad raw data"
    end
    local raw_len = string.len(raw)
    if raw_len < 6 then
        return nil, "raw data length is too short"
    end
    local len1, len2, len3, len4, ver, flags = byte(raw, 1, 6)
    -- 判断协议版本号
    if band(ver, VER_1) ~= VER_1 then
        return nil, "unpack dx protocol version error"
    end
    -- 计算剩余长度
    local remain_len = bxor(lshift(len1, 24), bxor(lshift(len2, 16), bxor(lshift(len3, 8), len4)))
    if remain_len < 2 then
        return nil, "dx protocol remain length error"
    end
    -- 计算payload长度
    local payload_len = remain_len - 2
    if payload_len == 0 then
        return {remain_len = remain_len, ver = ver, flags = flags, payload = nil}, "ok"
    end

    local payload = string.sub(raw, 7, payload_len + 7)
    return {remain_len = remain_len, ver = ver, flags = flags, payload = payload}, "ok"
end

-- 参数is_raw: 是否包含了协议头
function _M.pack(payload, is_raw)
    is_raw = is_raw or false
    local raw = ""
    if payload == nil then
        payload = ""
    end
    if is_raw then
        payload = sub(payload, 7, string.len(payload))
    end
    local payload_len = string.len(payload)
    if payload_len > 0xffffffff - 2 then
        return nil, "payload too big"
    end
    local remain_len = payload_len + 2
    raw = char(band(rshift(remain_len, 24), 0x000000ff)) 
        .. char(band(rshift(remain_len, 16), 0x000000ff))
        .. char(band(rshift(remain_len, 8), 0x000000ff))
        .. char(band(remain_len, 0x000000ff))
        .. char(VER_1) .. char(0x00) .. payload
    return raw, "ok"
end

return _M