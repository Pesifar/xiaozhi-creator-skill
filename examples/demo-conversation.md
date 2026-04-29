# Xiaozhi Creator Skill 示例对话

以下示例用于演示 skill 的典型调用路径。

## 示例 0：手机号登录获取 JWT token

用户：
我还没有 token，帮我用手机号 +8613537280181 登录小智。

助手（执行思路）：
1. 使用内置脚本：`bash bin/xiaozhi-login.sh +8613537280181`。
2. 脚本会按顺序：
   - `GET /api/auth/captcha`：保存 cookie jar 与图形验证码图片，自动调用系统图片查看器。
   - 提示用户输入图形验证码 → `POST /api/auth/send-code`（请求 cookie 必须带上 `captcha=...`）。
   - 提示用户输入短信验证码 → `POST /api/auth/phone-login`，返回 `token` 与 `data` 用户信息。
3. 脚本将 `token` 与用户信息保存到 `.xiaozhi-auth/token.json`（已 `.gitignore`），后续 API 调用复用。
4. 在对话中只展示 token 的掩码（首/尾 4 位 + `...`），不要明文外泄。

助手（结果模板）：
- operation: phone_login
- status: success
- key_ids: userId=230810, telephone=+86135****0181, role=admin
- token_preview: abcd...wxyz
- next_step: 已保存 token 到 `.xiaozhi-auth/token.json`，可继续执行 `get_agent_list` 或 `create_agent`。

## 示例 1：创建智能体

用户：
请帮我创建一个智能体，名字叫“客服小智”，助手名“阿智”，模型先用 qwen。

助手（执行思路）：
1. 先调用 `GET /api/roles/model-list`，确认 `qwen` 在可用模型中。
2. 组装创建参数并调用 `POST /api/agents`。
3. 返回创建结果中的 `agent_id`。

助手（结果模板）：
- operation: create_agent
- status: success
- key_ids: agent_id=123456
- next_step: 如需更细配置，请继续执行 update_agent_config。

## 示例 2：更新智能体配置

用户：
把 123456 这个智能体语速改成 fast，音调改成 2，角色介绍更新一下。

助手（执行思路）：
1. 用完整配置体调用 `POST /api/agents/123456/config`。
2. 若失败，按错误码给出修复建议（如 `CHARACTER_LENGTH_LIMIT`）。
3. 提醒“更新后需要重启设备生效”。

助手（结果模板）：
- operation: update_agent_config
- status: success
- key_ids: agent_id=123456
- next_step: 请重启该智能体绑定设备使配置生效。

## 示例 3：添加设备到智能体

用户：
把验证码 778899 这个设备加到 123456 号智能体。

助手（执行思路）：
1. 调用 `POST /api/agents/123456/devices`，请求体 `{ "verificationCode": "778899" }`。
2. 成功后返回设备信息中的 `device_id` 和 `serial_number`。

助手（结果模板）：
- operation: add_device
- status: success
- key_ids: agent_id=123456, device_id=600608
- next_step: 可调用 get_device_list 验证设备在线状态。

## 示例 4：获取音色列表

用户：
我想给智能体换个女声，先给我看可用音色。

助手（执行思路）：
1. 调用 `GET /api/user/tts-list` 获取可选音色列表。
2. 返回音色标识与展示名称，提示用户选择用于 `tts_voice`。

助手（结果模板）：
- operation: get_tts_voice_list
- status: success
- key_ids: none
- next_step: 请选择一个 `tts_voice`，我将用于创建或更新智能体配置。

## 示例 5：查询历史对话

用户：
帮我查一下最近几条历史对话记录。

助手（执行思路）：
1. 要求用户提供必填 `startDate`（格式 `YYYY-mm-dd`），按需补充 `endDate`。
2. 调用 `GET /api/chats/list` 查询历史对话。
3. 按时间倒序整理并返回会话摘要（`id`、时间、`chat_summary.title`、`msg_count`）。

助手（结果模板）：
- operation: get_chat_history_list
- status: success
- key_ids: none
- next_step: 告诉我要查看的会话ID（id），我可以继续帮你展开详细消息。

## 示例 6：MCP 创建使用（生成接入 token）

用户：
帮我给 1758836 这个智能体生成 MCP 接入地址。

