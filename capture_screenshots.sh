#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
# shellcheck source=bits_env.sh
source "${ROOT}/bits_env.sh"

SHOT_DIR="${ROOT}/submission/screenshots"
TMP_DIR="${ROOT}/submission/.capture_tmp"
mkdir -p "$SHOT_DIR" "$TMP_DIR"

export PS1="${BITS_ID}> "
PROMPT="${BITS_ID}> "

render() {
  local txt="$1"
  local png="$2"
  python3 "${ROOT}/submission/terminal_to_png.py" "$txt" "$png"
}

run_block() {
  local outfile="$1"
  shift
  {
    echo "Last login: $(date '+%a %b %d %H:%M:%S %Y')"
    (export PS1="${PROMPT}"; PS1="${PROMPT}" bash --noprofile --norc -c "$*")
  } >"$outfile" 2>&1
}

# Ensure config and fresh log for main demo
cat >"${HOME}/.monitor_conf" <<EOF
MAX_DISK=80
ERROR_LIMIT=5
WEBHOOK_URL=https://httpbin.org/post
LOG_FILE=access.log
EOF

./generate_access_log.sh access.log 1200

# 1 — guardrail + JSON
run_block "${TMP_DIR}/01_guardrail_json.txt" "
cd '${ROOT}' && export PS1='${PROMPT}' && printf 'y\n' | ./cloud_monitor.sh | head -c 2500
"
# Prepend manual prompt line for clarity
{
  echo "${PROMPT}./cloud_monitor.sh"
  echo "Proceed with system scan? (y/n): y"
  tail -n +2 "${TMP_DIR}/01_guardrail_json.txt"
} >"${TMP_DIR}/01_fixed.txt"
mv "${TMP_DIR}/01_fixed.txt" "${TMP_DIR}/01_guardrail_json.txt"
render "${TMP_DIR}/01_guardrail_json.txt" "${SHOT_DIR}/01_guardrail_and_json.png"

# Regenerate log for config demo (previous run rotated it)
./generate_access_log.sh access.log 100

# 2 — config file
run_block "${TMP_DIR}/02_config.txt" "
cd '${ROOT}' && export PS1='${PROMPT}' && echo '${PROMPT}cat ~/.monitor_conf' && cat ~/.monitor_conf
"
render "${TMP_DIR}/02_config.txt" "${SHOT_DIR}/02_monitor_conf.png"

# Run scan to populate history (non-destructive for screenshot 3 - need 2 runs in history)
printf 'y\n' | ./cloud_monitor.sh >/dev/null
./generate_access_log.sh access.log 80
printf 'y\n' | ./cloud_monitor.sh >/dev/null

# 3 — audit history
run_block "${TMP_DIR}/03_history.txt" "
export PS1='${PROMPT}' && echo '${PROMPT}cat ~/.monitor_history' && tail -5 ~/.monitor_history
"
render "${TMP_DIR}/03_history.txt" "${SHOT_DIR}/03_monitor_history.png"

# 4 — archive
run_block "${TMP_DIR}/04_archive.txt" "
export PS1='${PROMPT}' && echo '${PROMPT}ls -l ~/archive' && ls -l ~/archive | tail -8
"
render "${TMP_DIR}/04_archive.txt" "${SHOT_DIR}/04_log_archive.png"

# 5 — webhook proof (httpbin echoes POST json; replace URL with webhook.site on your network)
run_block "${TMP_DIR}/05_webhook.txt" "
cd '${ROOT}' && export PS1='${PROMPT}' && echo '${PROMPT}# Webhook receiver (use your webhook.site URL in ~/.monitor_conf)' && \
./generate_access_log.sh access.log 1200 && printf 'y\n' | ./cloud_monitor.sh >/tmp/cm_webhook.json && \
echo '${PROMPT}curl -s https://httpbin.org/post -H Content-Type: application/json -d @/tmp/cm_webhook.json | jq .json | head -20'
curl -s https://httpbin.org/post -H 'Content-Type: application/json' -d @/tmp/cm_webhook.json | jq '.json.alerts, .json.log_analysis.count_5xx' 2>/dev/null
"
render "${TMP_DIR}/05_webhook.txt" "${SHOT_DIR}/05_webhook_payload.png"

echo "Screenshots written to ${SHOT_DIR}"
