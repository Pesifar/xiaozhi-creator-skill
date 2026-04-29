#!/usr/bin/env bash
# Interactive xiaozhi.me phone-number login.
#
# Flow:
#   1) GET  /api/auth/captcha         -> save image + cookie jar
#   2) POST /api/auth/send-code       -> phone + captcha_code (with cookie)
#   3) POST /api/auth/phone-login     -> phone + sms_code
#
# Output (all under .xiaozhi-auth/, gitignored):
#   captcha.svg       SVG of the captcha (rendered by browser/Preview)
#   cookies.txt       curl-format cookie jar (carries `captcha=...`)
#   token.json        { token, userId, username, telephone, role }
#
# Usage:
#   bash bin/xiaozhi-login.sh [+86138xxxxxxxx]
#
# Dependencies: curl, python3 (used only for JSON parsing).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_DIR="$PROJECT_ROOT/.xiaozhi-auth"
COOKIE_JAR="$AUTH_DIR/cookies.txt"
CAPTCHA_HEADERS="$AUTH_DIR/captcha.headers"
TOKEN_FILE="$AUTH_DIR/token.json"
BASE_URL="${XIAOZHI_BASE_URL:-https://xiaozhi.me}"
UA="${XIAOZHI_UA:-Mozilla/5.0 (xiaozhi-creator-skill/cli)}"

mkdir -p "$AUTH_DIR"
chmod 700 "$AUTH_DIR" 2>/dev/null || true

if ! command -v curl >/dev/null 2>&1; then
  echo "[xiaozhi-login] 'curl' is required but not found in PATH." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "[xiaozhi-login] 'python3' is required but not found in PATH." >&2
  exit 1
fi

PHONE="${1:-}"
if [[ -z "$PHONE" ]]; then
  read -r -p "请输入手机号(含国家区号，例如 +8613537280181): " PHONE
fi

if [[ ! "$PHONE" =~ ^\+[0-9]{8,15}$ ]]; then
  echo "[xiaozhi-login] 手机号格式不正确，应为 + 开头且仅含数字，例如 +8613537280181" >&2
  exit 2
fi

