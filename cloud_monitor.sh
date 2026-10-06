#!/bin/bash
# Author: Dhruv Kumar

# folder where this script is kept
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# read settings from config file 
CONF="$HOME/.monitor_conf"
if [ ! -f "$CONF" ]; then
  echo "Config file not found: $CONF"
  exit 1
fi

MAX_DISK=$(grep "^MAX_DISK=" "$CONF" | cut -d= -f2)
ERROR_LIMIT=$(grep "^ERROR_LIMIT=" "$CONF" | cut -d= -f2)
WEBHOOK_URL=$(grep "^WEBHOOK_URL=" "$CONF" | cut -d= -f2)
LOG_FILE=$(grep "^LOG_FILE=" "$CONF" | cut -d= -f2)

if [ -z "$MAX_DISK" ] || [ -z "$ERROR_LIMIT" ] || [ -z "$WEBHOOK_URL" ] || [ -z "$LOG_FILE" ]; then
  echo "Please set MAX_DISK, ERROR_LIMIT, WEBHOOK_URL and LOG_FILE in $CONF"
  exit 1
fi

# full path of access log
if [[ "$LOG_FILE" == /* ]]; then
  LOG_PATH="$LOG_FILE"
else
  LOG_PATH="$SCRIPT_DIR/$LOG_FILE"
fi

# guardrail - ask user before scan 
read -p "Proceed with system scan? (y/n): " ans
ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
if [ "$ans" != "y" ] && [ "$ans" != "yes" ]; then
  echo "Scan cancelled."
  exit 0
fi

if [ ! -f "$LOG_PATH" ]; then
  echo "Log file missing: $LOG_PATH"
  exit 1
fi

start_time=$(date +%s)
ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
host=$(hostname)

# --- system metrics using df and load average ---
disk_line=$(df -P / | tail -1)
disk_pct=$(echo "$disk_line" | awk '{print $5}' | tr -d '%')

if [ -f /proc/loadavg ]; then
  read load1 load5 load15 rest < /proc/loadavg
else
  load_raw=$(sysctl -n vm.loadavg | tr -d '{}')
  load1=$(echo "$load_raw" | awk '{print $1}')
  load5=$(echo "$load_raw" | awk '{print $2}')
  load15=$(echo "$load_raw" | awk '{print $3}')
fi

# --- parse access.log ---
total=$(wc -l < "$LOG_PATH" | tr -d ' ')
c2xx=$(grep -cE 'HTTP/1\.[01]" 2[0-9]{2} ' "$LOG_PATH" || true)
c4xx=$(grep -cE 'HTTP/1\.[01]" 4[0-9]{2} ' "$LOG_PATH" || true)
c5xx=$(grep -cE 'HTTP/1\.[01]" 5[0-9]{2} ' "$LOG_PATH" || true)

# few sample 5xx lines for JSON
samples="["
first=1
while IFS= read -r line; do
  code=$(echo "$line" | awk '{print $(NF-1)}')
  path=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
  tstamp=$(echo "$line" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
  if [ $first -eq 1 ]; then
    first=0
  else
    samples="$samples,"
  fi
  samples="$samples{\"status\":$code,\"path\":\"$path\",\"timestamp\":\"$tstamp\"}"
done < <(grep -E 'HTTP/1\.[01]" 5[0-9]{2} ' "$LOG_PATH" | head -5)
samples="$samples]"

# check alerts using config limits
disk_alert=false
error_alert=false
webhook_sent=false

if [ "$disk_pct" -ge "$MAX_DISK" ]; then
  disk_alert=true
fi
if [ "$c5xx" -gt "$ERROR_LIMIT" ]; then
  error_alert=true
fi

# build JSON output (core requirement)
json=$(cat <<EOF
{
  "timestamp": "$ts",
  "hostname": "$host",
  "metrics": {
    "disk_mount": "/",
    "disk_usage_percent": $disk_pct,
    "cpu_load_1m": $load1,
    "cpu_load_5m": $load5,
    "cpu_load_15m": $load15
  },
  "log_analysis": {
    "log_file": "$LOG_FILE",
    "total_requests": $total,
    "count_2xx": $c2xx,
    "count_4xx": $c4xx,
    "count_5xx": $c5xx,
    "error_samples": $samples
  },
  "thresholds": {
    "max_disk_percent": $MAX_DISK,
    "error_limit": $ERROR_LIMIT
  },
  "alerts": {
    "disk_exceeded": $disk_alert,
    "error_limit_exceeded": $error_alert,
    "webhook_sent": $webhook_sent
  }
}
EOF
)

# webhook if critical issue found 
if [ "$disk_alert" = true ] || [ "$error_alert" = true ]; then
  if curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$json" >/dev/null; then
    webhook_sent=true
    json=$(echo "$json" | sed 's/"webhook_sent": false/"webhook_sent": true/')
  fi
fi

# print valid JSON
if command -v jq >/dev/null 2>&1; then
  json=$(echo "$json" | jq .)
fi
echo "$json"

# audit log in hidden file
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "$ts errors_5xx=$c5xx duration_sec=$duration" >> "$HOME/.monitor_history"

# rotate log - gzip and move to archive
mkdir -p "$HOME/archive"
archive_name="access-$(date '+%Y-%m-%d_%H%M%S').log.gz"
gzip -c "$LOG_PATH" > "$HOME/archive/$archive_name"
rm -f "$LOG_PATH"
