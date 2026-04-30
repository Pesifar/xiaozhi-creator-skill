# xiaozhi-creator-skill

将小智 API 的核心能力封装为可安装 skill：手机号登录获取 JWT、创建智能体、更新智能体、模型列表、智能体列表、设备列表、添加设备、音色列表、历史对话列表、声纹识别管理、MCP 接入点 token 生成与使用。

## 安装

```bash
npx skills add Pesifar/xiaozhi-creator-skill
```

例如（示例）：

```bash
npx skills add Pesifar/xiaozhi-creator-skill
```

## 能力范围

0. 手机号登录获取 JWT token（图形验证码 + 短信验证码，**三个接口均有 CORS 限制，必须服务端 / CLI 调用**）：
   - `GET  /api/auth/captcha`（保留 `Set-Cookie: captcha=...` 给后续步骤使用）
   - `POST /api/auth/send-code`（请求时需带回 `captcha=...` cookie）
   - `POST /api/auth/phone-login`（返回 `token` 用作后续 `Authorization: Bearer ...`）
1. 创建智能体：`POST /api/agents`
2. 更新智能体：`POST /api/agents/<agent_id>/config`
3. 模型列表：`GET /api/roles/model-list`
4. 智能体列表：`GET /api/agents`
5. 设备列表：`GET /api/developers/devices`
6. 添加设备：`POST /api/agents/<agent_id>/devices`
7. 音色列表：`GET /api/user/tts-list`
8. 历史对话：`GET /api/chats/list`
9. 获取MCP接入地址：`POST /api/agents/<agent_id>/generate-mcp-endpoint-token`
10. 声纹识别：
   - `GET /api/agents/<agent_id>/speakers`
   - `GET /api/v2/agents/<agent_id>/available-embeddings`
   - `POST /api/v2/agents/<agent_id>/speakers`
   - `POST /api/v2/agents/<agent_id>/speakers/<id>`
   - `DELETE /api/agents/<agent_id>/speakers/<id>`
11. 设备端 MCP 交互（远程查询/控制设备）：
   - `POST /api/agents/generate-messaging-token`（获取设备交互 token）
   - `POST /api/messaging/device/tools/list`（获取设备可用 MCP 工具列表）
   - `POST /api/messaging/device/tools/call`（调用设备 MCP 工具）
   - 自定义主题页面：`https://xiaozhi.me/tools/assets-generator/?token=<token>`（新标签页打开）

## 手机号登录快速使用

```bash
bash bin/xiaozhi-login.sh +8613537280181
```

脚本流程：

1. 拉取图形验证码图片（保存到 `.xiaozhi-auth/captcha.<ext>`，并把 `captcha=...` cookie 写入 `.xiaozhi-auth/cookies.txt`），macOS 下会自动用系统看图工具打开。
2. 终端提示输入图形验证码 → 调用 `POST /api/auth/send-code`（带回 cookie）。
3. 终端提示输入手机收到的短信验证码 → 调用 `POST /api/auth/phone-login`。
4. 把 `token` 与用户信息保存到 `.xiaozhi-auth/token.json`（已加入 `.gitignore`），并打印掩码后的 token 摘要。

后续接口调用可一键复用该 token：

```bash
export XIAOZHI_TOKEN="$(python3 -c 'import json; print(json.load(open(".xiaozhi-auth/token.json"))["token"])')"
curl -H "Authorization: Bearer $XIAOZHI_TOKEN" https://xiaozhi.me/api/agents
```

## MCP 创建使用补充

- 控制台入口：登录 `xiaozhi.me`，进入智能体配置页，右下角点击 `MCP接入点`。
- token 接口：`POST /api/agents/<agent_id>/generate-mcp-endpoint-token`
- 连接地址：`wss://api.xiaozhi.me/mcp/?token=<TOKEN>`
- 使用建议：工具名和参数名清晰、函数注释明确、返回 JSON 精简、日志优先使用 logger。
- 支持模式：
  - `mcp_enable`：首次启用（优先用用户提供的 `mcp_endpoint`，否则自动生成 token）
  - `mcp_add_service`：仅提供一个 MCP 脚本文件即可接入
  - `mcp_add_services_batch`：通过配置一次接入多个 MCP 服务
  - `mcp_update`：更新 MCP 服务代码并重启桥接进程
  - `mcp_rotate_token`：刷新 token 并更新接入地址
  - `mcp_reconnect`：连接断开后的快速重连
- 安装桥接 SDK：
  - `pip install git+https://github.com/dairoot/mcp-calculator`
- 运行桥接：
  - `export MCP_ENDPOINT=<your_mcp_endpoint>`
  - `python -m xiaozhi_mcp examples/calculator.py`（单服务）
  - `python -m xiaozhi_mcp`（按 `mcp_config.json` 启动全部服务）
- 脚本/文件即接入：
  - 你只需要提供脚本代码或文件路径（例如 `calculator.py`），即可通过 `mcp_add_service` 启用。
  - 多服务场景将条目写入仓库根目录 `mcp_config.json`，通过 `mcp_add_services_batch` 同步到同一智能体。
  - 同一 `MCP_ENDPOINT`（同一智能体）始终只保留一个 bridge 进程，并复用同一个 ws 连接。
  - 后续新增/删除服务只更新配置，不再拉起新的 bridge 进程。
- 本地快速环境：
  - 示例脚本：`examples/calculator.py`
  - 自动准备：`bash bin/mcp-local-prepare.sh`（优先复用已有 `.venv`，否则自动创建并安装 SDK）
  - Python 版本：脚本会自动选择 `python3.10+`，低版本会给出安装提示
  - 快速启用：`bash bin/mcp-local-enable.sh <MCP_ENDPOINT> [script_file]`
  - 批量启用：`bash bin/mcp-local-batch.sh <MCP_ENDPOINT>`

## 文件结构

```text
xiaozhi-creator-skill/
├── SKILL.md
├── README.md
├── bin/
│   ├── xiaozhi-login.sh
│   ├── mcp-local-prepare.sh
│   ├── mcp-local-enable.sh
│   └── mcp-local-batch.sh
├── examples/
│   ├── calculator.py
│   └── demo-conversation.md
├── references/
│   └── 主要接口_ai适配.md
├── mcp_config.json
└── .gitignore
```

## 致谢参考

- [alchaincyf/zhangxuefeng-skill](https://github.com/alchaincyf/zhangxuefeng-skill)

