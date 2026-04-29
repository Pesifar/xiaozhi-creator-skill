主要接口

全局请求头

HTTP Authorization: Bearer <Your_Authorization_Token> // 需要用户提供 Content-Type: application/json

0. 手机号登录（获取 JWT token）

适用场景：当用户尚未持有 `Authorization` token 时，按以下三步获取。

> ⚠️ **以下三个接口都存在跨域（CORS）限制**，浏览器端的
> `fetch` / `XMLHttpRequest` 调用会被同源策略拦截：
>
> - `GET  /api/auth/captcha`
> - `POST /api/auth/send-code`
> - `POST /api/auth/phone-login`
>
> 必须在服务端 / CLI 端调用（例如 `curl`、Node `https`、Python `requests`、Go `net/http`）。
> 仓库内置 `bin/xiaozhi-login.sh` 已用 `curl` 封装完整三步，是推荐入口；
> 若要在自家后端实现，请按照下文同样的 cookie jar 处理方式自己组织请求。

0.1 获取图形验证码

GET: `/api/auth/captcha`

返回值

- 响应体：**SVG 文本**，不是位图二进制。形如：

  ```xml
  <svg xmlns="http://www.w3.org/2000/svg" width="180" height="50" viewBox="0,0,180,50">
    ...验证码字形...
  </svg>
  ```

- 响应头：
  - `Content-Type: text/html; charset=utf-8` —— ⚠️ 服务端**把 SVG 错标成了 `text/html`**。
    不要按 `Content-Type` 决定处理方式（否则会被误识别成 HTML 页面），实际响应体是合法的 SVG。
  - `Set-Cookie: captcha=captcha:<random_id>`

调用方处理要点

- **嗅探响应体**前几个字节里是否包含 `<svg` 来判断格式，不要依赖 `Content-Type`。
- 必须把响应中的 `captcha=...` Cookie 持久化到 cookie jar，否则下一步 `send-code` 会失败。
- 直接把响应体保存为 `.svg` 文件即可（无需 PNG 转码），用浏览器或 macOS Preview 打开都能渲染，不会被误标的 `text/html` 影响。
- 浏览器端 `fetch` 受 CORS 限制无法获取 `Set-Cookie`，必须服务端 / CLI 调用。
- 同一个 `captcha` Cookie 仅对接下来的一次 `send-code` 有效；输错或失效后需重新拉取。

0.2 发送短信验证码

POST: `/api/auth/send-code`

请求 Cookie（必传）

- `Cookie: captcha=captcha:<random_id>`（来自 0.1）

请求参数

```json
{
  "phone": "+8613537280181",
  "captcha_code": "图形验证码字符"
}
```

返回参数

```json
{ "success": true }
```

错误处理

- `captcha_code` 错误：重新调用 0.1 获取新验证码。
- `phone` 必须带国家区号（如 `+86`）。

0.3 手机号登录

POST: `/api/auth/phone-login`

请求参数

```json
{
  "phone": "+8613537280181",
  "code": "手机收到的短信验证码"
}
```

返回参数

```json
{
  "token": "<JWT_TOKEN>",
  "data": {
    "userId": 230810,
    "username": "用户名",
    "telephone": "+86135****0181",
    "role": "admin"
  }
}
```

后续处理

- `token` 用于后续所有接口：`Authorization: Bearer <token>`。
- `token` 属于敏感凭据，对话日志中应仅展示前/后 4 位掩码。
- `bin/xiaozhi-login.sh` 会把 `token` 与用户基本信息保存到 `.xiaozhi-auth/token.json`（已加入 `.gitignore`），并打印 `export XIAOZHI_TOKEN=...` 便于后续脚本复用。

1. 获取 智能体列表

GET: /api/agents

请求参数

| 字段 | 描述 | 类型 |
| --- | --- | --- |
| page | 页码 | int |
| pageSize | 分页大小（最大 100） | int |
| keyword | 智能体名称模糊搜索 | str |

返回参数

