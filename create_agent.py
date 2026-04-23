#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
创建小智智能体（本目录为独立模版包：create_agent.py + agent_profile.template.json + 主要接口_ai适配.docx）。

--------------------------------------------------------------------
第一步  复制 JSON 模版
--------------------------------------------------------------------
  复制  agent_profile.template.json  为任意文件名（如  my_agent.json ），用 UTF-8 保存。

--------------------------------------------------------------------
第二步  只改 JSON 里两块内容
--------------------------------------------------------------------
  1）authorization.token  
      填登录控制台后拿到的 JWT（不要写 “Bearer ” 前缀）。

  2）agent  
      至少改好 agent_name、assistant_name、character；其余可按需改模型、音色、memory、mcp_endpoints 等。  
      未写的字段会由脚本用默认值补齐。字段说明见同目录：主要接口_ai适配.docx（同源 .md 可对照）

--------------------------------------------------------------------
第三步  运行（在 app 目录下）
--------------------------------------------------------------------
  python create_agent.py --config my_agent.json

可选：--dry-run  只打印请求体不调接口；--sync-config  创建后再同步一次配置接口。

Token 优先级：命令行 --token > JSON authorization > 环境变量 XIAOZHI_TOKEN / XIAOZHI_AUTHORIZATION

请求体使用 UTF-8。勿将含真实 Token 的 JSON 提交到公开仓库。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, Tuple


DEFAULT_BASE = "https://xiaozhi.me/api"

DEFAULT_FIELDS: Dict[str, Any] = {
    "assistant_name": "小智",
    "llm_model": "qwen",
    "tts_voice": "zh_female_wanwanxiaohe_moon_bigtts",
    "tts_speech_speed": "normal",
    "tts_pitch": 0,
    "asr_speed": "normal",
    "language": "zh",
    "character": "",
    "memory": "",
    "memory_type": "SHORT_TERM",
    "knowledge_base_ids": [],
    "mcp_endpoints": [],
}

_AUTH_TOP_KEYS = frozenset({"authorization", "auth"})


def _normalize_token(raw: str) -> str:
    t = (raw or "").strip()
    if t.lower().startswith("bearer "):
        t = t[7:].strip()
    return t


def _token_from_authorization_block(block: Any) -> str:
    if block is None:
        return ""
    if isinstance(block, str):
        return _normalize_token(block)
    if isinstance(block, dict):
        inner = (
            block.get("token")
            or block.get("bearer_token")
            or block.get("jwt")
            or block.get("Authorization")
        )
        if inner is None:
            return ""
        return _normalize_token(str(inner))
    return ""


def load_agent_document(path: str) -> Tuple[Dict[str, Any], str]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"配置文件必须是 JSON 对象: {path}")

    file_token = _token_from_authorization_block(
        data.get("authorization", data.get("auth"))
    )

    if isinstance(data.get("agent"), dict):
        user_cfg = dict(data["agent"])
    else:
        user_cfg = {k: v for k, v in data.items() if k not in _AUTH_TOP_KEYS}

    return user_cfg, file_token


def build_payload(user: Dict[str, Any]) -> Dict[str, Any]:
    return {**DEFAULT_FIELDS, **user}


def resolve_token(cli_token: str, file_token: str) -> str:
    for candidate in (
        cli_token,
        file_token,
        os.environ.get("XIAOZHI_TOKEN", ""),
        os.environ.get("XIAOZHI_AUTHORIZATION", ""),
    ):
        t = _normalize_token(str(candidate or ""))
        if t:
            return t
    return ""


def post_json(url: str, token: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            err = json.loads(raw)
        except json.JSONDecodeError:
            print(raw, file=sys.stderr)
            raise SystemExit(e.code) from e
        print(json.dumps(err, ensure_ascii=False, indent=2), file=sys.stderr)
        raise SystemExit(e.code)

    return json.loads(raw)


def main() -> None:
    p = argparse.ArgumentParser(
        description="创建小智智能体：分块 JSON（authorization + agent），见 agent_profile.template.json",
    )
    p.add_argument(
        "--config",
        metavar="PATH",
        required=True,
        help="UTF-8 JSON：含 authorization 与 agent 两块",
    )
    p.add_argument(
        "--token",
        default="",
        help="可选，若填写则覆盖 JSON / 环境变量中的 Token",
    )
    p.add_argument(
        "--base-url",
        default=os.environ.get("XIAOZHI_API_BASE", DEFAULT_BASE).rstrip("/"),
        help=f"API 根地址，默认 {DEFAULT_BASE}",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="只打印将要提交的 agent JSON（不含 Token），不请求接口",
    )
    p.add_argument(
        "--sync-config",
        action="store_true",
        help="创建成功后再 POST /agents/<id>/config",
    )
    args = p.parse_args()

    user_cfg, file_token = load_agent_document(args.config.strip())
    token = resolve_token(args.token, file_token)
    if not token:
        print(
            "错误：未找到 Token。请在 JSON 的 authorization 中填写 token，"
            "或使用 --token / 环境变量 XIAOZHI_TOKEN。",
            file=sys.stderr,
        )
        raise SystemExit(2)

    payload = build_payload(user_cfg)

    if not (payload.get("agent_name") or "").strip():
        print(
            '错误：agent 块中必须包含非空的 "agent_name"。',
            file=sys.stderr,
        )
        raise SystemExit(2)

    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return

    base = args.base_url.rstrip("/")
    create_url = f"{base}/agents"
    result = post_json(create_url, token, payload)

    if not result.get("success"):
        print(json.dumps(result, ensure_ascii=False, indent=2))
        raise SystemExit(1)

    agent_id = result.get("data", {}).get("id")
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if args.sync_config and agent_id is not None:
        config_url = f"{base}/agents/{agent_id}/config"
        cfg = post_json(config_url, token, payload)
        print("\n--- sync POST /agents/<id>/config ---\n")
        print(json.dumps(cfg, ensure_ascii=False, indent=2))

    if agent_id is not None:
        front = os.environ.get("XIAOZHI_FRONTEND", "https://xiaozhi.me").rstrip("/")
        print(f"\n控制台「配置角色」: {front}/console/agents/{agent_id}/config")


if __name__ == "__main__":
    main()
