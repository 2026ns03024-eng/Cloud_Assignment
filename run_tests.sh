#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

WEBHOOK="${WEBHOOK_URL:-https://httpbin.org/post}"

install_conf() {
  cat >"${HOME}/.monitor_conf" <<EOF
MAX_DISK=80
ERROR_LIMIT=${1}
WEBHOOK_URL=${WEBHOOK}
LOG_FILE=access.log
EOF
}

echo "=== Test: decline scan ==="
./generate_access_log.sh access.log 50
cp access.log access.log.bak
install_conf 5
printf 'n\n' | ./cloud_monitor.sh | head -1
test -f access.log && echo "OK: log preserved after decline"

echo "=== Test: scan with high ERROR_LIMIT (no webhook) ==="
install_conf 9999
./generate_access_log.sh access.log 200
printf 'y\n' | ./cloud_monitor.sh | tee /tmp/cm_out.json | jq -e '.alerts.webhook_sent == false' >/dev/null
test ! -f access.log && echo "OK: log rotated"
ls "${HOME}/archive"/access-*.log.gz | tail -1

echo "=== Test: alert + webhook ==="
install_conf 5
./generate_access_log.sh access.log 1200
printf 'y\n' | ./cloud_monitor.sh | jq -e '.alerts.error_limit_exceeded == true' >/dev/null
echo "OK: alert path"

echo "=== Test: missing log ==="
install_conf 5
printf 'y\n' | ./cloud_monitor.sh 2>/dev/null && exit 1 || echo "OK: missing log rejected"

echo "=== Test: invalid config ==="
echo "BADLINE" >"${HOME}/.monitor_conf"
printf 'y\n' | ./cloud_monitor.sh 2>/dev/null && exit 1 || echo "OK: bad config rejected"

install_conf 5
echo "All automated tests passed."