```json
{ "success": true, "message": "Get agents", "data": [{ "id": xxx, "user_id": xxx, "agent_name": "xxxx", // 智能体名称 "tts_voice": "zh_female_wanwanxiaohe_moon_bigtts", // 音色 "llm_model": "qwen", "assistant_name": "小智", "user_name": "主人", // 废弃 "created_at": "2025-07-17T10:03:28.000Z", // utc 时间 "updated_at": "2025-07-17T10:03:28.000Z", // utc 时间 "memory": "", // 记忆体 "character": "...", // 角色介绍 "long_memory_switch": 0, // 已废弃 "lang_code": "zh-CN", // 已废弃 "language": "zh", "tts_speech_speed": "normal", // 角色语速 "asr_speed": "normal", // 语音识别速度 "tts_pitch": 0, // 角色音调 "agent_template_id": 0, // 智能体模板ID "deviceCount": 0 }], "pagination": { "total": 3, "current": 1, "pageSize": 24, "hasMore": false } }
```

2. 模型列表

GET: /api/roles/model-list

返回参数

```json
{ "success": true, "data": { "modelList": [ {"name": "qwen", "description": "Qwen3 实时（推荐）"}, {"name": "deepseek","description": "DeepSeek V3 0324"}, {"name": "doubao-pro","description": "DouBao 1.5 Pro"}, ] }, "message": "Get model list successfully" }
```

3. 创建智能体

POST: /api/agents

请求参数

```json
{ "agent_name": "test", "assistant_name": "小智", "llm_model": "qwen", "tts_voice": "zh_female_wanwanxiaohe_moon_bigtts", // 音色 "tts_speech_speed": "normal", // 角色语速 slow normal fast "tts_pitch": 0, // 音高 范围 [-3, 3] "asr_speed": "normal", // 语音识别速度 slow normal fast "language": "zh", "character": "角色介绍...", "memory": "短期记忆体内容...", "memory_type": "SHORT_TERM", // "OFF"、"SHORT_TERM" "knowledge_base_ids": [], // 知识库ID列表 "mcp_endpoints": ["1", ...], // 官方 MCP 工具 为[]不加载任何产品mcp、为null会加载所有mcp }
```

返回参数

```json
// 成功信息 状态码 200 {"success":true,"message":"配置更新成功","data":{"id":xxx}} // 错误信息 状态码 400 { "success": false, "message": "角色介绍字数不能超过2000字", "code": "CHARACTER_LENGTH_LIMIT" }
```

4. 更新智能体

POST: /api/agents/<:智能体ID>/config

提交参数

```json
{ "agent_name": "test", "assistant_name": "小智", "llm_model": "qwen", "tts_voice": "zh_female_wanwanxiaohe_moon_bigtts", // 通过音色列表获取  "tts_speech_speed": "fast", // 角色语速 slow normal fast "tts_pitch": 3, // 音高 范围 [-3, 3] "asr_speed": "normal", // 语音识别速度 slow normal fast "language": "zh", // 见"语种列表"，如 zh/en/yue/ja/ko/... "character": "角色介绍 2000字", "memory": "记忆体内容", "memory_type": "SHORT_TERM", // "OFF"、"SHORT_TERM" "knowledge_base_ids": [], // 知识库ID列表 "mcp_endpoints": ["1", ...], // 官方 MCP 工具 为[]不加载任何产品mcp、为null会加载所有mcp }
```

返回参数

1. 成功 200

```json
{ "success": true, "message": "配置更新成功", "code": "CONFIG_UPDATE_SUCCESS" }
```

注：更新后，需要重启设备，才会生效配置

5. 设备列表

GET：/api/agents/<智能体ID>/devices

返回参数

```json
{
    "success": true,
    "message": "Get all devices",
    "data": [
        {
            "id": 1990929,
            "user_id": 230815,
            "mac_address": "fc:01:2c:c9:2b:34",
            "created_at": "2026-04-23T09:17:51.000Z",
            "updated_at": "2026-04-23T09:17:51.000Z",
            "last_connected_at": "2026-04-24T12:46:02.000Z",
            "auto_update": 1,
            "alias": null,
            "agent_id": 1753814,
            "app_version": "0.5.0",
            "board_name": "xiaozhi-xxxx",
            "serial_number": "DAI_XIAOZHI_SDK_04B349319C6276AC",
            "client_id": "xxxxx",
            "iccid": "",
            "is_auth": true,
            "online": false
        }
    ]
}
```

6. 添加设备

指定智能体ID

POST: /api/agents/<:智能体ID>/devices

```json
{ "verificationCode": "123123" }
```

返回参数

