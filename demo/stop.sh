#!/usr/bin/env bash
# Stop the demo stack (pattern-based: saved Grafana pids are unreliable). --wipe deletes data.
DEMO_HOME="${DEMO_HOME:-$HOME/.cache/logs-drilldown-demo}"
pats=("$DEMO_HOME/bin/grafana-" "$DEMO_HOME/bin/loki")
for pat in "${pats[@]}"; do pkill -f "$pat" 2>/dev/null; done
# Block until the ports are released: Loki takes seconds to shut down, and a caller that
# restarts immediately otherwise loses the race and the new process dies on "address in use".
for pat in "${pats[@]}"; do
  for i in $(seq 1 30); do
    pids=$(pgrep -f "$pat" 2>/dev/null) || break
    [ "$i" -eq 20 ] && kill -9 $pids 2>/dev/null
    sleep 1
  done
done
rm -f "$DEMO_HOME"/run/*.pid
[ "${1:-}" = "--wipe" ] && rm -rf "$DEMO_HOME/data" && echo "wiped $DEMO_HOME/data"
exit 0
