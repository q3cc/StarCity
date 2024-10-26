--关于本插件
--如果使用，请将内置的玩家封禁替换为 https://lumega.kukinghan.cn/lua%E6%8F%92%E4%BB%B6%E7%BC%96%E5%86%99/%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B/60%E5%88%86%E9%92%9F%E9%97%AA%E7%94%B5%E6%88%98.html
--中的，或者注释 223行-230行


local omega = require("omega")
local json = require("json")
--- @type Coromega
local coromega = require("coromega").from(omega)
-- Powered by Q3CC

print("config of 生成公告:  ",json.encode(coromega.config))
local ban_reason = "违反《游戏安全与处罚规则》"

-- local dbg = require('emmy_core')
-- dbg.tcpConnect('localhost', 9966)
-- print("waiting...")
-- for i=1,1000 do -- 调试器需要一些时间来建立连接并交换所有信息
--     -- 如果始终无法命中断点，你可以尝试将 1000 改的更大
--     print(".")
-- end
-- print("end")

local function display_candidates_and_get_selection_resolver_enclosure(disp)
    local candidates = coromega:get_all_online_players()
    local selectable_candidates = {}
    for i, candidate in pairs(candidates) do
        local idx = ("%s"):format(i)
        local name = candidate:name()
        selectable_candidates[idx] = name
        disp(("%s: %s"):format(idx, name))
    end
    return function(selection)
        local seleted_candidate = selectable_candidates[selection]
        if seleted_candidate then
            return seleted_candidate
        else
            return selection
        end
    end
end


