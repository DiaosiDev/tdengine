--room.lua
--Created by wugd
--桌子类

--创建类模板
DESK_CLASS = class()
DESK_CLASS.name = "DESK_CLASS"

--构造函数
function DESK_CLASS:create(room, idx)
    self.room = room
    self.idx = idx
    --rid=wheel, 玩家所在的位置
    self.users = {}
    --玩家所坐的位置
    self.wheels = {{}, {}, {}}
end

function DESK_CLASS:time_update()

end

function DESK_CLASS:is_full_user()
    return true
end

function DESK_CLASS:get_user_count()
    return sizeof(self.users)
end

function DESK_CLASS:get_empty_wheel()
    for idx,v in ipairs(self.wheels) do
        if not is_rid_vaild(v.rid) then
            return idx
        end 
    end
    return nil
end

function DESK_CLASS:is_empty()
    for idx,v in ipairs(self.wheels) do
        if is_rid_vaild(v.rid) then
            return false
        end 
    end
    return true
end

function DESK_CLASS:user_enter(user_rid)
    local idx = self:get_empty_wheel()
    if not idx then
        return -1
    end
    self.users[user_rid] = { idx = idx}
    self.wheels[idx] = {rid = user_rid, is_ready = 0}

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_enter_desk", {rid = user_rid, idx = idx, info = self.room:get_base_info_by_rid(user_rid)})
    return 0
end

function DESK_CLASS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end
    self.wheels[user_data.idx] = {}
    self:broadcast_message(MSG_ROOM_MESSAGE, "success_leave_desk", {rid = user_rid, idx = idx})
    return 0
end


-- 广播消息
function DESK_CLASS:broadcast_message(msg, ...)

    local size = sizeof(self.users)
    local msg_buf = pack_message(msg, ...)

    if not msg_buf then
        trace("广播消息(%d)打包消息失败。\n", msg)
        return
    end

    -- 遍历该房间的所有玩家对象
    for rid, _ in pairs(self.users) do
        self.room:send_rid_raw_message(rid, {}, msg_buf)
    end

    del_message(msg_buf)
end

function DESK_CLASS:op_info(user_rid, info)
    local idx = self.users[user_rid].idx
    if info.oper == "ready" then
        self.wheels[idx].is_ready = 1
        trace("玩家%s在位置%d已准备", user_rid, idx)
        self:broadcast_message(MSG_ROOM_MESSAGE, "success_user_ready", {rid = user_rid, idx = idx})
    end
end

function DESK_CLASS:is_playing(user_rid)
    return false
end

function DESK_CLASS:get_play_num()
    return 3
end