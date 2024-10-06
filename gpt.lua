-- 引入必要的模块
local omega = require("omega")
local json = require("json")
local coromega = require("coromega").from(omega)

-- 配置部分
local CONFIG = {
    OPENAI_API_KEY = "you_key", -- 替换为你的OpenAI API密钥
    OPENAI_API_URL = "https://oa.api2d.net/v1/chat/completions",
    MODEL = "gpt-3.5-turbo", -- 可根据需要更改为其他模型，如 gpt-4
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

    -- 发送HTTP POST请求到OpenAI API
    local response, err = coromega:http_request("POST", CONFIG.OPENAI_API_URL, {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. CONFIG.OPENAI_API_KEY
        },
        body = request_body,
        timeout = CONFIG.TIMEOUT .. "s" -- 设置超时时间
    })

    -- 错误处理
    if err then
        return nil, "HTTP请求错误：" .. tostring(err)
    end

    -- 解析响应体
    local response_data = json.decode(response.body)
    if not response_data then
        return nil, "解析响应失败。"
    end

    -- 检查API返回的结构
    if response_data.choices and response_data.choices[1] and response_data.choices[1].message and response_data.choices[1].message.content then
        return response_data.choices[1].message.content, nil
    else
        -- 如果API返回错误信息，则提取并返回
        if response_data.error and response_data.error.message then
            return nil, "OpenAI API 错误：" .. response_data.error.message
        end
        return nil, "未知的API响应结构。"
    end
end

-- 命令处理：玩家与ChatGPT对话
coromega:when_called_by_game_menu({
    triggers = { "ai", "gpt" }, -- 触发命令
    argument_hint = "[消息]", -- 参数提示
    usage = "与AI进行对话", -- 使用说明
}):start_new(function(chat)
    local input = chat.args -- 获取命令参数
    local caller_name = chat.name
    local caller = coromega:get_player_by_name(caller_name)
    local user_message = input[1]

    -- 如果玩家没有提供消息，则提示输入
    if not user_message or user_message == "" then
        user_message = caller:ask("请输入你想与AI交流的内容：")
        if not user_message or user_message == "" then
            caller:say("消息不能为空。")
            return
        end
    end

    -- 通知玩家请求正在处理中
    caller:say("AI正在思考，请稍候...")

    -- 调用ChatGPT API
    local ai_response, err = call_chatgpt(user_message)
    if ai_response then
        -- 发送AI的回复给玩家
        caller:say("AI: " .. ai_response)
    else
        -- 发送错误信息给玩家
        caller:say("AI 请求失败：" .. tostring(err))
    end
end)

-- 初始化插件
coromega:run()
