# Cloud Computing Assignment 1 — Telemetry Agent

## Files

| File | Purpose |
|------|---------|
| `cloud_monitor.sh` | Submitted telemetry agent |
| `monitor_conf.sample` | Template for `~/.monitor_conf` |
| `generate_access_log.sh` | Test log generator (not submitted) |
| `submission/report.md` | Submission document with screenshots and full code |
| `bits_env.sh` | Set your BITS ID for screenshot prompts |

## Quick start

```bash
cp monitor_conf.sample ~/.monitor_conf
# Edit WEBHOOK_URL to your https://webhook.site/... URL
./generate_access_log.sh access.log 1200
export PS1='YOUR_BITS_ID> '
./cloud_monitor.sh
```

## Verify

```bash
./run_tests.sh
./capture_screenshots.sh
```
# Cloud_Assignment