```json
{ "success": true, "message": "添加设备成功", "data": { "id": 600608, "user_id": 230810, "mac_address": "xxxx", "iccid": xxxx, "created_at": "2025-07-18T10:15:24.000Z", // utc 时间 "updated_at": "2025-07-18T10:15:24.000Z", // utc 时间 "last_connected_at": null, "auto_update": 1, "alias": null, "agent_id": xxx, "app_version": "0.0.8", "board_name": "xiaozhi-sdk-0.0.8", "serial_number": "xxx", "is_auth": true, // 设备是否商业授权 } }
```

7. 音色列表

GET: /api/user/tts-list

返回参数

```json
{"data":{"languages":["zh","en"],"tts_voices":{"zh":[{"status":1,"top":true,"voice_id":"zh_female_wanwanxiaohe_moon_bigtts","voice_name":"湾湾小何","language":"zh","created_at":"2024-12-31T16:00:00.000Z","voice_demo":"https://lf3-static.bytednsdoc.com/obj/eden-cn/lm_hz_ihsph/ljhwZthlaukjlkulzlp/portal/bigtts/湾湾小何.mp3"},{"is_beta":true,"status":1,"top":true,"voice_id":"zh_female_xiaohe_uranus_bigtts","voice_name":"湾湾小何","language":"zh","created_at":"2025-11-26T04:03:43.000Z","voice_demo":"https://lf3-static.bytednsdoc.com/obj/eden-cn/lm_hz_ihsph/ljhwZthlaukjlkulzlp/portal/bigtts/zh_female_xiaohe_uranus_bigtts.mp3"},{"is_beta":true,"status":1,"top":true,"voice_id":"zh_female_vv_uranus_bigtts","voice_name":"vivi","language":"zh","created_at":"2025-10-30T07:36:20.000Z","voice_demo":"https://lf3-static.bytednsdoc.com/obj/eden-cn/lm_hz_ihsph/ljhwZthlaukjlkulzlp/portal/bigtts/zh_female_vv_uranus_bigtts.wav"}],"yue":[{"status":1,"top":true,"voice_id":"Cantonese_PlayfulMan","voice_name":"粤语男声","language":"yue","created_at":"2024-12-31T16:00:00.000Z","voice_demo":"https://xiaozhi-voice-assistant.oss-cn-shenzhen.aliyuncs.com/tts/zx2ba6ee-40cf-4123-a6ae-394b2a682e49.mp3"}]}},"success":true}
```

说明：

- 用于创建或更新智能体时选择 `tts_voice`。
- 具体字段以线上接口返回为准。

8. 语种列表

用于创建/更新智能体时设置 `language` 字段，取值为下表中的语言代码（key）。

```json
{
  "zh": "普通话",
  "en": "英语",
  "ja": "日语",
  "yue": "粤语",
  "ko": "韩语",
  "ru": "俄语",
  "es": "西班牙语",
  "ar": "阿拉伯语",
  "fr": "法语",
  "vi": "越南语",
  "it": "意大利语",
  "id": "印尼语",
  "hi": "印地语",
  "fi": "芬兰语",
  "th": "泰语",
  "de": "德语",
  "pt": "葡萄牙语",
  "uk": "乌克兰语",
  "tr": "土耳其语",
  "cs": "捷克语",
  "pl": "波兰语",
  "ro": "罗马尼亚语",
  "ca": "加泰罗尼亚语",
  "nl": "荷兰语",
  "sv": "瑞典语",
  "da": "丹麦语",
  "no": "挪威语",
  "et": "爱沙尼亚语",
  "lv": "拉脱维亚语",
  "lt": "立陶宛语",
  "is": "冰岛语",
  "ms": "马来语",
  "sl": "斯洛文尼亚语",
  "bg": "保加利亚语",
  "he": "希伯来语",
  "sk": "斯洛伐克语",
  "hr": "克罗地亚语",
  "hu": "匈牙利语",
  "fa": "波斯语",
  "el": "希腊语",
  "fil": "菲律宾语"
}
```

说明：

- 创建/更新智能体（接口 3、4）的 `language` 字段必须使用上表中的 key（如 `zh`、`en`、`yue`）。
- 选择的 `language` 应与 `tts_voice` 所属语言保持一致；可参考音色列表（接口 7）返回中的 `languages` 与 `tts_voices` 分组。
- 若用户输入的是中文语种名（如"日语"），需先映射为对应 key（如 `ja`）后再提交。

常用枚举（接口 3、4）