coromega:when_called_by_terminal_menu({
    triggers = { "ggban","公告ban" },
    argument_hint = "[玩家名] [时间] [原因] [违反规定] [是否转发至QQ]",
    usage = "玩家封禁并生成公告",
}):start_new(function(input)
    local player_name = input[1]
    local ban_time = input[2]
      -- 在服务器的行为
    local reason = input[3]
    --违反条目
    local rule = input[4]
    local send_to_qq = input[5]
    while not player_name or player_name == "" do
        local resolver = display_candidates_and_get_selection_resolver_enclosure(function(info) coromega:print(info) end)
            player_name = resolver(coromega:input("请输入要封禁的玩家名, 或输入序号: "))
         if not player_name or player_name == "" then
            coromega:print("玩家名不能为空")
        end
        if not player_name or player_name == "" then
            coromega:print("玩家名不能为空")
        end
    end
    while not ban_time or ban_time == "" do
        ban_time = coromega:input("请输入要的时间: ")
        if not ban_time or ban_time == "" then
            coromega:print("封禁时间不能为空")
        end
    end
    -- 在服务器的行为
    while not reason or reason == "" do 
        reason = coromega:input("请输入要的理由: ")
        if not reason or reason == "" then
            coromega:print("封禁理由不能为空")
        end
    end
    while not rule or rule == "" do
        rule = coromega:input("请输入违反的条目: ")
        if not rule or rule == "" then
            coromega:print("违反的条目不能为空")
        end
    end
    if not send_to_qq or send_to_qq == "" then
        send_to_qq = coromega:input("请是否转发到内部QQ群（yes or no,空为转发）:")
    end

 --ggban 暖阳中的尚 1d 玩原神 1.1
    -- 玩原神
    -- 暖阳中的尚

-- 将时间转换为秒，然后再进行中文转换
    local function convertTimeToChinese(ban_time)
        -- 匹配数字和单位
        local number, unit = ban_time:match("(%d+)([a-zA-Z])")
    
        -- 定义不同单位对应的秒数
        local seconds_in_minute = 60
        local seconds_in_hour = 3600
        local seconds_in_day = 86400
    
        -- 将时间单位转换为秒
        local total_seconds = 0
        if unit == "d" then
            total_seconds = tonumber(number) * seconds_in_day
        elseif unit == "h" then
            total_seconds = tonumber(number) * seconds_in_hour
        elseif unit == "m" then
            total_seconds = tonumber(number) * seconds_in_minute
        elseif unit == "s" then
            total_seconds = tonumber(number)
        else
            return ban_time  -- 如果单位不匹配，返回原始字符串
        end
    
        -- 判断是否为永久封禁
        if total_seconds >= 3650 * seconds_in_day then
            return "永久"
        end
    
        -- 将秒数转换为年、月、周、天、小时、分钟
        local years = math.floor(total_seconds / (365 * seconds_in_day))
        total_seconds = total_seconds % (365 * seconds_in_day)
    
        local months = math.floor(total_seconds / (30 * seconds_in_day))
        total_seconds = total_seconds % (30 * seconds_in_day)
    
        local weeks = math.floor(total_seconds / (7 * seconds_in_day))
        total_seconds = total_seconds % (7 * seconds_in_day)
    
        local days = math.floor(total_seconds / seconds_in_day)
        total_seconds = total_seconds % seconds_in_day
    
        local hours = math.floor(total_seconds / seconds_in_hour)
        total_seconds = total_seconds % seconds_in_hour
    
        local minutes = math.floor(total_seconds / seconds_in_minute)
        local seconds = total_seconds % seconds_in_minute
    
        -- 根据时间长短生成相应的中文时间描述
        local time_string = ""
        if years > 0 then
            time_string = time_string .. years .. "年"
        end
        if months > 0 then
            time_string = time_string .. months .. "月"
        end
        if weeks > 0 then
            time_string = time_string .. weeks .. "周"
        end
        if days > 0 then
            time_string = time_string .. days .. "天"
        end
        if hours > 0 then
            time_string = time_string .. hours .. "小时"
        end
        if minutes > 0 then
            time_string = time_string .. minutes .. "分钟"
        end
        if seconds > 0 and time_string == "" then  -- 只有当其他单位为空时显示秒
            time_string = time_string .. seconds .. "秒"
        end
    
        return time_string
    end
    
    -- 使用函数转换时间并赋值给 ggban_time
    local ggban_time = convertTimeToChinese(ban_time)
    

    
-- -- 函数：从格式化字符串中提取实际内容
--     local function extractStringContent(formatted_string)
--         -- 使用正则表达式匹配内容
--         -- 格式为 "%!S(string=内容)"
--         local content = formatted_string:match('%%!S%s*%(%s*string%s*=%s*(.-)%)')
--         return content
--     end
    
--     -- 提取实际的字符串内容
--     local actual_string = extractStringContent(ggban_time)
    
--     -- 检查提取结果
--     if actual_string then
--         -- 将提取后的内容重新赋值给 ggban_time
--         ggban_time = actual_string
--     end

    local function generate_announcement(player_name, ban_time, reason, rule)
        local formatted_ban_time = convertTimeToChinese(ban_time)
        local ban_message
    
        if formatted_ban_time == "永久" then
            ban_message = "，永久封禁该玩家账号"
        else
            ban_message = string.format("，封禁该玩家账号 %s", formatted_ban_time)
        end
    
        return string.format(
            "【违规公示】\n\n玩家「%s」于%s在服务器内%s。此行为违反了《StarCity 游戏安全与处罚规则》 %s 的规定。\n\n经团队研究决定%s。希望各位玩家引以为戒，遵守游戏规则，维护游戏平衡。\n\nStarCity 运营团队",
            player_name,
            os.date(" %Y 年 %m 月 %d 日"),
            reason,
            rule,
            ban_message
        )
    end
    
    -- 调用函数生成公告
    local gg = generate_announcement(player_name, ban_time, reason, rule)

--发送QQ
     if send_to_qq == "yes" or send_to_qq == "" then
      coromega:send_cqhttp_message("群聊:903420213" , gg)
        end


print(gg)

print(ban_time)

    -- 调用其他插件的接口
    local result = coromega:call_other_plugin_api("/player/ban",
        { player_name = player_name, ban_time = ban_time, ban_reason = ban_reason })
    if result.ok then
        coromega:log_and_print(("调用成功: %s"):format(result.detail))
    else
        coromega:log_and_print(("调用成功: 已封禁%s,%s"):format(player_name,ggban_time))
    end
end)

coromega:run()
