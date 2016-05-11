--roomd.lua
--Created by wugd
--���𷿼���صĹ���ģ��

--����ģ������
ROOM_D = {}
setmetatable(ROOM_D, {__index = _G})
local _ENV = ROOM_D

--�����б�
local room_list  = {}
local room_table = {}
local freq_table = {}

local all_room_details = {}

--�����ڲ��ӿڣ�������ĸ˳������
local function clear_doing_enter_room(entity)
    if entity:is_user() then
        entity:delete_temp("doing_enter_room")
    end
end

--���幫���ӿڣ�������ĸ˳������

-- �㲥��Ϣ
function broadcast_message(room_name, msg, ...)
    -- ȡ�ø÷����Ŷ�Ӧ�ķ������
    local room = room_list[room_name]
    if not room then
        return
    end

    -- �㲥��Ϣ
    room:broadcast_message(msg, ...)
end

--����ȫ������
function create_allroom(filename)
    room_table = IMPORT_D.readcsv_to_tables(filename)
    for k, v in pairs(room_table) do
        create_room(v)
    end
end

-- ��ȡcsv����Ϣ
function get_room_table()
    return room_table
end

--����һ������
function create_room(roomdata)
    local room_tdcls = _G[roomdata.room_tdcls]
    assert(room_tdcls ~= nil, "�������ñ������")
    local room = clone_object(room_tdcls, roomdata)
    assert(room_list[room:get_room_name()] == nil, "�ظ����÷���")
    room_list[room:get_room_name()] = room
    REDIS_D.add_subscribe_channel(room:get_listen_channel())
    REDIS_D.add_subscribe_channel(room:get_respone_channel())
    return room
end

function enter_room(entity, room_name)
    
end

--��ȡ�������
function get_room_list()
    return room_list
end

function get_room(room_name)
    return room_list[room_name]
end

--�뿪һ������
function leave_room(entity, room_name)
    local room = room_list[room_name]

    if room then
        room:entity_leave(entity)
    end

    -- ɾ����ҵ�λ����Ϣ
    entity:delete_temp("room")
end

-- ����rid��ȡroom_name
function get_room_name_by_rid(rid)
    local rid_ob = find_object_by_rid(rid)
    if not is_object(rid_ob) then
        return
    end
    return (rid_ob:query_temp("room"))
end