1) 识别速度（`asr_speed`）

```json
{
  "normal": "正常",
  "slow": "缓慢",
  "fast": "快速"
}
```

2) 语速（`tts_speech_speed`）

```json
{
  "normal": "正常",
  "slow": "缓慢",
  "fast": "快速"
}
```

3) 记忆类型（`memory_type`）

```json
{
  "SHORT_TERM": "短期记忆",
  "OFF": "关闭"
}
```

10. 历史对话

GET: /api/chats/list

提交参数

| 字段 | 描述 | 类型 | 必填 |
| --- | --- | --- | --- |
| page | 页码 | int | 否 |
| pageSize | 分页大小 | int | 否 |
| agentId | 智能体ID | int | 否 |
| deviceId | 设备ID | int | 否 |
| chatId | 会话ID | int | 否 |
| startDate | 起始日期 | YYYY-mm-dd | 是 |
| endDate | 截止日期 | YYYY-mm-dd | 否 |

返回参数

```json
{
  "success": true,
  "data": {
    "list": [
      {
        "id": "xxx",
        "user_id": "xxx",
        "created_at": "2025-08-22T06:53:08.000Z",
        "device_id": "xxx",
        "msg_count": 6,
        "agent_id": "xx",
        "model": "qwen",
        "token_count": 13956,
        "duration": 128,
        "url": "xxxx",
        "chat_summary": {
          "title": "重新播放音乐",
          "summary": "用户要求重新播放音乐，小智确认后播放了歌曲《单车池塘》。"
        }
      }
    ]
  }
}
```

说明：

- `startDate` 为必填，建议默认查询近 7 天并允许用户调整日期区间。
- 列表结果优先展示：`id`、`created_at`、`chat_summary.title`、`msg_count`。

9. 官方 MCP 工具列表

GET: `/api/agents/common-mcp-tool/list`

请求参数

无（仅需 `Authorization: Bearer <token>`）。

返回参数

```json
{
  "success": true,
  "data": [
    { "endpoint_id": "2",   "name": "Weather" },
    { "endpoint_id": "8",   "name": "Joke",          "language": "zh" },
    { "endpoint_id": "9",   "name": "Music" },
    { "endpoint_id": "101", "name": "News",          "language": "zh" },
    { "endpoint_id": "104", "name": "knowledgeBase" },
    { "endpoint_id": "12",  "name": "onlineMusic",   "debug": true }
  ]
}
```

字段说明

- `endpoint_id`：官方 MCP 工具的接入点 ID（字符串）。用于创建/更新智能体（接口 3、4）的 `mcp_endpoints` 字段。
- `name`：工具展示名（如 `Weather`、`Music`、`knowledgeBase`），用于让用户挑选。
- `language`（可选）：工具仅支持的语言代码（如 `zh`）。未返回该字段视为通用工具。
- `debug`（可选，布尔）：调试中工具，仅供内测，默认不展示给最终用户。

使用建议

- 调用创建/更新智能体前，先拉取本接口列表，配合用户已选 `language` 过滤后给出可选项。
  - 示例：`language=zh` 时保留 `language` 缺失或等于 `zh` 的条目。
- 默认过滤掉 `debug: true` 的条目，除非用户明确要求查看调试工具。
- 提交给 `mcp_endpoints` 时使用 `endpoint_id`（字符串数组），并区分以下三种语义：
  - `mcp_endpoints: ["<id>", ...]`：仅启用所选官方工具。
  - `mcp_endpoints: []`：不加载任何官方 MCP 工具。
  - `mcp_endpoints: null`：加载全部官方 MCP 工具（默认行为）。

11. MCP 创建使用（获取接入点 token）

POST: `/api/agents/<:智能体ID>/generate-mcp-endpoint-token`

返回参数

```json
{
  "success": true,
  "message": "MCP 接入点 token 生成成功",
  "token": "xxxx"
}
```

MCP 使用 demo

```text
wss://api.xiaozhi.me/mcp/?token=<TOKEN>
```

说明：

- 该接口用于为指定智能体生成 MCP 接入 token。
- 返回 `token` 后，按上述格式拼接 MCP websocket 地址。
- `token` 属于敏感凭据，日志与对话中应避免完整明文泄露。
- 控制台获取入口：登录 `xiaozhi.me` 控制台，进入智能体配置页面，右下角点击 `MCP接入点`。
- 接入点弹窗可查看：接入点状态（在线/未连接）、可用工具列表、接入点地址。

