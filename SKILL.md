---
name: xiaozhi-creator
description: >-
  Manage xiaozhi.me agents and devices through API workflows: phone login to
  obtain JWT, create agent, update agent config, list models, list agents,
  list devices, add device, list tts voices, list chat history, list official
  MCP tools, and generate MCP endpoint token. Includes MCP endpoint-based
  lifecycle operations: enable, hot-update, and reconnect to agent.
  Use when the user requests xiaozhi API operations, agent lifecycle
  management, device binding, or phone-based login to xiaozhi.me.
---

# Xiaozhi Creator

Use xiaozhi open APIs with JWT bearer auth to complete the core operations.

## Trigger scenarios

- User asks to login to xiaozhi.me with a phone number to obtain JWT token.
- User asks to create or update a xiaozhi agent.
- User asks for available model list before selecting `llm_model`.
- User asks to query agents or devices.
- User asks to bind a device to an agent using verification code.
- User asks which official MCP tools are available, or wants to pick the
  `mcp_endpoints` value when creating/updating an agent.

## Authentication and base rules

- Base URL default: `https://xiaozhi.me`
- Required header:
  - `Authorization: Bearer <JWT_TOKEN>`
  - `Content-Type: application/json`
- Never output full token in chat logs.
- Validate critical fields before calling write APIs.

## Supported capabilities

0. Phone login (obtain JWT token via captcha + SMS)
1. Create agent
2. Update agent config
3. Get model list
4. Get agent list
5. Get device list
6. Add device to agent
7. Get tts voice list
8. Get chat history list
9. List official MCP tools (`mcp_endpoints` candidates)
10. Generate MCP endpoint token, build websocket endpoint, and manage MCP lifecycle

## API playbook

### 0) Phone login (obtain JWT token)

Use this workflow when the user has no JWT yet and only has a phone number.
The flow consists of three sequential calls and **requires a shared cookie
jar** because the captcha cookie issued by step 0.1 must be sent back in
step 0.2.

> ⚠️ **All three auth endpoints have CORS restrictions** and cannot be
> called from a browser `fetch` / `XMLHttpRequest`:
> - `GET  /api/auth/captcha`
> - `POST /api/auth/send-code`
> - `POST /api/auth/phone-login`
>
> They must be invoked **server-side / from a CLI** (e.g. `curl`, Node
> `https`, Python `requests`, Go `net/http`). Do **not** try to wire them
> into a frontend page directly — they will be blocked by the browser's
> same-origin policy.
>
> The provided helper `bin/xiaozhi-login.sh` handles the full flow
> end-to-end via `curl` and is the recommended path. If you must call them
> from your own backend, mirror the same cookie-jar handling described
> below.

#### 0.1) Get image captcha

- Endpoint: `GET /api/auth/captcha`
- Response:
  - Body: **SVG XML text**, not a raster image. Looks like:

    ```xml
    <svg xmlns="http://www.w3.org/2000/svg" width="180" height="50" viewBox="0,0,180,50">
      ...captcha glyphs...
    </svg>
    ```

  - Headers:
    - `Content-Type: text/html; charset=utf-8` — ⚠️ the server **mislabels**
      the SVG as `text/html`. Do **not** trust this header to decide how to
      handle the body; it is genuine SVG.
    - `Set-Cookie: captcha=captcha:<random_id>`
- Required handling:
  - Detect SVG by **sniffing the body** for a leading `<svg` token, not by
    parsing `Content-Type`.
  - Persist the response cookie (`captcha=...`) into a cookie jar.
  - Save the SVG body to a local file with `.svg` extension so the OS opens
    it in a browser / Preview, regardless of the misleading server header.
  - On macOS the helper script automatically opens the SVG with the system
    default app (typically Safari/Chrome). On Linux it tries `xdg-open`.
  - Do **not** try to decode the SVG to PNG before showing it — sending it
    directly to a browser-capable viewer is enough for the user to read
    the characters.

#### 0.2) Send SMS verification code

- Endpoint: `POST /api/auth/send-code`
- Request cookie (required):
  - `Cookie: captcha=captcha:<random_id>` (from step 0.1)
