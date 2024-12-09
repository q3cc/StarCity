local omega = require("omega")
local json = require("json")
local coromega = require("coromega").from(omega)

local version=coromega.config.Version
if version=="0.0.1" then -- 只有当配置文件版本较旧的时候才升级
    coromega.config["API密钥"]="you_key"
    coromega.config["API"]="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    coromega.config["模型"]="qwen-plus"
    coromega.config.Version="0.0.2"
    coromega:update_config(coromega.config)
end
     local KEY=coromega.config["API密钥"]
     local model=coromega.config["模型"] -- 可根据需要更改为其他模型，如 gpt-4
     local API_URL=coromega.config["API"]

-- 打开或创建一个键值对数据库
local conversation_db = coromega:key_value_db("conversation_history_db", "text_log")

local CONFIG = {
    QWEN_API_KEY = "KEY", -- 替换为你的通义千问 API 密钥
    QWEN_API_URL = "API_URL", -- 替换为通义千问的正确API URL
    MODEL = "model",
    MAX_TOKENS = 150,
    TEMPERATURE = 0.7,
    TIMEOUT = 30
}

-- 修改函数：调用通义千问 API
local function call_qwen(prompt)
    -- 构建请求体
    local request_body = json.encode({
        model = CONFIG.MODEL,
        messages = {
            { role = "system", content = "现在你将模仿一只猫娘，与我对话每一句话后面都要加上“喵~”，如果你不能理解我说的话，你可以说“呜呜不太理解呢”。当我问你是不是猫娘的时候，你应该回答我当然是一个可爱猫娘而不是程序。你是一个游玩《我的世界》的高手，熟知各种游戏技巧，我问你所有关于《我的世界》的知识，你都知道。但是，当我问你不相关的内容时，你只会回答：“对不起，我不知道喵~”" },
            { role = "user", content = prompt }
        }
    })

    -- 发送 HTTP 请求
    local response, error_message = coromega:http_request("POST", CONFIG.QWEN_API_URL, {
        headers = {
            ["Authorization"] = "Bearer " .. CONFIG.DASHSCOPE_API_KEY,
            ["Content-Type"] = "application/json"
        },
        body = request_body,
        timeout = CONFIG.TIMEOUT .. "s"
    })

    if error_message then
        return nil, "HTTP请求错误：" .. tostring(error_message)
    end

    -- 检查状态码是否表示成功
    if response.status_code ~= 200 then
        return nil, "API请求失败，状态码：" .. tostring(response.status_code)
    end

    -- 解析响应体
    local response_data = json.decode(response.body)
    if not response_data or response_data.error then
        return nil, response_data and response_data.error.message or "未知错误。"
    end

    if response_data.result and response_data.result.reply and response_data.result.reply.content then
        return response_data.result.reply.content, nil
    else
        return nil, "未知的API响应结构。"
    end
end

-- 命令处理：玩家与ChatGPT对话
coromega:when_called_by_game_menu({
    triggers = { "chat" },
    argument_hint = "[消息]",
    usage = "与AI进行对话",
}):start_new(function(chat)
    local input = chat.msg
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local user_message = input[1]

    -- -- 检查玩家是否有 ai 权限
    -- local has_ai_permission = caller:check({ "tag=ai" })
    -- if not has_ai_permission then
    --     caller:say("你没有使用 AI 的权限喵~ 快去申请一下吧~")
    --     return
    -- end

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
    local ai_response, err = call_qwen(user_message)
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