官方使用补充（根据说明文档截图）

1. MCP 工具名与参数名要清晰，尽量避免缩写，并提供注释说明用途和触发场景。
2. 函数文档注释需要指导大模型何时调用该工具，以及参数语义。
3. 示例工程中的输入输出占用标准流，调试日志建议使用 `logger`，避免 `print`。
4. MCP 返回值通常为字符串或 JSON，建议精简内容，长度通常限制在 1024 字符内。
5. MCP 工具列表/描述有上限（按 token 计），建议控制工具数量与描述长度。
6. 每个 MCP 接入点连接数有上限，建议避免过多并发空闲连接。


接入点驱动的启用/更新流程（推荐）

1. 启用（mcp_enable）
   - 输入：`agent_id` + 可选 `mcp_endpoint`。
   - 若用户已提供 `mcp_endpoint`，直接使用；否则调用 token 接口拼接 `wss` 地址。
   - 启动桥接进程前，先导出环境变量：
     - `export MCP_ENDPOINT=<your_mcp_endpoint>`
2. 运行方式（参考内置 `mcp-project`）
   - 单个 MCP 服务：`python mcp_pipe.py calculator.py`
   - 按配置运行全部服务：`python mcp_pipe.py`
3. 更新（mcp_update）
   - 更新 MCP server 代码后重启桥接进程；优先保持同一个 `MCP_ENDPOINT`。
4. 刷新 token（mcp_rotate_token）
   - 当 token 失效或需要轮换凭据时，重新调用 token 接口并替换 `MCP_ENDPOINT`。
5. 重连（mcp_reconnect）
   - 连接中断时，先确认 endpoint 有效，再重启桥接进程并回归连通性测试。

12. 删除智能体

POST: `/api/agents/delete`

请求参数

```json
{ "id": 1769357 }
```

| 字段 | 描述 | 类型 | 必填 |
| --- | --- | --- | --- |
| id | 智能体 ID（来自接口 1 列表的 `data[].id`） | int | 是 |

返回参数

```json
{
  "success": true,
  "message": "Delete Agent",
  "data": { "id": 1769357 }
}
```

说明：

- 该接口用于删除指定智能体；删除后该智能体下绑定的设备、配置、历史对话等关联数据将不可再访问，操作不可逆，调用前需向用户二次确认。
- 仅传 `id`，不在 URL 路径中拼接智能体 ID（与「4. 更新智能体」`/api/agents/<:智能体ID>/config` 的风格不同，注意不要混用）。
- 鉴权同其他接口：`Authorization: Bearer <token>`，`Content-Type: application/json`。
- 若 `id` 不存在或无权限，应按统一错误约定返回 `success: false` 并提示用户。

脚本/文件接入 MCP 服务（新增）

1. 单服务接入（mcp_add_service）
   - 用户仅提供 MCP 脚本代码或脚本文件路径（如 `calculator.py`）。
   - 设置接入点：`export MCP_ENDPOINT=<your_mcp_endpoint>`
   - 启动命令：`python vendor/mcp-project/mcp_pipe.py calculator.py`
2. 多服务接入（mcp_add_services_batch）
   - 将多个 MCP 服务写入 `vendor/mcp-project/mcp_config.json`（每个条目包含 `type`、`enabled` 等配置）。
   - 启动命令：`python vendor/mcp-project/mcp_pipe.py`
3. 同步到智能体
   - 所有服务通过同一个 `MCP_ENDPOINT` 与目标智能体同步。
   - 新增或更新服务后重启桥接进程即可完成同步。
4. 更新策略
   - 改脚本：替换脚本文件后重启进程。
   - 改配置：更新 `mcp_config.json` 后重启进程。

本地加速建议（免下载）

1. 项目已内置示例工程：`vendor/mcp-project`。
2. 首次仅需创建一次环境：
   - `bash bin/mcp-local-prepare.sh`
   - 虚拟环境会自动创建在 `vendor/mcp-project/.venv`，并安装依赖。
   - 会自动选择 `python3.10+`，若系统版本不足会提示安装。
3. 推荐使用封装脚本：
   - `bash bin/mcp-local-enable.sh <MCP_ENDPOINT> [script_file]`
   - `bash bin/mcp-local-batch.sh <MCP_ENDPOINT>`
