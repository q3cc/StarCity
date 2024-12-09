local omega = require("omega")
local json = require("json")
local coromega = require("coromega").from(omega)

-- 检查并升级配置文件版本
local version = coromega.config.Version or "0.0.1"
if version == "0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["API密钥"] = "your_key" -- 替换为你的API密钥
    coromega.config["API"] = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    coromega.config["模型"] = "qwen-plus"
    coromega.config["QQ群号"] = "832240220" -- 默认群号
    coromega.config["触发词"] = "*gpt" -- 默认触发词
    coromega.config.Version = "0.0.3" -- 升级到 0.0.3
    coromega:update_config(coromega.config)
end

local KEY = coromega.config["API密钥"]
local model = coromega.config["模型"]
local API_URL = coromega.config["API"]
local GROUP_ID = tonumber(coromega.config["QQ群号"]) -- 将字符串转换为数字
local TRIGGER_WORD = coromega.config["触发词"]

-- 打开或创建一个键值对数据库来存储对话历史
local conversation_db = coromega:key_value_db("conversation_history_db", "text_log")

-- 配置表
local CONFIG = {
    QWEN_API_KEY = KEY,
    QWEN_API_URL = API_URL,
    MODEL = model,
    MAX_TOKENS = 150,
    TEMPERATURE = 0.7,
    TIMEOUT = 30
}

-- 调用通义千问 API 的函数
local function call_qwen(prompt)
    local request_body = json.encode({
        model = CONFIG.MODEL,
        messages = {
            { role = "system", content = "现在你将模仿一只猫娘，与我对话每一句话后面都要加上“喵”，当我问你是不是猫娘的时候，你应该回答我当然是一个可爱猫娘而不是程序。并且，你是一个资深游戏玩家，玩过《我的世界》,《原神》等游戏，你还会各种编程代码，如Lua，Python等" },
            { role = "user", content = prompt }
        }
    })

    coromega:print("调用通义千问 API 请求体: " .. request_body)

    local response, error_message = coromega:http_request("POST", CONFIG.QWEN_API_URL, {
        headers = {
            ["Authorization"] = "Bearer " .. CONFIG.QWEN_API_KEY,
            ["Content-Type"] = "application/json"
        },
        body = request_body,
        timeout = CONFIG.TIMEOUT
    })

    if error_message then
        return nil, "HTTP请求错误：" .. tostring(error_message)
    end

    if response.status_code ~= 200 then
        return nil, "API请求失败，状态码：" .. tostring(response.status_code)
    end

    -- 解析 JSON 响应
    local response_data = json.decode(response.body)
    if not response_data or response_data.error then
        return nil, response_data and response_data.error.message or "未知错误。"
    end

    if response_data.choices and #response_data.choices > 0 and response_data.choices[1].message.content then
        return response_data.choices[1].message.content, nil
    else
        return nil, "未知的API响应结构。"
    end
end

