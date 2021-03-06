local hive = require "hive"
local socket = require "hive.socket"
local thread = require "hive.thread"
local hive_log = require "hive.log"
local spack = string.pack
local sunpack = string.unpack

local M = {}
local Socket_M = {}


----- socks5 server gate
function M:on_create()
    if SELF_NAME ~= "agent" then
        local host = "0.0.0.0"
        local port = 9941
        local id, err = socket.listen(host, port, 
            function (client_id)
                local agent_handle = hive.create("examples/socks5.lua", "agent")
                local host, port = socket.addrinfo(client_id)
                hive_log.logf("[accept] %s:%s", host, port)
                if agent_handle then
                    hive.send(agent_handle, "resovle_agent", client_id)
                else
                    socket.close(client_id)
                end
            end)
        assert(id, err)
        hive_log.logf("socks5 listen: %s:%s", host, port)
    end
end



local function resovle(id)
    local function exit_agent()
        socket.close(id)
        hive.exit()
    end

    local function socket_read(sz)
        local data, err = socket.read(id, sz)
        if not data then
            hive.exit()
            error(err)
        elseif #data == 0 then
            hive.exit()
            error(string.format("id:%s socks5 connect break", id))
        else
            return data
        end
    end

    -- attach socket id
    socket.attach(id)

    -- client request
    local s = socket_read(2)
    local ver, nmethods = sunpack(">I1I1", s)

    -- check version
    if ver ~= 5 then
        exit_agent()
        return
    end

    -- ignore metchods
    socket_read(nmethods)

    -- response
    local resp = spack(">I1I1", 0x05, 0x00)
    local ret = socket.send(id, resp)

    -- resovle request
    s = socket_read(4)
    local ver, cmd, rsv, atyp = sunpack(">I1I1I1I1", s)
    if ver ~= 5 then
        exit_agent()
        return
    end

    -- only support connect protocol
    if cmd ~= 1 then
        exit_agent()
        return
    end

    local connect_addr
    if atyp == 1 then  -- ipv4 address
        local s = socket_read(4)
        local t = {}
        for i=1,4 do
            t[i] = string.byte(s, i)
        end
        connect_addr = string.format("%d.%d.%d.%d", t[1], t[2], t[3], t[4])

    elseif atyp == 3 then -- domain address
        local len = string.byte(socket_read(1), 1)
        connect_addr = socket_read(len)

    else  -- other address not support
        exit_agent()
        return
    end

    local connect_port = sunpack(">I2", socket_read(2))

    -- connect server
    local proxy_id, err = socket.connect(connect_addr, connect_port)
    if not proxy_id then
        exit_agent()
        error(err)
    end

    local proxy_host, proxy_port = socket.addrinfo(proxy_id)
    hive_log.logf("[connect] %s:%s from %s:%s", 
        connect_addr, connect_port,
        proxy_host, proxy_port)

    local proxy_host_t = {}
    for v in string.gmatch(proxy_host, "[^%.]+") do
        proxy_host_t[#proxy_host_t+1] = tonumber(v)
    end
    
    --  response connect success
    local s = spack(">I1I1I1I1I1I1I1I1I2",
        0x05, 0, 0, 1,
        proxy_host_t[1], proxy_host_t[2], proxy_host_t[3], proxy_host_t[4], 
        proxy_port) -- use default ip and port
    socket.send(id, s)

    local client_host, client_port = socket.addrinfo(id)
    local addrinfo_map = {
        [proxy_id] = {
            host = proxy_host,
            port = proxy_port,
        },

        [id] = {
            host = client_host,
            port = client_port,
        }
    }

    local function pipe(source_id, target_id)
        while true do
            local s, err = socket.read(source_id)
            local addr = addrinfo_map[source_id]
            if not s then
                socket.close(target_id)
                hive.exit()
                hive_log.logf("[error] %s:%s error:%s",addr.host, addr.port, err)
                return
            elseif #s == 0 then
                hive_log.logf("[break] %s:%s", addr.host, addr.port)
                socket.close(target_id)
                hive.exit()
                return
            else
                socket.send(target_id, s)
            end
        end        
    end

    -- proxy to client
    thread.run(pipe, proxy_id, id)

    -- client to proxy
    thread.run(pipe, id, proxy_id)
end


function M:resovle_agent(client_id)
    thread.run(resovle, client_id)
end


hive.start(M)
