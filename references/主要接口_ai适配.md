主要接口

全局请求头

HTTP Authorization: Bearer <Your_Authorization_Token> // 需要用户提供 Content-Type: application/json

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
{ "agent_name": "test", "assistant_name": "小智", "llm_model": "qwen", "tts_voice": "zh_female_wanwanxiaohe_moon_bigtts", // 通过音色列表获取 "tts_speech_speed": "fast", // 角色语速 slow normal fast "tts_pitch": 3, // 音高 范围 [-3, 3] "asr_speed": "normal", // 语音识别速度 slow normal fast "language": "zh", // zh en yue "character": "角色介绍 2000字", "memory": "记忆体内容", "memory_type": "SHORT_TERM", // "OFF"、"SHORT_TERM" "knowledge_base_ids": [], // 知识库ID列表 "mcp_endpoints": ["1", ...], // 官方 MCP 工具 为[]不加载任何产品mcp、为null会加载所有mcp }
```

返回参数

1. 成功 200

```json
{ "success": true, "message": "配置更新成功", "code": "CONFIG_UPDATE_SUCCESS" }
```

2.失败 400 — CHARACTER_LENGTH_LIMIT

```json
{ "success": false, "message": "角色介绍字数不能超过2000字", "code": "CHARACTER_LENGTH_LIMIT" }
```

3.失败 400 — INVALID_MEMORY_TYPE

```json
{ "success": false, "message": "无效的记忆类型选择", "code": "INVALID_MEMORY_TYPE" }
```

4.失败 400 — INVALID_MCP_ENDPOINT

```json
{ "success": false, "message": "无效的 MCP 接入点选择", "code": "INVALID_MCP_ENDPOINT" }
```

5.失败 400 — MALICIOUS_REQUEST

```json
{ "success": false, "message": "频繁请求，请稍后再试", "code": "MALICIOUS_REQUEST" }
```

6.失败 404 — AGENT_NOT_FOUND

```json
{ "success": false, "message": "智能体不存在", "code": "AGENT_NOT_FOUND" }
```

7.失败 400 — SENSITIVE_WORD_DETECTED

```json
{ "success": false, "message": "角色介绍或角色记忆，检测到违规内容，请修改后保存", "code": "SENSITIVE_WORD_DETECTED" }
```

8.失败 400 — INVALID_TTS_VOICE

```json
{ "success": false, "message": "无效的角色音色选择", "code": "INVALID_TTS_VOICE" }
```

9.失败 400 — INVALID_LLM_MODEL

```json
{ "success": false, "message": "无效的语言模型选择", "code": "INVALID_LLM_MODEL" }
```

（待补充）

注：更新后，需要重启设备，才会生效配置

5. 设备列表

GET：/api/developers/devices

提交参数

| 字段 | 描述 | 类型 | 必填 |
| --- | --- | --- | --- |
| page | 页码 | int | 否 |
| pageSize | 分页大小 | int | 否 |
| mac_address | 设备mac地址 | str | 否 |
| serial_number | 序列号 | str | 否 |
| product_id | 产品ID | int | 否 |
| device_id | 设备ID | int | 否 |

返回参数

```json
{ "success": true, "data": { "list": [ { "device_id": xxx, // 设备ID "agent_id": xxx, // 智能体ID "id": xxxx, "product_id": xxx, "seed": "xxxxx", "serial_number": "xxxx", "activate_at": "2025-10-11T02:38:06.000Z", "product_name": "xxx", "mac_address": "xxxx", "app_version": "1.8.9", "board_name": "w1.54", "online": true, // 是否在线 }, ...
```

6. 添加设备

指定智能体ID

POST: /api/agents/<:智能体ID>/devices

```json
{ "verificationCode": "123123" }
```

返回参数

```json
{ "success": true, "message": "添加设备成功", "data": { "id": 600608, "user_id": 230815, "mac_address": "xxxx", "iccid": xxxx, "created_at": "2025-07-18T10:15:24.000Z", // utc 时间 "updated_at": "2025-07-18T10:15:24.000Z", // utc 时间 "last_connected_at": null, "auto_update": 1, "alias": null, "agent_id": xxx, "app_version": "0.0.8", "board_name": "xiaozhi-sdk-0.0.8", "serial_number": "xxx", "is_auth": true, // 设备是否商业授权 } }
```
