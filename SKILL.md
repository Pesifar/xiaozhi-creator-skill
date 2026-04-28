---
name: xiaozhi-creator
description: >-
  Manage xiaozhi.me agents and devices through nine API workflows: create agent,
  update agent config, list models, list agents, list devices, add device,
  list tts voices, list chat history, and generate MCP endpoint token.
  Includes MCP endpoint-based lifecycle operations: enable, hot-update, and
  reconnect to agent.
  Use when the user requests xiaozhi API operations, agent lifecycle
  management, or device binding.
---

# Xiaozhi Creator

Use xiaozhi open APIs with JWT bearer auth to complete nine core operations.

## Trigger scenarios

- User asks to create or update a xiaozhi agent.
- User asks for available model list before selecting `llm_model`.
- User asks to query agents or devices.
- User asks to bind a device to an agent using verification code.

## Authentication and base rules

- Base URL default: `https://xiaozhi.me`
- Required header:
  - `Authorization: Bearer <JWT_TOKEN>`
  - `Content-Type: application/json`
- Never output full token in chat logs.
- Validate critical fields before calling write APIs.

## Supported capabilities

1. Create agent
2. Update agent config
3. Get model list
4. Get agent list
5. Get device list
6. Add device to agent
7. Get tts voice list
8. Get chat history list
9. Generate MCP endpoint token, build websocket endpoint, and manage MCP lifecycle

## API playbook

### 1) Create agent

- Endpoint: `POST /api/agents`
- Required minimal body:
  - `agent_name`
  - `assistant_name`
  - `llm_model`
  - `character`
- Recommended defaults:
  - `tts_speech_speed: "normal"`
  - `asr_speed: "normal"`
  - `language: "zh"`
  - `memory_type: "SHORT_TERM"`
- Success pattern:
  - `success: true`
  - `data.id` exists (new agent id)

### 2) Update agent config

- Endpoint: `POST /api/agents/<agent_id>/config`
- Use full config payload shape from create API.
- Important note:
  - Device restart is required after update to apply config.
- Handle known errors by code:
  - `CHARACTER_LENGTH_LIMIT`
  - `INVALID_MEMORY_TYPE`
  - `INVALID_MCP_ENDPOINT`
  - `SENSITIVE_WORD_DETECTED`
  - `INVALID_TTS_VOICE`
  - `INVALID_LLM_MODEL`
  - `AGENT_NOT_FOUND`

### 3) Get model list

- Endpoint: `GET /api/roles/model-list`
- Read `data.modelList[]` and map:
  - `name` for API input
  - `description` for user-readable choice

### 4) Get agent list

- Endpoint: `GET /api/agents`
- Query params:
  - `page`
  - `pageSize` (max 100)
  - `keyword`
- Use response `pagination` to support paging.

### 5) Get device list

- Endpoint: `GET /api/developers/devices`
- Optional query params:
  - `page`, `pageSize`
  - `mac_address`, `serial_number`
  - `product_id`, `device_id`

### 6) Add device

- Endpoint: `POST /api/agents/<agent_id>/devices`
- Body:
  - `verificationCode`
- Success message:
  - `添加设备成功`

### 7) Get tts voice list

- Endpoint: `GET /api/user/tts-list`
- Returns available voice presets for `tts_voice`.
- Recommended usage:
  - Call before create/update agent when user asks to pick a voice.
  - Map readable name/description to actual `tts_voice` value.

### 8) Get chat history list

- Endpoint: `GET /api/chats/list`
- Query params:
  - `startDate` (required, format `YYYY-mm-dd`)
  - `endDate` (optional, format `YYYY-mm-dd`)
  - `page`, `pageSize` (optional)
  - `agentId`, `deviceId`, `chatId` (optional filters)
- Response key fields (`data.list[]`):
  - `id`, `user_id`, `created_at`, `device_id`, `agent_id`
  - `msg_count`, `model`, `token_count`, `duration`, `url`
  - `chat_summary.title`, `chat_summary.summary`
- Recommended usage:
  - Validate `startDate` before calling API.
  - Return concise list with `id`, `created_at`, `chat_summary.title`, and `msg_count`.

### 9) MCP create and usage

- Endpoint: `POST /api/agents/<agent_id>/generate-mcp-endpoint-token`
- Console path (official):
  - Login `xiaozhi.me` console.
  - Open target agent config page.
  - Click `MCP接入点` in the bottom-right area to view endpoint status and available tools.
- Success response pattern:
  - `success: true`
  - `message`: MCP endpoint token generated successfully
  - `token` exists
- Build MCP websocket URL:
  - `wss://api.xiaozhi.me/mcp/?token=<TOKEN>`
- Also accept user-provided endpoint:
  - `mcp_endpoint` can be passed directly by user.
  - If both are available, prefer user-provided endpoint.
  - If not provided, generate token and assemble endpoint automatically.
