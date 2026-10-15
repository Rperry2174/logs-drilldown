#!/usr/bin/env bash
# Local repro stack for grafana/logs-drilldown#1996 (info and debug share a color), no Docker.
#   Loki 3.5.5 :3110 + Grafana Enterprise 13.2.4 :3310 with ./dist mounted + demo/seed.py.
#   demo/start.sh [--build]     demo/stop.sh [--wipe]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_HOME="${DEMO_HOME:-$HOME/.cache/logs-drilldown-demo}"
GF_VER="${GF_VER:-13.2.4}"; LOKI_VER=3.5.5; GRAFANA_PORT=3310; LOKI_PORT=3110
mkdir -p "$DEMO_HOME"/{bin,run/plugins,run/prov/datasources,run/prov/plugins,logs,data}
os=$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$(uname -m)
case "$arch" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; esac
[ -x "$DEMO_HOME/bin/grafana-$GF_VER/bin/grafana" ] || "$REPO/demo/fetch-grafana.sh" "$GF_VER" "$DEMO_HOME/bin"
if [ ! -x "$DEMO_HOME/bin/loki" ]; then
  echo "downloading Loki $LOKI_VER…"
  curl -fsSL -o "$DEMO_HOME/bin/loki.zip" "https://github.com/grafana/loki/releases/download/v$LOKI_VER/loki-$os-$arch.zip"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$DEMO_HOME/bin/loki.zip" "$DEMO_HOME/bin"
  mv "$DEMO_HOME/bin/loki-$os-$arch" "$DEMO_HOME/bin/loki"; chmod +x "$DEMO_HOME/bin/loki"; rm -f "$DEMO_HOME/bin/loki.zip"
fi
[ -n "${DEMO_DOWNLOAD_ONLY:-}" ] && { echo "binaries ready in $DEMO_HOME/bin"; exit 0; }
if [ "${1:-}" = "--build" ] || [ ! -f "$REPO/dist/module.js" ]; then
  (cd "$REPO" && pnpm install --frozen-lockfile --ignore-scripts && pnpm run build)
fi
R="$DEMO_HOME/run"; D="$DEMO_HOME/data"
wait_ready() {  # name url logfile — fail loudly rather than reporting a stack that never came up
  # Deadline, not an iteration count: a port that accepts but never answers makes each
  # probe cost its full --max-time, which would stretch a 90s budget into minutes.
  local deadline=$((SECONDS + 90))
  while [ "$SECONDS" -lt "$deadline" ]; do
    curl -sf --max-time 5 "$2" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "$1 never became ready; last lines of $3:" >&2; tail -20 "$3" >&2; return 1
}
cat > "$R/loki.yaml" <<Y
auth_enabled: false
server: {http_listen_port: $LOKI_PORT, grpc_listen_port: 9196}
common:
  instance_addr: 127.0.0.1
  path_prefix: $D/loki
  storage: {filesystem: {chunks_directory: $D/loki/chunks, rules_directory: $D/loki/rules}}
  replication_factor: 1
  ring: {kvstore: {store: inmemory}}
schema_config:
  configs: [{from: 2024-01-01, store: tsdb, object_store: filesystem, schema: v13, index: {prefix: index_, period: 24h}}]
limits_config: {allow_structured_metadata: true, volume_enabled: true, discover_log_levels: true, reject_old_samples: false}
pattern_ingester: {enabled: true}
memberlist: {bind_port: 7966}
analytics: {reporting_enabled: false}
Y
cat > "$R/prov/datasources/loki.yaml" <<Y
apiVersion: 1
datasources:
  - { uid: loki, type: loki, name: Loki, url: "http://127.0.0.1:$LOKI_PORT", isDefault: true }
Y
printf 'apiVersion: 1\napps:\n  - { type: grafana-lokiexplore-app, disabled: false }\n' > "$R/prov/plugins/app.yaml"
ln -sfn "$REPO/dist" "$R/plugins/grafana-lokiexplore-app"
seeded=0
if ! curl -sf --max-time 5 "http://127.0.0.1:$LOKI_PORT/ready" >/dev/null 2>&1; then
  nohup "$DEMO_HOME/bin/loki" -config.file="$R/loki.yaml" > "$DEMO_HOME/logs/loki.log" 2>&1 < /dev/null & echo $! > "$R/loki.pid"
  wait_ready Loki "http://127.0.0.1:$LOKI_PORT/ready" "$DEMO_HOME/logs/loki.log"
fi
LOKI_PORT=$LOKI_PORT python3 "$REPO/demo/seed.py"
if ! curl -sf --max-time 5 "http://127.0.0.1:$GRAFANA_PORT/api/health" >/dev/null 2>&1; then
  G="$DEMO_HOME/bin/grafana-$GF_VER"
  GF_PATHS_DATA="$D/grafana" GF_PATHS_LOGS="$DEMO_HOME/logs" GF_PATHS_PLUGINS="$R/plugins" GF_PATHS_PROVISIONING="$R/prov" \
  GF_SERVER_HTTP_PORT=$GRAFANA_PORT GF_SERVER_HTTP_ADDR=127.0.0.1 GF_AUTH_ANONYMOUS_ENABLED=true GF_AUTH_ANONYMOUS_ORG_ROLE=Admin GF_AUTH_DISABLE_LOGIN_FORM=true \
  GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=grafana-lokiexplore-app GF_PLUGINS_PREINSTALL_DISABLED=true \
  GF_ANALYTICS_REPORTING_ENABLED=false GF_ANALYTICS_CHECK_FOR_UPDATES=false GF_NEWS_NEWS_FEED_ENABLED=false \
  nohup "$G/bin/grafana" server --homepath "$G" > "$DEMO_HOME/logs/grafana.stdout" 2>&1 < /dev/null & echo $! > "$R/grafana.pid"
  wait_ready Grafana "http://127.0.0.1:$GRAFANA_PORT/api/health" "$DEMO_HOME/logs/grafana.stdout"
fi
echo "up: Grafana :$GRAFANA_PORT, Loki :$LOKI_PORT"
echo "Open: http://127.0.0.1:$GRAFANA_PORT/a/grafana-lokiexplore-app/explore?var-ds=loki&from=now-1h&to=now"
