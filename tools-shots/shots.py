import re, json
from playwright.sync_api import sync_playwright
OUT = 'out/'
def log(*a): print(*a, flush=True)

FIND = """
([text, nav]) => {
  const norm = s => (s || '').replace(/\\s+/g, ' ').trim();
  const cands = [];
  document.querySelectorAll('flt-semantics').forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width < 4 || r.height < 4) return;
    const first = norm((el.innerText || '').split('\\n')[0]);
    const lab = norm(el.getAttribute('aria-label'));
    if (first === text || lab === text || lab.startsWith(text + ' ') || first.startsWith(text + ' ')) {
      cands.push({x: r.x + r.width/2, y: r.y + r.height/2, area: r.width*r.height, top: r.y});
    }
  });
  if (!cands.length) return null;
  if (nav) { cands.sort((a,b) => b.top - a.top); return cands[0]; }
  cands.sort((a,b) => a.area - b.area); return cands[0];
}
"""
TEXTS = """
() => [...document.querySelectorAll('flt-semantics')].map(e => (e.innerText||'').split('\\n')[0].trim()).filter(t => t).slice(0,60)
"""

class Shot:
    def __init__(self, pg): self.pg = pg; self.n = 0
    def snap(self, name):
        self.pg.mouse.move(388, 430)
        self.pg.wait_for_timeout(5200 if name in ('a_fin','r_dues','a_home') else 1600)
        self.pg.screenshot(path=OUT + name + '.png'); log('SNAP', name)
    def find(self, text, nav=False):
        return self.pg.evaluate(FIND, [text, nav])
    def tap(self, text, nav=False, scroll=True):
        for i in range(8):
            c = self.find(text, nav)
            if c and 0 < c['y'] < 800:
                self.pg.mouse.click(c['x'], c['y']); self.pg.wait_for_timeout(1400); return True
            if not scroll: break
            self.pg.mouse.move(195, 500); self.pg.mouse.wheel(0, 380); self.pg.wait_for_timeout(500)
        log('NOT FOUND', text, 'visible:', self.pg.evaluate(TEXTS)[:25])
        return False
    def back(self):
        self.pg.go_back(); self.pg.wait_for_timeout(1500)
        if not self.find('More', True) and not self.find('Home', True):
            self.pg.mouse.click(28, 48); self.pg.wait_for_timeout(1200)

def login(sh, email):
    pg = sh.pg
    pg.goto('http://localhost:8099/', wait_until='load'); pg.wait_for_timeout(6500)
    pg.evaluate("document.querySelector('flt-semantics-placeholder') && document.querySelector('flt-semantics-placeholder').click()")
    pg.wait_for_timeout(1500)
    pg.mouse.click(195, 362); pg.wait_for_timeout(400); pg.keyboard.type(email, delay=25)
    pg.mouse.click(195, 422); pg.wait_for_timeout(400); pg.keyboard.type('Demo@1234', delay=25)
    pg.mouse.click(195, 490); pg.wait_for_timeout(3500)

def more_tile(sh, tile, name):
    sh.tap('More', True); sh.pg.wait_for_timeout(700)
    # back to top of the More list
    sh.pg.mouse.move(195, 400); sh.pg.mouse.wheel(0, -3000); sh.pg.wait_for_timeout(500)
    if sh.tap(tile):
        sh.snap(name); sh.back()
    log('after', name, sh.pg.evaluate(TEXTS)[:8])

with sync_playwright() as p:
    b = p.chromium.launch()
    for role, email, steps in [
        ('r', 'resident@demo.test', [('Home','r_home'),('Book','r_book'),('Parking','r_parking'),('Dues','r_dues'),('More','r_more')]),
        ('a', 'admin@demo.test', [('Home','a_home'),('Units','a_units'),('Facility','a_fac'),('Finance','a_fin'),('More','a_more')]),
    ]:
        ctx = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
        pg = ctx.new_page()
        pg.on('console', lambda m: None)
        sh = Shot(pg)
        if role == 'r':
            pg.goto('http://localhost:8099/', wait_until='load'); pg.wait_for_timeout(6500)
            sh.snap('r_login')
        login(sh, email)
        log(role, 'after login texts:', pg.evaluate(TEXTS)[:25])
        for label, name in steps:
            if label == 'Home':
                sh.snap(name); continue
            if sh.tap(label, True): sh.snap(name)
        if role == 'r':
            for tile, name in [('My reservations','r_res'),('Complaints','r_gr'),('Events','r_events'),('Polls & voting','r_polls')]:
                more_tile(sh, tile, name)
        else:
            for tile, name in [('Announcements & events','a_ann'),('Complaints','a_req'),('Polls & voting','a_polls'),('Maintenance','a_maint'),('Expenses','a_exp'),('Activity log','a_log')]:
                more_tile(sh, tile, name)
        ctx.close()
    b.close()
