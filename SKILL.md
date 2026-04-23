---
name: xiaozhi-agent-creator
description: Create and sync xiaozhi.me agents from JSON templates. Use when the user wants to create, dry-run, or sync an agent profile on xiaozhi.me, or mentions create_agent.py, agent_profile.template.json, JWT token, or agent bootstrap automation.
---

# Xiaozhi Agent Creator

Create xiaozhi.me agents by filling a template JSON and calling a local Python script.

## When to use

- User wants to quickly create a new xiaozhi agent.
- User has an agent profile JSON and wants a safe dry-run.
- User wants to sync profile fields after agent creation.

## Required inputs

- A config JSON using `authorization + agent` structure.
- A valid JWT token in one of:
  - CLI arg: `--token`
  - JSON: `authorization.token`
  - env vars: `XIAOZHI_TOKEN` or `XIAOZHI_AUTHORIZATION`

## Workflow

1. Start from `templates/agent_profile.template.json`.
2. Save as a new file (for example `my_agent.json`).
3. Fill at least:
   - `authorization.token`
   - `agent.agent_name`
   - `agent.assistant_name`
   - `agent.character`
4. Run dry-run first:
   - `python scripts/create_agent.py --config my_agent.json --dry-run`
5. Create agent:
   - `python scripts/create_agent.py --config my_agent.json`
6. Optional sync:
   - `python scripts/create_agent.py --config my_agent.json --sync-config`

## Safety rules

- Never commit real JWT tokens.
- Do not print or expose token values in final responses.
- If token is missing, instruct user how to set it and stop.
- If `agent_name` is empty, ask user to fix config before retrying.

## Output expectation

- On success, show returned JSON and the console config URL.
- On failure, show concise actionable error guidance.

## Additional resources

- For API field details and integration notes, read `references/主要接口_ai适配.md`.