-- ��ȡĳ����������б�
function get_room_entity_list(room_name)
    local peo_list = {}
    local room = room_list[room_name]
    if room then
        local room_peoples = room:get_room_entity()
        local user
        local find_object_by_rid = find_object_by_rid
        local name, account, result
        local query_func
        for rid, info in pairs(room_peoples) do

            if info.ob_type == OB_TYPE_USER then
                user = find_object_by_rid(rid)
                if is_object(user) then
                    if not query_func then
                        query_func = user.query
                    end

                    name    = query_func(user, "name")
                    account = query_func(user, "account")
                    level   = query_func(user, "level")
                    result  = {
                        rid     = rid,
                        name = name,
                        account = account,
                        level = level
                    }

                    peo_list[#peo_list+1] = result
                else
                    room_peoples[rid] = nil
                end
            end
        end
    end

    return {
        ret         = #peo_list,
        result_list = peo_list,
    }
end

function update_room_entity(room_name, rid, pkg_info)

    local room = room_list[room_name]

    if not room then
        return
    end

    room:update_entity(rid, pkg_info)
end

function get_detail_room(room_name)
    local room = all_room_details[room_name or ""]
    if not room then
        return
    end

    if os.time() - (room.time or 0) > 180 then
        all_room_details[room_name] = nil
        room = nil
    end

    return room
end

function redis_room_detail(detail)
    for name,value in pairs(detail) do
        value["time"] = os.time()
        value["room_name"] = name
        all_room_details[name] = value
    end
end

function get_room_detail()
    return all_room_details
end

function cmd_room_message(room_name, user_rid, cookie, oper, info)
    local room = room_list[room_name]
    if not room then
        trace("����:%o������", room_name)
        return
    end
    local data = room:get_data_by_rid(user_rid)
    local ret = 0
    local server_id = remove_get(info, "server_id")
    if oper == "enter_room" then
        assert(is_int(server_id), "server_id must exist")
        ret = room:entity_enter(server_id, user_rid, info)
    elseif oper == "leave_room" then
        ret = room:entity_leave(user_rid, info)
    elseif oper == "enter_desk" then
        if not data then
            ret = -1
        else
            ret = room:enter_desk(user_rid, info.idx, info.enter_method)
        end
    elseif oper == "desk_op" then
        if not data then
            ret = -1
        else
            ret = room:desk_op(user_rid, info)
        end
    end

    if data then
        server_id = data.server_id
    end
    cookie = tonumber(cookie)
    if server_id and cookie and cookie ~= 0 then
        local channel = string.format(CREATE_RESPONE_SERVER_INFO, server_id, cookie)
        REDIS_D.run_publish(channel, encode_json({ret = ret}))
    end
end

function redis_dispatch_message(room_name, user_rid, cookie, msg_buf)
    local room = room_list[room_name]
    if not is_object(room) then
        LOG.err("����'%s'��Ϣ������", room_name)
        return
    end
    local name, net_msg = pack_raw_message(msg_buf)
    if not net_msg then
        LOG.err("���͸�����:'%s',�û�:'%s',��Ϣʧ��", room_name, user_rid)
        return
    end

    local name, args = net_msg:msg_to_table()
    trace("name, args = %o", {name, args})
    if name and args and ROOM_D[name] then
        ROOM_D[name](room_name, user_rid, cookie, unpack(args))
    end
    del_message(net_msg)
end

function room_detail_update(detail)

end

local function logic_cmd_room_message(user, buffer)
    local room_name = user:query_temp("room_name")
    if sizeof(room_name) == 0 then
        return
    end

    INTERNAL_COMM_D.send_room_raw_message(room_name, get_ob_rid(user), {}, buffer:get_data())
end

local function publish_room_detail()
    local result = {}
    for room_name,room in pairs(room_list) do
        local room_entity = room:get_room_entity()
        result[room_name] = { amount = sizeof(room_entity), game_type = room:get_game_type() }
    end
    REDIS_D.run_publish(SUBSCRIBE_ROOM_DETAIL_RECEIVE, encode_json(result))
end

local function user_login(user_rid, server_id)
    for room_name,room in pairs(room_list) do
        local data = room:get_data_by_rid(user_rid)
        if data then
            data.server_id = server_id
            data.last_logout_time = nil
            data.last_op_time = os.time()
            INTERNAL_COMM_D.send_server_message(server_id, user_rid, {}, RESPONE_ROOM_MESSAGE, "reconnect_user", {room_name = room_name, rid = user_rid})
        end
    end
end

local function user_logout(user_rid)
    trace("��ҵǳ� %o", user_rid)
    for _, room in pairs(room_list) do
        local data = room:get_data_by_rid(user_rid)
        trace("data = %o", data)
        if data then
            room:entity_leave(user_rid)
            -- INTERNAL_COMM_D.send_server_message(server_id, user_rid, {}, RESPONE_ROOM_MESSAGE, "reconnect_user", {room_name = room_name, rid = user_rid})
        end
    end
end

local function time_update()
    for _,room in pairs(room_list) do
        room:time_update()
    end
end

-- ģ������ִ��
function create()
    if ENABLE_ROOM then
        create_allroom("data/txt/room.txt")
        register_as_audience("ROOM_D", {EVENT_USER_OBJECT_CONSTRUCT = user_login})
        register_as_audience("ROOM_D", {EVENT_USER_CONNECTION_LOST = user_logout})
        set_timer(1000, time_update, nil, true)
    end
    
    register_msg_filter("cmd_room_message", logic_cmd_room_message)

    if SERVER_TYPE == SERVER_LOGIC or STANDALONE then
        REDIS_D.add_subscribe_channel(SUBSCRIBE_ROOM_DETAIL_RECEIVE)
    end
end

local function init()
    if ENABLE_ROOM then
        publish_room_detail()
        set_timer(60000, publish_room_detail, nil, true)
    end
end

create()
register_post_init(init)