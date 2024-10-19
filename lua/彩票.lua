local omega = require("omega")
local json = require("json")
package.path = ("%s;%s"):format(
    package.path,
    omega.storage_path.get_code_path("LuaLoader", "?.lua")
)
local coromega = require("lua.coromega").from(omega)
local version = coromega.config.Version

-- 生成随机字符串的函数
local function generate_random_string(length)
    local chars = "0123456789"
    local random_string = ""

    for i = 1, length do
        local rand_index = math.random(1, #chars) -- 生成随机索引
        random_string = random_string .. chars:sub(rand_index, rand_index) -- 拼接随机字符
    end

    return random_string
end

-- 使用示例
math.randomseed(os.time()) -- 初始化随机数种子
local back_name = generate_random_string(4) -- 生成长度为 4 的随机字符串