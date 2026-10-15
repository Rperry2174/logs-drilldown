"""Fails while grafana/logs-drilldown#1996 exists: 'info' and 'debug' share a color in the log-volume chart legend.
Run: demo/repro-check.sh   (stack: demo/start.sh)
Needs the stack up (demo/start.sh; Grafana :3310, Loki :3110 seeded by demo/seed.py).
Env: GRAFANA_PORT (3310), SHOT (screenshot path), CROP (crop path), CHROME."""
import os, json
from playwright.sync_api import sync_playwright
PORT = os.environ.get("GRAFANA_PORT", "3310")
URL = f"http://127.0.0.1:{PORT}/a/grafana-lokiexplore-app/explore?var-ds=loki&from=now-1h&to=now"
HERE = os.path.dirname(os.path.abspath(__file__))
JS = """() => { const out = {};
  for (const el of document.querySelectorAll('*')) {
    const t = el.textContent.trim(); if (t !== 'info' && t !== 'debug') continue;
    const row = el.closest('tr, [class*="Legend"], li'); if (!row) continue;
    for (const c of row.querySelectorAll('*')) { const bg = getComputedStyle(c).backgroundColor;
      if (bg && bg !== 'rgba(0, 0, 0, 0)' && c.offsetWidth > 0 && c.offsetWidth <= 24) { out[t] = bg; break; } }
  } return out; }"""

def test_info_debug_colors_differ():
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--no-sandbox"], **({"executable_path": os.environ["CHROME"]} if os.environ.get("CHROME") else {}))
        pg = b.new_page(viewport={"width": 1440, "height": 900})
        pg.goto(URL, wait_until="load", timeout=120000)
        pg.wait_for_selector("text=level-mix-api", timeout=90000)
        pg.wait_for_selector("td:has-text('debug'), :text-is('debug')", timeout=90000)
        pg.wait_for_timeout(4000)
        colors = pg.evaluate(JS)
        if os.environ.get("SHOT"): pg.screenshot(path=os.environ["SHOT"])
        if os.environ.get("CROP"):
            panel = pg.locator("text=level-mix-api").first.locator("xpath=ancestor::*[.//td][1]")
            panel.screenshot(path=os.environ["CROP"])
        b.close()
    print("legend colors:", json.dumps(colors))
    assert {"info", "debug"} <= colors.keys(), f"legend swatches not found: {colors}"
    assert colors["info"] != colors["debug"], f"info and debug share a color ({colors['info']}) - bug #1996 present"

if __name__ == "__main__":
    test_info_debug_colors_differ(); print("PASS")
