#!/usr/bin/env bash
# repro check for grafana/logs-drilldown#1996 (info and debug share a color in the log-volume legend).
# Exit 1 while the bug exists (expected on main / pre-fix), 0 once fixed. Stack must be up (demo/start.sh).
set -uo pipefail
cd "$(dirname "$0")"
CHROME="$(./find-chrome.sh)"; export CHROME
python3 repro_check.py "$@"; rc=$?
[ $rc -eq 0 ] && echo "PASS (colors differ)" || echo "FAIL (bug reproduced or stack not ready), exit $rc"
exit $rc