助手（执行思路）：
1. 调用 `POST /api/agents/1758836/generate-mcp-endpoint-token`。
2. 从返回值读取 `token`。
3. 拼接为 `wss://api.xiaozhi.me/mcp/?token=<TOKEN>` 并返回给用户。
4. 提醒在控制台智能体配置页右下角 `MCP接入点` 可查看在线状态和可用工具。
5. 提醒工具参数命名清晰、返回 JSON 简洁（建议 <= 1024 字符）。

助手（结果模板）：
- operation: generate_mcp_endpoint_token
- status: success
- key_ids: agent_id=1758836
- next_step: 使用返回的 `wss` 地址连接 MCP 客户端，并优先用简单工具做连通性验证。

## 示例 7：MCP 使用规范提醒

用户：
我已经接好了 MCP，帮我总结一下上线前要检查什么。

助手（结果模板）：
- operation: mcp_preflight_check
- status: success
- key_ids: agent_id=1758836
- next_step: 请逐项确认：工具名/参数名语义清晰、函数注释完整、日志用 logger、返回值精简、连接数可控。

## 示例 8：用户提供接入点，随时启用 MCP

用户：
我已经有接入点地址了，帮我直接启用 MCP 并接到这个智能体。

助手（执行思路）：
1. 读取用户提供的 `mcp_endpoint`，不再重复申请 token。
2. 提供桥接运行命令：
   - `export MCP_ENDPOINT=<user_endpoint>`
   - `python mcp_pipe.py calculator.py`
3. 返回启用结果和连通性测试建议。

助手（结果模板）：
- operation: mcp_enable
- status: success
- key_ids: agent_id=1758836
- next_step: 先执行一条简单计算请求，确认工具调用已被智能体正确路由。

## 示例 9：更新 MCP 服务并保持接入

用户：
我更新了 calculator 的代码，帮我把 MCP 服务更新到智能体侧。

助手（执行思路）：
1. 使用当前 `MCP_ENDPOINT` 保持接入地址不变。
2. 重启桥接进程以加载新代码（先起新进程再停旧进程更稳妥）。
3. 若重连失败，再执行 token 刷新并更新 endpoint。

助手（结果模板）：
- operation: mcp_update
- status: success
- key_ids: agent_id=1758836
- next_step: 运行 1-2 条回归指令（如计算与随机数）确认工具行为正常。

## 示例 10：只提供脚本文件，接入为 MCP 服务

用户：
我只有一个 `weather.py`，帮我接入成 MCP 服务并同步到智能体。

助手（执行思路）：
1. 读取用户提供的脚本文件，按单服务模式启动。
2. 使用当前 `MCP_ENDPOINT` 执行：
   - `export MCP_ENDPOINT=<endpoint>`
   - `python vendor/mcp-project/mcp_pipe.py weather.py`
3. 返回服务启用结果并提示做首条工具调用测试。

助手（结果模板）：
- operation: mcp_add_service
- status: success
- key_ids: agent_id=1758836
- next_step: 调用一次 weather 工具确认模型可见并可执行。

## 示例 11：一次接入多个 MCP 服务并同步智能体

用户：
我有 `calculator.py`、`weather.py`、`mail.py` 三个脚本，帮我一起接入到同一个智能体。

助手（执行思路）：
1. 将三个服务登记到 `vendor/mcp-project/mcp_config.json` 并启用。
2. 运行 `python vendor/mcp-project/mcp_pipe.py` 启动所有已启用服务。
3. 返回已同步服务列表，提示进行多工具连通性验证。

助手（结果模板）：
- operation: mcp_add_services_batch
- status: success
- key_ids: agent_id=1758836
- next_step: 依次执行 calculator/weather/mail 三个工具的 smoke test。

## 示例 12：使用内置本地工程快速启用

用户：
不要再下载 GitHub 了，直接用本地项目帮我把 MCP 接上智能体。

助手（执行思路）：
1. 使用仓库内置路径 `vendor/mcp-project`，不再执行下载步骤。
2. 初始化本地环境并安装依赖：
   - `bash bin/mcp-local-prepare.sh`
3. 调用封装脚本快速启动：
   - `bash bin/mcp-local-enable.sh <MCP_ENDPOINT> vendor/mcp-project/calculator.py`

助手（结果模板）：
- operation: mcp_enable
- status: success
- key_ids: agent_id=1758836
- next_step: 发送一条计算请求验证工具连通性与响应速度。

