local omega = require("omega")
local json = require("json")
package.path = ("%s;%s"):format(
    package.path,
    omega.storage_path.get_code_path("LuaLoader", "?.lua")
)
local coromega = require("coromega").from(omega)
local version = coromega.config.Version

if version == "0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["备份区域的长宽"] = "62"
    coromega.config["备份区域的高度"] = "62"
    coromega.config["改了上面的配置记得修改源代码内的提示"] = "修改此项无效" --51行处
    coromega.config.Version = "0.0.2"
    coromega:update_config(coromega.config)
end

local testfor = coromega.config["改了上面的配置记得修改源代码内的提示"]
local height = coromega.config["备份区域的高度"]
local length = coromega.config["备份区域的长宽"]
local player_backup_log_db = coromega:key_value_db("玩家备份日志") -- 新建一个数据库用于记录备份日志

if testfor ~= "修改此项无效" then -- 帮傻子修改回去
    print("为啥不看提示捏")
    coromega.config["改了上面的配置记得修改源代码内的提示"] = "修改此项无效"
    coromega:update_config(coromega.config)
end

-- 生成随机字符串的函数
local function generate_random_string(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local random_string = "back_"

    for i = 1, length do
        local rand_index = math.random(1, #chars) -- 生成随机索引
        random_string = random_string .. chars:sub(rand_index, rand_index) -- 拼接随机字符
    end

    return random_string
end

-- 使用示例
math.randomseed(os.time()) -- 初始化随机数种子
local back_name = generate_random_string(4) -- 生成长度为 4 的随机字符串

-- 游戏内备份菜单
coromega:when_called_by_game_menu({
    triggers = { "备份", "back" },
    argument_hint = "[建筑名称]",
    usage = "自助备份大小为 62*62*62 的区域", --记得改此项
}):start_new(function(chat)
    local input =chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local set_name = input[1]
    -- 冷却
    local current_timestamp = os.time()
    local log_entry = player_backup_log_db:get(chat.name)

    if log_entry then
        local recorded_timestamp = log_entry.backup_time
        local remaining_time = recorded_timestamp - os.time()    -- 获取当前时间的时间戳
    
        if remaining_time > 0 then
            -- 返回剩余秒数
            caller:say(string.format("正在冷却中，剩余时间: %d 秒", remaining_time))
            return -- 不执行后面的代码
        end
    end

    while not set_name or set_name == "" do
        set_name = caller:ask("请输入建筑名称：")
        if not set_name or set_name == "" then
            caller:say("建筑名称不能为空")
        end
    end
    


    local player = coromega:get_player(chat.name) -- 获取玩家名称
    local pos = player:get_pos().position -- 获取玩家坐标
    local x = math.floor(pos.x)
    local y = math.floor(pos.y)
    local z = math.floor(pos.z)

    -- 设置 x1, y1, z1
    local x1 = x - length
    local y1 = y - height
    local z1 = z - length

    -- 设置 x2, y2, z2
    local x2 = x + length
    local y2 = y + height
    local z2 = z + length

    -- 构建命令字符串
    local command = string.format("execute as %s at @s run structure save %s %s %s %s %s %s disk", 
        player:name(), back_name, x1, y1, z1, x2, y2)


    -- 命令执行部分
    coromega:send_wo_cmd(command) -- get_result 为 false 或者空时没有返回值

    -- 加上 600 秒
    local new_timestamp = current_timestamp + 600

-- 保存数据到备份日志数据库
    local log_entry = {
        player_name = chat.name,
        backup_time = new_timestamp,
        command = command,
        set_name = set_name
    }
    player_backup_log_db:set(chat.name, log_entry) -- 使用玩家名作为键保存日志

end)

-- 这是debug所使用的
-- coromega:when_called_by_terminal_menu({
--     triggers = { "备份", "back" },
--     argument_hint = "[建筑名称]",
--     usage = "自助备份大小为 62*62*62 的区域", --记得改此项
-- }):start_new(function(input)
-- local name = "ahahah114514"
-- local caller_name = name
-- local caller = coromega:get_player_by_name(caller_name)
-- local set_name = input[1]
-- while not set_name or set_name == "" do
--     set_name = coromega:input("请输入建筑名称：")
--     if not set_name or set_name == "" then
--         coromega:print("建筑名称不能为空")
--     end
-- end


-- -- 冷却
-- local current_timestamp = os.time()
-- local log_entry = player_backup_log_db:get(name)

-- if log_entry then
--     local recorded_timestamp = log_entry.backup_time
--     local remaining_time = recorded_timestamp - os.time()    -- 获取当前时间的时间戳

--     if remaining_time > 0 then
--         -- 返回剩余秒数
--         coromega:print(string.format("正在冷却中，剩余时间: %d 秒", remaining_time))
--         return -- 不执行后面的代码
--     end
-- end

-- local player = coromega:get_player(name) -- 获取玩家名称
-- local pos = player:get_pos().position -- 获取玩家坐标
-- local x = math.floor(pos.x)
-- local y = math.floor(pos.y)
-- local z = math.floor(pos.z)

-- -- 设置 x1, y1, z1
-- local x1 = x - length
-- local y1 = y - height
-- local z1 = z - length

-- -- 设置 x2, y2, z2
-- local x2 = x + length
-- local y2 = y + height
-- local z2 = z + length

-- -- 构建命令字符串
-- local command = string.format("/execute as %s at @s run structure save %s %s %s %s %s %s disk", 
--     player:name(), back_name, x1, y1, z1, x2, y2)

-- -- 命令执行部分
-- coromega:send_player_cmd(command) -- get_result 为 false 或者空时没有返回值
-- local result = coromega:send_player_cmd(command, true)
-- coromega:print(json.encode(result)) -- result 的结果是一个很复杂的结构

-- -- 加上 600 秒
-- local new_timestamp = current_timestamp + 600

-- -- 保存数据到备份日志数据库
-- local log_entry = {
--     player_name = name,
--     backup_time = new_timestamp,
--     command = command,
--     set_name = set_name
-- }
-- player_backup_log_db:set(name, log_entry) -- 使用玩家名作为键保存日志

-- end)

coromega:run()
