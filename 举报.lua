local omega = require("omega")
local json = require("json")
package.path = ("%s;%s"):format(
    package.path,
    omega.storage_path.get_code_path("LuaLoader", "?.lua")
)
local coromega = require("coromega").from(omega)
local version = coromega.config.Version

-- 构建在线玩家列表
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
        local selected_candidate = selectable_candidates[selection]
        if selected_candidate then
            return selected_candidate
        else
            return selection
        end
    end
end

coromega:when_called_by_game_menu({
    triggers = { "举报", "report", "jubao" },
    argument_hint = "[玩家名]",
    usage = "举报其他玩家",
}):start_new(function(chat)
local input =chat.msg
local caller_name = chat.name
local caller = coromega:get_player_by_name(caller_name)
local player_name = chat.msg[1]
local reason = chat.msg[2]

    
while not player_name or player_name == "" do
    local resolver = display_candidates_and_get_selection_resolver_enclosure(function(info) 
        coromega:print(info) 
    end)
    
    while not player_name or player_name == "" do
        player_name = resolver(coromega:input("请输入要举报的玩家名, 或输入序号: "))
        if not player_name or player_name == "" then
            caller:say("玩家名不能为空")
        end
    end
end

    while not reason or reason == "" do
        reason = caller:ask("请输入举报原因：")
        if not reason or reason == "" then
            caller:say("举报原因不能为空")
        end
    end

coromega:log_and_print(("玩家 %s 被玩家 %s 举报，原因: %s"):format(player_name, caller,  reason))

end)

-- 终端菜单举报
coromega:when_called_by_terminal_menu({
    triggers = { "举报", "report", "jubao" },
    argument_hint = "[玩家名]",
    usage = "举报其他玩家",
}):start_new(function(input)
    local player_name = input[1]
    
    while not player_name or player_name == "" do
        local resolver = display_candidates_and_get_selection_resolver_enclosure(function(info) 
            coromega:print(info) 
        end)
        player_name = resolver(coromega:input("请输入要举报的玩家名, 或输入序号: "))
        
        if not player_name or player_name == "" then
            coromega:print("玩家名不能为空")
        end
    end

    local reason = coromega:input("请输入举报原因: ")
    if not reason or reason == "" then
        coromega:print("举报原因不能为空")
        return
    end

    -- 处理举报逻辑（例如记录到数据库或发送消息）
    coromega:log_and_print(("玩家 %s 被举报，原因: %s"):format(player_name, reason))
end)

coromega:run()