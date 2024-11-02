local omega = require("omega")
local json = require("json")
package.path = ("%s;%s"):format(
    package.path,
    omega.storage_path.get_code_path("LuaLoader", "?.lua")
)
local coromega = require("coromega").from(omega)
local version=coromega.config.Version
if version=="0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["发送的群聊"]="群聊:903420213"
    coromega.config.Version="0.0.2"
    coromega:update_config(coromega.config)
end

local Qgroup_nember=coromega.config["发送的群聊"]

local function display_candidates_and_get_selection_resolver_enclosure(disp)
    local candidates = coromega:get_all_online_players()
    local selectable_candidates = {}
    for i, candidate in pairs(candidates) do
        local idx = tostring(i)
        local name = candidate:name()
        selectable_candidates[idx] = name
        disp(string.format("%s: %s", idx, name))
    end
    return function(selection)
        return selectable_candidates[selection] or selection
    end
end

local function send_qq (player_name, player, reason)
    
    coromega:send_cqhttp_message(Qgroup_nember, send_to_qq_message)
    
end

-- 游戏菜单举报
coromega:when_called_by_game_menu({
    triggers = { "举报", "report", "jubao" },
    argument_hint = "[玩家名] [举报原因]",
    usage = "举报其他玩家，例如：举报 玩家名 举报原因",
}):start_new(function(chat)
    local input = chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local player_name = input[1]
    local reason = input[2]

    while not player_name or player_name == "" do
        local resolver = display_candidates_and_get_selection_resolver_enclosure(function(info)
            coromega:print(info)
        end)

        player_name = resolver(coromega:input("请输入要举报的玩家名, 或输入序号: "))
        if not player_name or player_name == "" then
            caller:say("玩家名不能为空")
        end
    end

    while not reason or reason == "" do
        reason = caller:ask("请输入举报原因：")
        if not reason or reason == "" then
            caller:say("举报原因不能为空")
        end
    end

    -- 可选：添加附件
    -- local attachments = {
    --     { name = "证据截图.png", data = "http://example.com/screenshot.png", encoding = "url" }
    -- }

    -- 发送邮件通知
      send_qq(player_name, caller_name, reason)

    coromega:log_and_print(string.format("玩家 %s 被玩家 %s 举报，原因: %s", player_name, caller_name, reason))
end)

-- 终端菜单举报
coromega:when_called_by_terminal_menu({
    triggers = { "举报", "report", "jubao" },
    argument_hint = "[玩家名] [举报原因]",
    usage = "举报其他玩家，例如：举报 玩家名 举报原因",
}):start_new(function(input)
    local player_name = input[1]
    local reason = input[2]

    while not player_name or player_name == "" do
        local resolver = display_candidates_and_get_selection_resolver_enclosure(function(info)
            coromega:print(info)
        end)
        player_name = resolver(coromega:input("请输入要举报的玩家名, 或输入序号: "))

        if not player_name or player_name == "" then
            coromega:print("玩家名不能为空")
        end
    end

    while not reason or reason == "" do
        reason = coromega:input("请输入举报原因：")
        if not reason or reason == "" then
            coromega:print("举报原因不能为空")
            return
        end
    end

    -- 可选：添加附件
    -- local attachments = {
    --     { name = "证据截图.png", data = "http://example.com/screenshot.png", encoding = "url" }
    -- }

    -- 发送邮件通知
    send_qq(player_name, "终端用户", reason)

    coromega:log_and_print(string.format("玩家 %s 被举报，原因: %s", player_name, reason))
end)


coromega:run()
