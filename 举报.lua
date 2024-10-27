local omega = require("omega")
local json = require("json")

-- 设置包路径
package.path = ("%s;%s"):format(
    package.path,
    omega.storage_path.get_code_path("LuaLoader", "?.lua")
)

local coromega = require("coromega").from(omega)
local version = coromega.config.Version

-- 升级配置文件
if version == "0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["收件人邮箱1"] = "default@example.com" -- 设置默认邮箱
    coromega.config["收件人邮箱2"] = "default@example.com"
    coromega.config["收件人邮箱3"] = "default@example.com"
    coromega.config["收件人邮箱4"] = "default@example.com"
    coromega.config.Version = "0.0.2" -- 更新版本号
    coromega:update_config(coromega.config) -- 更新配置文件
end
if version == "0.0.2" then
    coromega.config["QQ群"] = "903420213"
    coromega.config.Version = "0.1.0"
    coromega:update_config(coromega.config)
end
if version == "0.1.0" then
coromega.config["app_key"] = "your_app_key_here" -- 添加 app_key
coromega.config.Version = "0.1.1"
coromega:update_config(coromega.config)
end

local app_key = coromega.config["app_key"]
local QGroup = coromega.config["QQ群"]
-- 获取收件人邮箱地址
local email_addresses = {
    coromega.config["收件人邮箱1"],
    coromega.config["收件人邮箱2"],
    coromega.config["收件人邮箱3"],
    coromega.config["收件人邮箱4"]
}

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



-- 发送邮件举报
local function send_email_report(player_name, caller_name, reason)
    local email_content = string.format(
        "玩家 %s 被玩家 %s 举报，原因: %s",
        player_name,
        caller_name,
        reason
    )


    for _, email_address in ipairs(email_addresses) do
        -- 发送邮件的请求
        local response, error_message = coromega:http_request("GET", "http://your_api_domain/?s=App.Email.Send", {
            query = {
                address = email_address,
                title = "玩家举报通知",
                content = email_content,
                app_key = app_key,
            }
        })

        if error_message then
            coromega:log_and_print("邮件发送失败: " .. error_message)
        else
            local response_data = json.decode(response.body)
            if response_data.ret == 200 and response_data.data.err_code == 0 then
                coromega:log_and_print("邮件发送成功: " .. response.body)
            else
                coromega:log_and_print("邮件发送失败: " .. response_data.data.err_msg)
            end
        end
    end
end


local function send_qq(player_name, caller_name, reason)

    local content = string.format(
        "玩家 %s 被玩家 %s 举报，原因: %s",
        player_name,
        caller_name,
        reason
    )
    coromega:send_cqhttp_message(QGroup, content)
    
end

-- 游戏菜单举报
coromega:when_called_by_game_menu({
    triggers = { "举报", "report", "jubao" },
    argument_hint = "[玩家名]",
    usage = "举报其他玩家",
}):start_new(function(chat)
    local input = chat.msg
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

    -- 发送邮件通知
    send_email_report(player_name, caller_name, reason)
    -- send_qq(player_name, caller_name, reason)

    coromega:log_and_print(("玩家 %s 被玩家 %s 举报，原因: %s"):format(player_name, caller_name, reason))
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

    -- 发送邮件通知
    send_email_report(player_name, "终端用户", reason)
    -- send_qq(player_name, "终端用户", reason)

    coromega:log_and_print(("玩家 %s 被举报，原因: %s"):format(player_name, reason))
end)

coromega:run()
