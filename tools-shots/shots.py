import re, time
from playwright.sync_api import sync_playwright
OUT = 'out/'
def log(*a): print(*a, flush=True)
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
    pg = ctx.new_page()
    pg.on('console', lambda m: log('console:', m.text[:150]) if m.type == 'error' else None)
    pg.goto('http://localhost:8099/', wait_until='load')
    pg.wait_for_timeout(7000)
    pg.screenshot(path=OUT + '00_first.png')
    # turn on accessibility so the controls can be found by name
    try:
        pg.evaluate("document.querySelector('flt-semantics-placeholder') && document.querySelector('flt-semantics-placeholder').click()")
        pg.wait_for_timeout(1500)
    except Exception as e:
        log('placeholder', e)
    log('semantics host present:', pg.evaluate("!!document.querySelector('flt-semantics-host')"))
    html = pg.evaluate("document.querySelector('flt-semantics-host') ? document.querySelector('flt-semantics-host').innerHTML.slice(0,6000) : ''")
    log('SEM:', html)
    b.close()
