local omega = require("omega")
local json = require("json")
local coromega = require("coromega").from(omega)

local version = coromega.config.Version
if version == "0.0.1" then
    -- coromega.config["API密钥"] = "you_key"
    coromega.config["API"] = "https://api.j8.wiki/v1/chat/completions"
    coromega.config["模型"] = "gpt-4o-mini"
    coromega.config.Version = "0.0.2"
    coromega:update_config(coromega.config)
end

local API_URL = coromega.config["API"]
local model = coromega.config["模型"]

-- 打开或创建一个键值对数据库
local conversation_db = coromega:key_value_db("GPT_conversation_history_db", "text_log")
local key_db = coromega:key_value_db("GPT_user_keys_db", "text_log") -- 用于存储用户的 API 密钥

local function call_chatgpt(prompt, user_key)
    local request_body = json.encode({
        model = model,
        messages = {
            { role = "system", content = "现在你将模仿一只猫娘，与我对话每一句话后面都要加上“喵~”，如果你不能理解我说的话，你可以说“呜呜不太理解呢”。当我问你是不是猫娘的时候，你应该回答我当然是一个可爱猫娘而不是程序。你是一个游玩《我的世界》的高手，熟知各种游戏技巧，我问你所有关于《我的世界》的知识，你都知道。但是，但我问你不相关的内容时，你只会回答：”对不起，我不知道喵~”" },
            { role = "user", content = prompt }
        },
        max_tokens = 150,
        temperature = 0.7
    })

    local response, err = coromega:http_request("POST", API_URL, {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. user_key
        },
        body = request_body,
        timeout = "30s"
    })

    if err then
        return nil, "HTTP 请求错误：" .. tostring(err)
    end

    local response_data = json.decode(response.body)
    if not response_data then
        return nil, "解析响应失败。"
    end

    if response_data.choices and response_data.choices[1] and response_data.choices[1].message and response_data.choices[1].message.content then
        return response_data.choices[1].message.content, nil
    else
        if response_data.error and response_data.error.message then
            return nil, "OpenAI API 错误：" .. response_data.error.message
        end
        return nil, "未知的 API 响应结构。"
    end
end

-- 命令处理：玩家与ChatGPT对话
coromega:when_called_by_game_menu({
    triggers = { "ai", "gpt" },
    argument_hint = "[消息]",
    usage = "与 AI 进行对话",
}):start_new(function(chat)
    local input = chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local user_message = input[1]

    -- 调用OpenAI的ChatGPT API


    -- -- 检查玩家是否有 ai 权限
    -- local has_ai_permission = caller:check({ "tag=ai" })
    -- if not has_ai_permission then
    --     caller:say("你没有使用 AI 的权限喵~ 快去申请一下吧~")
    --     return
    -- end

    -- 检查用户是否绑定了 API 密钥
    local user_key = key_db:get(caller_name)
    if not user_key then
        caller:say("你没有绑定 Key 哦，使用命令 ’/tell @a[tag=omega_bot] 绑定key 你的key‘ 命令进行绑定吧~")
        return
    end

    -- 初始化对话历史
    if not caller.conversation_history then
        local stored_history = conversation_db:get(caller_name)
        if stored_history then
            caller.conversation_history = json.decode(stored_history)
        else
            caller.conversation_history = {}
        end
    end

    -- 如果玩家没有提供消息，则提示输入
    if not user_message or user_message == "" then
        user_message = caller:ask("请输入你想与 AI 交流的内容：")
        if not user_message or user_message == "" then
            caller:say("消息不能为空。")
            return
        end
    end

    -- 将用户消息添加到对话历史
    table.insert(caller.conversation_history, { role = "user", content = user_message })

    -- 保留最近的 3 条对话
    if #caller.conversation_history > 6 then
        table.remove(caller.conversation_history, 1)
        table.remove(caller.conversation_history, 1)
    end

    -- 存储对话历史到数据库
    conversation_db:set(caller_name, json.encode(caller.conversation_history))

    -- 通知玩家请求正在处理中
    caller:say("AI 正在思考，请稍候...")

    -- 调用ChatGPT API
    local ai_response, err = call_chatgpt(user_message, user_key)
    if ai_response then
        -- 将AI的回复添加到对话历史
        table.insert(caller.conversation_history, { role = "assistant", content = ai_response })

        -- 存储更新后的对话历史到数据库
        conversation_db:set(caller_name, json.encode(caller.conversation_history))

        -- 发送AI的回复给玩家
        caller:say("AI : " .. ai_response)
    else
        -- 发送错误信息给玩家
        caller:say("AI 请求失败：" .. tostring(err))
    end
end)

-- 绑定用户 API 密钥的命令
coromega:when_called_by_game_menu({
    triggers = { "bind_key", "绑定key" },
    argument_hint = "[你的key]",
    usage = "绑定你的 API 密钥",
}):start_new(function(chat)
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local user_key = chat.msg[1]

    while not user_key or user_key == "" do
        user_key = caller:ask("请输入你的 API 密钥：")
        if not user_key or user_key == "" then
            caller:say("API 密钥不能为空")
        end
    end

    -- 保存用户的 API 密钥到数据库
    key_db:set(caller_name, user_key)
    caller:say("你的 API 密钥已成功绑定！")
end)

-- 初始化插件
coromega:run()