- Usage notes:
  - Keep `token` masked in chat logs.
  - Token should be treated as temporary secret and only shown when user explicitly asks.
  - If user requests MCP access point setup, return both `agent_id` and assembled websocket URL.
  - Tool names and parameter names should be explicit and self-explanatory.
  - Tool docstring should explain when to use the tool.
  - Use logger output in MCP server code; avoid relying on `print`.
  - Tool return payload should be concise; practical limit is around 1024 chars.
  - Tool list size is limited and later shown in console.
  - Each MCP endpoint has a connection limit; advise user to close idle clients.

### 9.1) MCP service lifecycle (endpoint-driven)

Use this standard workflow so MCP can be enabled/updated anytime:

1. **Enable**
   - Input: `agent_id` + optional `mcp_endpoint`.
   - If `mcp_endpoint` missing, call token API and assemble endpoint.
   - Export endpoint and start bridge process:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python vendor/mcp-project/mcp_pipe.py vendor/mcp-project/calculator.py` (single server)
     - or `python vendor/mcp-project/mcp_pipe.py` (all servers from config)
2. **Update MCP service**
   - Keep same `MCP_ENDPOINT`, deploy updated server code, restart `mcp_pipe.py`.
   - For zero-downtime style updates, start new process first, then stop old process.
3. **Reconnect to agent**
   - If connection drops or token expires, regenerate token and rebuild endpoint.
   - Re-export `MCP_ENDPOINT` and restart local `vendor/mcp-project/mcp_pipe.py`.
4. **Rollback**
   - Restore previous MCP server code version.
   - Restart bridge process with known-good code and current valid endpoint.

### 9.2) Add MCP service from script/file

Allow user to onboard MCP by only providing script code or file:

1. **Single script mode**
   - Input: one script file path, such as `calculator.py`.
   - Keep script interface compatible with FastMCP stdio server pattern.
   - Start command:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python vendor/mcp-project/mcp_pipe.py <script_file>`
2. **Config mode (multiple services)**
   - Input: multiple script files or remote MCP entries.
   - Register services in `vendor/mcp-project/mcp_config.json` with `type` and `enabled`.
   - Start all enabled services:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python vendor/mcp-project/mcp_pipe.py`
3. **Update from new file/code**
   - Replace target script file or update config entry.
   - Restart bridge process to load latest tool schema.
4. **Sync to agent**
   - If endpoint unchanged, sync is immediate after reconnect.
   - If endpoint changed, rotate token/endpoint and restart bridge.
   - For same endpoint (same agent), keep exactly one bridge process and one ws connection.
   - Adding or removing services only updates config and keeps that single bridge running.

### 9.3) Local fast environment setup (no GitHub download needed)

This repository already vendors the MCP sample under `vendor/mcp-project`.

1. Create python env once:
   - `bash bin/mcp-local-prepare.sh`
   - Runtime env is managed at `vendor/mcp-project/.venv`.
   - Script auto-selects `python3.10+` and fails fast with install hint if unavailable.
2. Quick run helpers:
   - `bash bin/mcp-local-enable.sh <MCP_ENDPOINT> [script_file]`
   - `bash bin/mcp-local-batch.sh <MCP_ENDPOINT>`
3. Result:
   - MCP bridge starts locally and can be synced to target agent immediately.

### 9.4) Recommended operation modes

- `mcp_enable`: first-time endpoint setup and connectivity check.
- `mcp_add_service`: add one script file as MCP service.
- `mcp_add_services_batch`: add multiple services through config.
- `mcp_update`: hot update MCP tool code and restart bridge.
- `mcp_rotate_token`: regenerate token and refresh endpoint.
- `mcp_reconnect`: recover from disconnected state.
- `mcp_preflight_check`: check naming, docs, payload, connection limits.

## Execution order recommendation

1. Call model list to validate `llm_model`.
2. Optionally call tts voice list to validate `tts_voice`.
3. Create agent.
4. Optionally update config for advanced fields.
5. Query device list if user needs filtering.
6. Add device to target agent.
7. Optionally query chat history for recent conversations.
8. If user needs MCP integration, use user-provided endpoint or generate token.
9. Return concise summary with ids and next actions.

## MCP response recommendation

When operation 9 is called, return this shape:

- `operation`: one of `mcp_enable` / `mcp_add_service` / `mcp_add_services_batch` / `mcp_update` / `mcp_rotate_token` / `mcp_reconnect`
- `status`: `success` or `failed`
- `key_ids`: include `agent_id`
- `mcp_endpoint`: active endpoint in use
- `bridge_command`: command used to run bridge process
- `services`: activated service names or script files
- `next_step`: one clear action, such as running a calculator test call

## Response template

Use this concise result format:

- `operation`: which API was called
- `status`: success or failed
- `key_ids`: `agent_id` / `device_id` when available
- `next_step`: one actionable next step

## Additional resource

- API details source: `references/主要接口_ai适配.md`
- Example dialogs: `examples/demo-conversation.md`
- Local vendored sample path: `vendor/mcp-project`