- Request body:
  - `phone`: full E.164 number, e.g. `"+8613537280181"`
  - `captcha_code`: the captcha characters the user just read from the image
- Success pattern:
  - `success: true`
- Common failure causes:
  - Wrong `captcha_code` → repeat step 0.1 to get a new captcha.
  - Phone format must include country prefix (e.g. `+86`).

#### 0.3) Phone login

- Endpoint: `POST /api/auth/phone-login`
- Request body:
  - `phone`: same number used in step 0.2.
  - `code`: the SMS code received on the phone.
- Success response shape:

```json
{
  "token": "<JWT_TOKEN>",
  "data": {
    "userId": 230810,
    "username": "...",
    "telephone": "+86135****0181",
    "role": "user"
  }
}
```

- Required handling after success:
  - Treat `token` as a sensitive credential. Never echo it in chat logs in
    full; mask it (e.g. show first/last 4 chars) unless the user explicitly
    asks.
  - Persist `token` for downstream API calls as `Authorization: Bearer <token>`.
  - The helper script writes the token to `.xiaozhi-auth/token.json`
    (gitignored) for reuse by subsequent operations.

#### 0.4) Helper script (recommended)

Run the interactive helper instead of orchestrating curl calls manually:

- `bash bin/xiaozhi-login.sh +8613537280181`
- The script will:
  1. Fetch the captcha image, save it to `.xiaozhi-auth/captcha.<ext>`,
     save the cookie jar to `.xiaozhi-auth/cookies.txt`, and try to open
     the image with the system viewer.
  2. Prompt the user to type the captcha characters.
  3. Call `/api/auth/send-code` with the captcha cookie.
  4. Prompt the user to type the SMS code received on the phone.
  5. Call `/api/auth/phone-login`, save `token` and user info into
     `.xiaozhi-auth/token.json`, and print a masked summary plus the
     `export XIAOZHI_TOKEN=...` line for shell reuse.

#### 0.5) Operation contract

When this operation is invoked, return a concise result of this shape:

- `operation`: `phone_login`
- `status`: `success` / `failed`
- `key_ids`: `userId=<id>`, `telephone=<masked>`, `role=<role>`
- `token_preview`: first 4 + `...` + last 4 chars of `token`
- `next_step`: e.g. "已保存 token，可继续调用 get_agent_list / create_agent。"

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
- Optional `mcp_endpoints` field (list of official MCP tool ids):
  - `null` (default) — load all official MCP tools.
  - `[]` — load no official MCP tools.
  - `["<endpoint_id>", ...]` — load only the listed tools. Source the ids
    from operation 9 (`GET /api/agents/common-mcp-tool/list`).
- Success pattern:
  - `success: true`
  - `data.id` exists (new agent id)

### 2) Update agent config

- Endpoint: `POST /api/agents/<agent_id>/config`
- Use full config payload shape from create API.
- `mcp_endpoints` follows the same semantics as create agent (see operation 9
  for how to source `endpoint_id` candidates).
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

### 9) List official MCP tools

- Endpoint: `GET /api/agents/common-mcp-tool/list`
- Auth: `Authorization: Bearer <JWT_TOKEN>`
- Response shape (`data[]`):
  - `endpoint_id` (string) — value to feed into `mcp_endpoints` of create/update agent.
  - `name` — display name (e.g. `Weather`, `Music`, `News`, `knowledgeBase`).
  - `language` (optional) — language restriction code (e.g. `zh`).
  - `debug` (optional, bool) — beta tool, hide by default.
- Recommended usage:
  - Call before create/update agent when the user wants to pick official MCP tools.
  - Filter out entries with `debug: true` unless the user asks for debug tools.
  - Prefer entries whose `language` matches the agent's `language`, or has no
    `language` field at all (treat missing as universal).
- `mcp_endpoints` semantics in create/update agent:
  - `["<endpoint_id>", ...]` — load only the selected official tools.
  - `[]` — load no official MCP tools.
  - `null` — load all official MCP tools (default behavior).

### 10) MCP create and usage

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

### 10.1) MCP service lifecycle (endpoint-driven)

