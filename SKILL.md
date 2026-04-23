---
name: xiaozhi-creator
description: Manage xiaozhi.me agents and devices through six API workflows: create agent, update agent config, list models, list agents, list devices, and add device. Use when the user requests xiaozhi API operations, agent lifecycle management, or device binding.
---

# Xiaozhi Creator

Use xiaozhi open APIs with JWT bearer auth to complete six core operations.

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

## Execution order recommendation

1. Call model list to validate `llm_model`.
2. Create agent.
3. Optionally update config for advanced fields.
4. Query device list if user needs filtering.
5. Add device to target agent.
6. Return concise summary with ids and next actions.

## Response template

Use this concise result format:

- `operation`: which API was called
- `status`: success or failed
- `key_ids`: `agent_id` / `device_id` when available
- `next_step`: one actionable next step

## Additional resource

- API details source: `references/主要接口_ai适配.md`