-- 设置游戏菜单命令处理：玩家与AI进行对话
coromega:when_called_by_game_menu({
    triggers = { "chat" },
    argument_hint = "[消息]",
    usage = "与AI进行对话",
}):start_new(function(chat)
    local input = chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player(caller_name)
    local user_message = table.concat(input, " ")

    -- 初始化对话历史
    local conversation_history = {}
    local stored_history = conversation_db:get(caller_name)
    if stored_history then
        conversation_history = json.decode(stored_history)
    end

    -- 如果玩家没有提供消息，则提示输入
    if not user_message or user_message == "" then
        user_message = caller:ask("请输入你想与AI交流的内容：")
        if not user_message or user_message == "" then
            caller:say("消息不能为空。")
            return
        end
    end

    -- 将用户消息添加到对话历史
    table.insert(conversation_history, { role = "user", content = user_message })

    -- 保留最近的 6 条对话（3轮）
    if #conversation_history > 6 then
        for i = 1, (#conversation_history - 6) do
            table.remove(conversation_history, 1)
        end
    end

    -- 存储对话历史到数据库
    conversation_db:set(caller_name, json.encode(conversation_history))

    -- 通知玩家请求正在处理中
    caller:say("AI正在思考，请稍候...")

    -- 调用通义千问 API
    local ai_response, err = call_qwen(user_message)
    if ai_response then
        -- 将AI的回复添加到对话历史
        table.insert(conversation_history, { role = "assistant", content = ai_response })

        -- 存储更新后的对话历史到数据库
        conversation_db:set(caller_name, json.encode(conversation_history))

        -- 发送AI的回复给玩家
        caller:say("AI: " .. ai_response)
    else
        -- 发送错误信息给玩家
        caller:say("AI 请求失败：" .. tostring(err))
    end
end)

-- 设置终端命令处理：管理员通过终端与AI对话
coromega:when_called_by_terminal_menu({
    triggers = { "gpt" },
    argument_hint = "[消息]",
    usage = "与AI进行对话",
}):start_new(function(input)
    local user_message = table.concat(input, " ")

    -- 如果终端输入为空，则提示输入
    if not user_message or user_message == "" then
        user_message = coromega:backend_input("请输入你想与AI交流的内容：")
        if not user_message or user_message == "" then
            coromega:print("消息不能为空。")
            return
        end
    end

    -- 调用通义千问 API
    local ai_response, err = call_qwen(user_message)
    if ai_response then
        -- 输出AI的回复给终端
        coromega:print("AI: " .. ai_response)
    else
        -- 输出错误信息给终端
        coromega:print("AI 请求失败：" .. tostring(err))
    end
end)

-- 支持Q群内调用GPT
coromega:when_receive_cqhttp_message():start_new(function(message_type, message, raw_message_string)
    -- coromega:print("接收到 CQHTTP 消息: 类型: " .. message_type .. ", 内容: " .. raw_message_string)

    if message_type == "GroupMessage" then  -- 确保消息类型为 GroupMessage
        coromega:print("处理群聊消息...")

        -- 解析 JSON 格式的 raw_message_string
        local message_data = json.decode(raw_message_string)
        if not message_data then
            coromega:print("无法解析 JSON 消息: " .. raw_message_string)
            return
        end

        local group_id = tonumber(message_data.group_id)
        local sender_id = tonumber(message_data.sender.user_id)
        local message_content = message_data.raw_message

        -- coromega:print("解析到的群号: " .. tostring(group_id) .. ", 用户ID: " .. tostring(sender_id) .. ", 消息内容: " .. message_content)

        -- 触发词检查
        local trigger_pattern = "^%s*" .. TRIGGER_WORD .. "%s*(.*)$"  -- 匹配以触发词开头的消息，忽略前后空格
        local user_message = string.match(message_content, trigger_pattern)

        if user_message ~= nil then
            -- coromega:print("匹配到触发词，处理用户消息: " .. user_message)

            -- 如果用户消息为空，则提示输入
            user_message = user_message:gsub("^%s*(.-)%s*$", "%1")  -- 移除可能存在的前后空格
            if user_message == "" then
                coromega:send_cqhttp_message_to_group(GROUP_ID, "啊嘞，没有听见你说了什么。")
                return
            end

            -- 调用通义千问 API
            local ai_response, err = call_qwen(user_message)
            if ai_response then
                -- 发送AI的回复给Q群
                coromega:send_cqhttp_message_to_group(GROUP_ID, ai_response)
                coromega:print("发送 AI 回复: " .. ai_response)
            else
                -- 发送错误信息给Q群
                coromega:send_cqhttp_message_to_group(GROUP_ID, tostring(err))
                coromega:print("AI 请求失败: " .. tostring(err))
            end
        else
            -- coromega:print("未匹配到触发词，忽略消息。")
        end
    else
    --     coromega:print("非群聊消息，忽略。")
    end
end)

-- 初始化插件
coromega:run()