Use this standard workflow so MCP can be enabled/updated anytime:

1. **Enable**
   - Input: `agent_id` + optional `mcp_endpoint`.
   - If `mcp_endpoint` missing, call token API and assemble endpoint.
   - Install bridge SDK when needed:
     - `pip install git+https://github.com/dairoot/mcp-calculator`
   - Export endpoint and start bridge process:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python -m xiaozhi_mcp examples/calculator.py` (single server)
     - or `python -m xiaozhi_mcp` (all servers from `mcp_config.json`)
2. **Update MCP service**
   - Keep same `MCP_ENDPOINT`, deploy updated server code, restart `python -m xiaozhi_mcp`.
   - For zero-downtime style updates, start new process first, then stop old process.
3. **Reconnect to agent**
   - If connection drops or token expires, regenerate token and rebuild endpoint.
   - Re-export `MCP_ENDPOINT` and restart local SDK bridge.
4. **Rollback**
   - Restore previous MCP server code version.
   - Restart bridge process with known-good code and current valid endpoint.

### 10.2) Add MCP service from script/file

Allow user to onboard MCP by only providing script code or file:

1. **Single script mode**
   - Input: one script file path, such as `calculator.py`.
   - Keep script interface compatible with FastMCP stdio server pattern.
   - Start command:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python -m xiaozhi_mcp <script_file>`
2. **Config mode (multiple services)**
   - Input: multiple script files or remote MCP entries.
   - Register services in `mcp_config.json` with `type` and `enabled`.
   - Start all enabled services:
     - `export MCP_ENDPOINT=<mcp_endpoint>`
     - `python -m xiaozhi_mcp`
3. **Update from new file/code**
   - Replace target script file or update config entry.
   - Restart bridge process to load latest tool schema.
4. **Sync to agent**
   - If endpoint unchanged, sync is immediate after reconnect.
   - If endpoint changed, rotate token/endpoint and restart bridge.
   - For same endpoint (same agent), keep exactly one bridge process and one ws connection.
   - Adding or removing services only updates config and keeps that single bridge running.

### 10.3) Local fast environment setup

This repository uses the packaged bridge SDK from `dairoot/mcp-calculator`; do not rely on a vendored bridge implementation.

1. Create python env once:
   - `bash bin/mcp-local-prepare.sh`
   - Runtime env is managed at `.venv`.
   - Script auto-selects `python3.10+` and fails fast with install hint if unavailable.
   - The script installs `git+https://github.com/dairoot/mcp-calculator`.
2. Quick run helpers:
   - `bash bin/mcp-local-enable.sh <MCP_ENDPOINT> [script_file]`
   - `bash bin/mcp-local-batch.sh <MCP_ENDPOINT>`
3. Result:
   - MCP bridge starts locally and can be synced to target agent immediately.

### 10.4) Recommended operation modes

- `mcp_enable`: first-time endpoint setup and connectivity check.
- `mcp_add_service`: add one script file as MCP service.
- `mcp_add_services_batch`: add multiple services through config.
- `mcp_update`: hot update MCP tool code and restart bridge.
- `mcp_rotate_token`: regenerate token and refresh endpoint.
- `mcp_reconnect`: recover from disconnected state.
- `mcp_preflight_check`: check naming, docs, payload, connection limits.
- `list_official_mcp_tools`: fetch `mcp_endpoints` candidates before
  create/update agent.

## Execution order recommendation

0. If no JWT token is available, run phone login (operation 0) first so all
   downstream calls have `Authorization: Bearer <token>`.
1. Call model list to validate `llm_model`.
2. Optionally call tts voice list to validate `tts_voice`.
3. Optionally call official MCP tool list (operation 9) when the user wants
   to pick `mcp_endpoints` for create/update agent.
4. Create agent.
5. Optionally update config for advanced fields.
6. Query device list if user needs filtering.
7. Add device to target agent.
8. Optionally query chat history for recent conversations.
9. If user needs MCP integration, use user-provided endpoint or generate token.
10. Return concise summary with ids and next actions.

## MCP response recommendation

When operation 10 is called, return this shape:

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
- Local MCP example script: `examples/calculator.py`

