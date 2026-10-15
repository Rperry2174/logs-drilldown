"""Seed Loki :3110 with one service (level-mix-api) emitting interleaved info and debug logs over the last 60 min."""
import json, time, random, urllib.request, os
URL = f"http://127.0.0.1:{os.environ.get('LOKI_PORT','3110')}/loki/api/v1/push"
now = time.time_ns(); streams = {"info": [], "debug": []}
for i in range(3600):
    ts = now - (3600 - i) * 1_000_000_000
    lvl = "info" if random.random() < 0.6 else "debug"
    streams[lvl].append([str(ts), f'level={lvl} msg="{"request served" if lvl=="info" else "cache lookup"}" path=/api/item/{i%50}'])
body = {"streams": [{"stream": {"service_name": "level-mix-api", "level": l, "env": "demo"}, "values": v} for l, v in streams.items()]}
r = urllib.request.urlopen(urllib.request.Request(URL, json.dumps(body).encode(), {"Content-Type": "application/json"}), timeout=120)
print("seeded", {k: len(v) for k, v in streams.items()}, r.status)
