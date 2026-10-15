# logs-drilldown #1996 repro kit

`main` = upstream main with the fix reverted (bug present; pre-fix reference 807ae881dc, pre-fix; fixed upstream in PR #2021) plus this demo/ kit and `.cursor/`.

- `demo/start.sh [--build]`: Loki 3.5.5 :3110, Grafana 12.3.0 :3310 (./dist mounted), seeds `level-mix-api` via `demo/seed.py`
- `demo/repro-check.sh`: exit 1 while info/debug share a color (expected pre-fix), 0 once fixed
- `demo/stop.sh [--wipe]`

No Docker needed. Grafana falls back to Docker Hub image layers when dl.grafana.com is blocked; the check falls back to system Chrome.
PRs from agents go to Rperry2174/logs-drilldown only, never grafana/*.