mask_phone() {
  local p="$1"
  if [[ ${#p} -le 7 ]]; then
    printf '%s' "$p"
  else
    printf '%s****%s' "${p:0:7}" "${p: -4}"
  fi
}

mask_token() {
  local t="$1"
  if [[ ${#t} -le 12 ]]; then
    printf '****'
  else
    printf '%s...%s' "${t:0:4}" "${t: -4}"
  fi
}

# extract_field <json_body> <dotted.path>
extract_field() {
  local body="$1"
  local path="$2"
  printf '%s' "$body" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(0)
cur = data
for key in sys.argv[1].split("."):
    if not key:
        continue
    if isinstance(cur, dict) and key in cur:
        cur = cur[key]
    else:
        cur = ""
        break
if isinstance(cur, (dict, list)):
    print(json.dumps(cur, ensure_ascii=False))
else:
    print("" if cur is None else cur)
' "$path"
}

# ---------------- step 1: captcha ----------------
echo "[xiaozhi-login] (1/3) 获取图形验证码..."
rm -f "$COOKIE_JAR" "$CAPTCHA_HEADERS"
TMP_IMG="$AUTH_DIR/captcha.bin"
curl -sS \
  -A "$UA" \
  -c "$COOKIE_JAR" \
  -D "$CAPTCHA_HEADERS" \
  -o "$TMP_IMG" \
  "$BASE_URL/api/auth/captcha"

if [[ ! -s "$TMP_IMG" ]]; then
  echo "[xiaozhi-login] 拉取验证码失败：响应体为空。" >&2
  exit 3
fi

if ! grep -qi "captcha" "$COOKIE_JAR" 2>/dev/null; then
  echo "[xiaozhi-login] 警告：未在响应中发现 captcha cookie，后续 send-code 可能失败。" >&2
fi

# /api/auth/captcha returns SVG XML text in the body, but the server
# mislabels it as `Content-Type: text/html; charset=utf-8`. We therefore
# sniff the response body for a leading `<svg` instead of trusting the
# header / `file` mime detection (which on Linux often reports text/html
# for the same body). Default extension is .svg; the file mime branch
# below is only a defensive fallback.
EXT="svg"
if head -c 1024 "$TMP_IMG" 2>/dev/null | grep -qi "<svg"; then
  EXT="svg"
elif command -v file >/dev/null 2>&1; then
  MIME="$(file -b --mime-type "$TMP_IMG" 2>/dev/null || echo "")"
  case "$MIME" in
    image/svg*)  EXT="svg"  ;;
    image/png)   EXT="png"  ;;
    image/jpeg)  EXT="jpg"  ;;
    image/gif)   EXT="gif"  ;;
    image/webp)  EXT="webp" ;;
    text/*)      EXT="svg"  ;;
  esac
fi
CAPTCHA_IMG="$AUTH_DIR/captcha.$EXT"
mv -f "$TMP_IMG" "$CAPTCHA_IMG"

echo "[xiaozhi-login] 验证码图片已保存: $CAPTCHA_IMG"
case "$(uname -s)" in
  Darwin) (open "$CAPTCHA_IMG" >/dev/null 2>&1 || true) ;;
  Linux)
    if command -v xdg-open >/dev/null 2>&1; then
      (xdg-open "$CAPTCHA_IMG" >/dev/null 2>&1 || true)
    fi
    ;;
esac

read -r -p "请输入图片中显示的验证码: " CAPTCHA_CODE
if [[ -z "$CAPTCHA_CODE" ]]; then
  echo "[xiaozhi-login] 验证码为空，已终止。" >&2
  exit 4
fi

# ---------------- step 2: send-code ----------------
echo "[xiaozhi-login] (2/3) 请求短信验证码..."
SEND_BODY="$(
  PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
print(json.dumps({"phone": sys.argv[1], "captcha_code": sys.argv[2]}, ensure_ascii=False))
' "$PHONE" "$CAPTCHA_CODE"
)"

SEND_RESP="$(
  curl -sS \
    -A "$UA" \
    -b "$COOKIE_JAR" \
    -c "$COOKIE_JAR" \
    -H "Content-Type: application/json" \
    -X POST \
    --data "$SEND_BODY" \
    "$BASE_URL/api/auth/send-code"
)"

SEND_OK="$(extract_field "$SEND_RESP" 'success')"
if [[ "$SEND_OK" != "true" && "$SEND_OK" != "True" && "$SEND_OK" != "1" ]]; then
  echo "[xiaozhi-login] 发送短信失败，原始响应:" >&2
  echo "$SEND_RESP" >&2
  echo "[xiaozhi-login] 提示：图形验证码可能输错或失效，请重新运行脚本。" >&2
  exit 5
fi
echo "[xiaozhi-login] 短信已发送至 $(mask_phone "$PHONE")，请查收。"

read -r -p "请输入手机收到的短信验证码: " SMS_CODE
if [[ -z "$SMS_CODE" ]]; then
  echo "[xiaozhi-login] 短信验证码为空，已终止。" >&2
  exit 6
fi

# ---------------- step 3: phone-login ----------------
echo "[xiaozhi-login] (3/3) 登录中..."
LOGIN_BODY="$(
  PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
print(json.dumps({"phone": sys.argv[1], "code": sys.argv[2]}, ensure_ascii=False))
' "$PHONE" "$SMS_CODE"
)"

LOGIN_RESP="$(
  curl -sS \
    -A "$UA" \
    -b "$COOKIE_JAR" \
    -H "Content-Type: application/json" \
    -X POST \
    --data "$LOGIN_BODY" \
    "$BASE_URL/api/auth/phone-login"
)"

TOKEN="$(extract_field    "$LOGIN_RESP" 'token')"
USER_ID="$(extract_field  "$LOGIN_RESP" 'data.userId')"
USERNAME="$(extract_field "$LOGIN_RESP" 'data.username')"
TEL="$(extract_field      "$LOGIN_RESP" 'data.telephone')"
ROLE="$(extract_field     "$LOGIN_RESP" 'data.role')"

if [[ -z "$TOKEN" ]]; then
  echo "[xiaozhi-login] 登录失败，原始响应:" >&2
  echo "$LOGIN_RESP" >&2
  exit 7
fi

printf '%s' "$LOGIN_RESP" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
data = json.loads(sys.stdin.read() or "{}")
result = {
    "token": data.get("token"),
    "userId": (data.get("data") or {}).get("userId"),
    "username": (data.get("data") or {}).get("username"),
    "telephone": (data.get("data") or {}).get("telephone"),
    "role": (data.get("data") or {}).get("role"),
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)
' "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE" 2>/dev/null || true

echo
echo "[xiaozhi-login] 登录成功 ✅"
echo "  userId    : $USER_ID"
echo "  username  : $USERNAME"
echo "  telephone : $TEL"
echo "  role      : $ROLE"
echo "  token     : $(mask_token "$TOKEN")"
echo "  saved to  : $TOKEN_FILE"
echo
echo "后续在当前 shell 复用 token，可执行:"
echo "  export XIAOZHI_TOKEN=\"\$(python3 -c 'import json; print(json.load(open(\"$TOKEN_FILE\"))[\"token\"])')\""
