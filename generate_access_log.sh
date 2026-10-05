#!/usr/bin/env bash
# Local test helper only — not submitted per assignment brief.
set -euo pipefail

OUT="${1:-access.log}"
LINES="${2:-1200}"

endpoints=(
  "/index.html" "/api/data" "/image.png" "/api/login" "/health"
  "/static/app.js" "/api/users" "/favicon.ico" "/api/search"
)
methods=(GET POST GET GET GET GET GET POST GET)
statuses=(200 200 404 500 502 200 200 404 500)

random_ip() {
  printf "%d.%d.%d.%d" $((RANDOM % 223 + 1)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 254 + 1))
}

random_ts() {
  local day=$((RANDOM % 28 + 1))
  local hour=$((RANDOM % 24))
  local min=$((RANDOM % 60))
  local sec=$((RANDOM % 60))
  printf "[19/Aug/2026:%02d:%02d:%02d +0530]" "$hour" "$min" "$sec"
}

: >"$OUT"
for ((i = 1; i <= LINES; i++)); do
  ip="$(random_ip)"
  ts="$(random_ts)"
  idx=$((RANDOM % ${#endpoints[@]}))
  ep="${endpoints[$idx]}"
  meth="${methods[$idx]}"
  # Bias toward 5xx so alerting demos work (~12% 5xx)
  roll=$((RANDOM % 100))
  if ((roll < 12)); then
    st=$((RANDOM % 2 == 0 ? 500 : 502))
  elif ((roll < 28)); then
    st=404
  else
    st=200
  fi
  bytes=$((RANDOM % 4096 + 64))
  printf '%s - - %s "%s %s HTTP/1.1" %s %s\n' "$ip" "$ts" "$meth" "$ep" "$st" "$bytes" >>"$OUT"
done

echo "Wrote $LINES lines to $OUT"
