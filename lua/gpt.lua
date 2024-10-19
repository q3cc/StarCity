-- 引入必要的模块
local omega = require("omega")
local json = require("json")
local coromega = require("lua.coromega").from(omega)

local version=coromega.config.Version
if version=="0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["API密钥"]="you_key"
    coromega.config["API"]="https://oa.api2d.net/v1/chat/completions"
    coromega.config["模型"]="gpt-4o-mini"
    coromega.config.Version="0.0.2"
    coromega:update_config(coromega.config)
end
     local KEY=coromega.config["API密钥"]
     local model=coromega.config["模型"]
     local API_URL=coromega.config["API"]

-- 打开或创建一个键值对数据库
local conversation_db = coromega:key_value_db("conversation_history_db", "text_log")

-- 配置部分
local CONFIG = {
    OPENAI_API_KEY = KEY, -- 替换为你的OpenAI API密钥
    OPENAI_API_URL = API_URL,
    MODEL = model, -- 可根据需要更改为其他模型，如 gpt-4
    MAX_TOKENS = 150, -- 响应的最大token数
    TEMPERATURE = 0.7, -- 生成文本的随机性
    TIMEOUT = 30 -- HTTP请求的超时时间，单位秒
}

-- 函数：调用OpenAI的ChatGPT API
local function call_chatgpt(prompt)
    -- 构建请求体
    local request_body = json.encode({
        model = CONFIG.MODEL,
        messages = {
            { role = "system", content = "现在你将模仿一只猫娘，与我对话每一句话后面都要加上“喵~”，如果你不能理解我说的话，你可以说“呜呜不太理解呢”。当我问你是不是猫娘的时候，你应该回答我当然是一个可爱猫娘而不是程序。你是一个游玩《我的世界》的高手，熟知各种游戏技巧，我问你所有关于《我的世界》的知识，你都知道。但是，但我问你不相关的内容时，你只会回答：”对不起，我不知道喵~”" },
            { role = "user", content = prompt }
        },
        max_tokens = CONFIG.MAX_TOKENS,
        temperature = CONFIG.TEMPERATURE
    })

    local response, err = coromega:http_request("POST", CONFIG.OPENAI_API_URL, {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. CONFIG.OPENAI_API_KEY
        },
        body = request_body,
        timeout = CONFIG.TIMEOUT .. "s"
    })

    if err then
        return nil, "HTTP请求错误：" .. tostring(err)
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
        return nil, "未知的API响应结构。"
    end
end

-- 命令处理：玩家与ChatGPT对话
coromega:when_called_by_game_menu({
    triggers = { "ai", "gpt" },
    argument_hint = "[消息]",
    usage = "与AI进行对话",
}):start_new(function(chat)
    local input = chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local user_message = input[1]

    -- 检查玩家是否有 ai 权限
    local has_ai_permission = caller:check({ "tag=ai" })
    if not has_ai_permission then
        caller:say("你没有使用 AI 的权限喵~ 快去申请一下吧~")
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
        user_message = caller:ask("请输入你想与AI交流的内容：")
        if not user_message or user_message == "" then
            caller:say("消息不能为空。")
            return
        end
    end

    -- 将用户消息添加到对话历史
    table.insert(caller.conversation_history, { role = "user", content = user_message })

    -- 保留最近的 3 条对话
    if #caller.conversation_history > 6 then
        table.remove(caller.conversation_history, 1) -- 移除最早的用户消息
        table.remove(caller.conversation_history, 1) -- 移除最早的 AI 回复
    end

    -- 存储对话历史到数据库
    conversation_db:set(caller_name, json.encode(caller.conversation_history))

    -- 通知玩家请求正在处理中
    caller:say("AI正在思考，请稍候...")

    -- 调用ChatGPT API
    local ai_response, err = call_chatgpt(user_message)
    if ai_response then
        -- 将AI的回复添加到对话历史
        table.insert(caller.conversation_history, { role = "assistant", content = ai_response })

        -- 存储更新后的对话历史到数据库
        conversation_db:set(caller_name, json.encode(caller.conversation_history))

        -- 发送AI的回复给玩家
        caller:say("AI: " .. ai_response)
    else
        -- 发送错误信息给玩家
        caller:say("AI 请求失败：" .. tostring(err))
    end
end)

-- 初始化插件
coromega:run()
