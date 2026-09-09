import math, json, io

THEMES = [
 dict(key="haldi", name="Haldi", tag="Warm kitchen light",
   blurb="Turmeric on warm paper. The palette of a spice tin and an afternoon kitchen — the only direction here that feels like it belongs to the food it tracks.",
   face="Fraunces", body="IBM Plex Sans", faceNote="Fraunces for figures · IBM Plex Sans for UI",
   best="you want the app to feel like it belongs to the kitchen",
   pros=["Distinctly Indian without costume-drama clichés","Warm neutrals are easy on the eyes for a morning app","Gold accent reads as achievement, not alarm"],
   cons=["Warm grounds can feel dated if the type is careless","Gold on white needs care to stay AA legible"],
   light=dict(bg="#f7f3ec",surface="#fffdf8",surface2="#f1ebe0",line="#e2d9c8",ink="#211c14",ink2="#5a5044",ink3="#8a7f6e",
              accent="#9c6408",accentInk="#fffdf8",accentSoft="#f6e7c8",track="#eae1d0",
              s=["#b5451f","#2b6ba8","#d9a017","#3f8a4f"], ok="#2e7d4f", low="#a06d0c", high="#7a5ea8"),
   dark=dict(bg="#171410",surface="#201c17",surface2="#2a251e",line="#39322a",ink="#f6f0e6",ink2="#c0b5a4",ink3="#8e8375",
              accent="#e0a72c",accentInk="#1a1610",accentSoft="#3a2f18",track="#332c24",
              s=["#cf5f2e","#4a8fd4","#c08207","#1f9a68"], ok="#4aa873", low="#d0a03a", high="#a893d8")),

 dict(key="neem", name="Neem", tag="Fresh and plain-spoken",
   blurb="Green-forward and crisp. The expected choice for a nutrition app, executed with restraint — no gradients, no glow, just clean surfaces and one confident accent.",
   face="Figtree", body="Figtree", faceNote="Figtree throughout",
   best="you want zero explanation — it reads as a health app instantly",
   pros=["Instantly legible as a health app; zero learning curve","White surfaces make the charts the loudest thing on screen","Green accent tests well for 'on track' without extra colour"],
   cons=["The most conventional of the five — safe, not memorable","Green accent sits close to the 'on target' status hue"],
   light=dict(bg="#f3f6f2",surface="#ffffff",surface2="#eaf0e8",line="#d8e2d5",ink="#15201a",ink2="#4a5750",ink3="#7c8a82",
              accent="#2f7a4f",accentInk="#ffffff",accentSoft="#dcece1",track="#e2ebe0",
              s=["#b8532b","#3f6fa8","#c99a12","#2e8556"], ok="#2e7d4f", low="#a06d0c", high="#7a5ea8"),
   dark=dict(bg="#111512",surface="#181d19",surface2="#212722",line="#2e372f",ink="#eaf1ec",ink2="#adbcb2",ink3="#7d8b82",
              accent="#4faa78",accentInk="#0f140f",accentSoft="#1c2f24",track="#28302a",
              s=["#cf6330","#4f8ad0","#b8860a","#2b9c62"], ok="#4aa873", low="#d0a03a", high="#a893d8")),

 dict(key="indigo", name="Indigo", tag="Calm instrument",
   blurb="Deep indigo on cool paper — the colour of block-printed cloth, used as a tool's chrome rather than as decoration. Reads as something you consult, not something that nags.",
   face="IBM Plex Sans", body="IBM Plex Sans", faceNote="IBM Plex Sans throughout",
   best="the household reads numbers more than it reads charts",
   pros=["Feels like an instrument: serious, quiet, precise","Cool neutrals keep four macro hues clearly separated","Best of the five for dense numeric screens"],
   cons=["Least 'food' of the five — could feel clinical","Dark mode needs care not to drift toward navy mush"],
   light=dict(bg="#f2f3f8",surface="#ffffff",surface2="#e9ebf4",line="#d6d9e8",ink="#161829",ink2="#4b4f66",ink3="#7b8098",
              accent="#3b4d9e",accentInk="#ffffff",accentSoft="#dfe3f4",track="#e3e6f1",
              s=["#c1572d","#1f6fa5","#c7961a","#0f8a5e"], ok="#2e7d4f", low="#a06d0c", high="#7a5ea8"),
   dark=dict(bg="#0f1119",surface="#161927",surface2="#1e2233",line="#2b3045",ink="#e9ebf6",ink2="#a8adc4",ink3="#787e96",
              accent="#8b99ea",accentInk="#0e1018",accentSoft="#232847",track="#242940",
              s=["#d16536","#3f92cf","#bb8a0c","#2a9b6e"], ok="#4aa873", low="#d0a03a", high="#a893d8")),

 dict(key="kora", name="Kora", tag="Quiet chrome, loud data",
   blurb="Named for undyed cotton. The interface itself is nearly colourless — every hue on screen belongs to your data. The most restrained option, and the one that ages slowest.",
   face="IBM Plex Sans", body="IBM Plex Sans", faceNote="IBM Plex Sans throughout",
   best="you expect to add nutrients and charts over the years",
   pros=["Colour means data and nothing else — the clearest chart reading","Never looks dated; no trend to fall out of","Works best if you add nutrients or charts later"],
   cons=["Little personality; can read as unfinished to some","Relies entirely on typography and spacing being right"],
   light=dict(bg="#f6f6f4",surface="#ffffff",surface2="#eeeeeb",line="#e0e0dc",ink="#1a1a18",ink2="#55554f",ink3="#87877f",
              accent="#2f4858",accentInk="#ffffff",accentSoft="#e3e8ec",track="#e8e8e4",
              s=["#b04f22","#2a6f9e","#b08a1c","#25845a"], ok="#2e7d4f", low="#a06d0c", high="#7a5ea8"),
   dark=dict(bg="#131313",surface="#1a1a19",surface2="#232322",line="#31312f",ink="#f0f0ec",ink2="#b3b3ac",ink3="#83837c",
              accent="#9fbcce",accentInk="#121212",accentSoft="#242c31",track="#2a2a28",
              s=["#c66236","#3f8cc4","#b3860f","#2f9868"], ok="#4aa873", low="#d0a03a", high="#a893d8")),

 dict(key="nilgiri", name="Nilgiri", tag="Built for night",
   blurb="Designed dark-first, with the light mode derived from it rather than the other way round. Teal on near-black — for logging dinner at 11pm without being dazzled.",
   face="Figtree", body="Figtree", faceNote="Figtree throughout",
   best="most logging happens after dark",
   pros=["The best dark mode of the five, by design not by inversion","Teal accent is uncommon in this category — memorable","High contrast helps at low screen brightness"],
   cons=["Light mode is the weaker half — it is the derived one","Teal can read 'tech product' more than 'household app'"],
   light=dict(bg="#f0f5f5",surface="#ffffff",surface2="#e6eeee",line="#d3e0e0",ink="#0f1e1e",ink2="#44585a",ink3="#75898b",
              accent="#0e7c72",accentInk="#ffffff",accentSoft="#d5eae7",track="#dfeaea",
              s=["#d1683c","#5566cc","#d9a422","#2f8a4f"], ok="#2e7d4f", low="#a06d0c", high="#7a5ea8"),
   dark=dict(bg="#0c1414",surface="#121b1c",surface2="#1a2526",line="#263435",ink="#e6f2f1",ink2="#a3b8b7",ink3="#748887",
              accent="#2cc4b0",accentInk="#08110f",accentSoft="#123230",track="#1f2c2c",
              s=["#d46b3c","#7182e0","#b8860a","#35a166"], ok="#4aa873", low="#d0a03a", high="#a893d8")),
]

FACE_STACK = {
 "Fraunces": "'Fraunces', Georgia, serif",
 "Figtree": "'Figtree', system-ui, sans-serif",
 "IBM Plex Sans": "'IBM Plex Sans', system-ui, sans-serif",
}

def tokens(d, face, body):
    t = [f"--bg:{d['bg']}", f"--surface:{d['surface']}", f"--surface-2:{d['surface2']}",
         f"--line:{d['line']}", f"--ink:{d['ink']}", f"--ink-2:{d['ink2']}", f"--ink-3:{d['ink3']}",
         f"--accent:{d['accent']}", f"--accent-ink:{d['accentInk']}", f"--accent-soft:{d['accentSoft']}",
         f"--track:{d['track']}", f"--ok:{d['ok']}", f"--low:{d['low']}", f"--high:{d['high']}",
         f"--display:{FACE_STACK[face]}", f"--body:{FACE_STACK[body]}"]
    t += [f"--s{i+1}:{c}" for i, c in enumerate(d["s"])]
    return ";".join(t) + ";"

css = []
for th in THEMES:
    css.append(f".th-{th['key']}{{{tokens(th['light'], th['face'], th['body'])}}}")
dark_rules = "".join(f".th-{th['key']}{{{tokens(th['dark'], th['face'], th['body'])}}}" for th in THEMES)
css.append("@media (prefers-color-scheme: dark){:root:not([data-theme=\"light\"]) " +
           " :is(" + ",".join(f'.th-{t["key"]}' for t in THEMES) + "){}}")
# emit dark blocks properly scoped
media_block = "@media (prefers-color-scheme: dark){" + "".join(
    f":root:not([data-theme=\"light\"]) .th-{th['key']}{{{tokens(th['dark'], th['face'], th['body'])}}}" for th in THEMES) + "}"
stamp_block = "".join(
    f":root[data-theme=\"dark\"] .th-{th['key']}{{{tokens(th['dark'], th['face'], th['body'])}}}" for th in THEMES)
css = [c for c in css if not c.startswith("@media (prefers-color-scheme: dark){:root:not")]
THEME_CSS = "\n".join(css) + "\n" + media_block + "\n" + stamp_block

# ---------- ring geometry ----------
R, CX = 46, 60
C = 2 * math.pi * R
RING_MAX = 1.25          # ring full circle = 125% of target
kcal, kcal_t = 1640, 2050
prog_f = (kcal / kcal_t) / RING_MAX
band_a, band_b = 0.90 / RING_MAX, 1.10 / RING_MAX   # tolerance band
tgt_f = 1.0 / RING_MAX

def polar(f, r):
    d = math.radians(f * 360 - 90)
    return CX + r * math.cos(d), CX + r * math.sin(d)

tx1, ty1 = polar(tgt_f, R - 9)
tx2, ty2 = polar(tgt_f, R + 9)
RING = dict(C=round(C, 2), prog=round(prog_f * C, 2), progGap=round(C - prog_f * C, 2),
            bandLen=round((band_b - band_a) * C, 2), bandGap=round(C - (band_b - band_a) * C, 2),
            bandOff=round(-band_a * C, 2),
            tx1=round(tx1, 2), ty1=round(ty1, 2), tx2=round(tx2, 2), ty2=round(ty2, 2))

MACROS = [("Protein", 82, 95, "g", 1), ("Carbs", 198, 240, "g", 2),
          ("Fat", 54, 62, "g", 3), ("Fibre", 18, 29, "g", 4)]

def bar_rows():
    out = []
    for name, val, tgt, unit, slot in MACROS:
        fill = min(val / tgt / RING_MAX, 1.0) * 100
        tick = (1.0 / RING_MAX) * 100
        pct = round(val / tgt * 100)
        state = "on" if pct >= 90 else "low"
        out.append(f'''<div class="mrow">
        <span class="mname">{name}</span>
        <span class="mtrack"><span class="mfill" style="width:{fill:.1f}%;background:var(--s{slot})"></span><span class="mtick" style="left:{tick:.1f}%"></span></span>
        <span class="mval"><b>{val}</b><span class="mmuted">/{tgt}{unit}</span></span>
      </div>''')
    return "\n      ".join(out)

WATER_F = (1.6 / 2.6 / RING_MAX) * 100
WATER_TICK = (1.0 / RING_MAX) * 100

def preview(th):
    return f'''<div class="phone th-{th['key']}">
    <div class="pv">
      <div class="pvtop">
        <div><div class="pvdate">Thursday, 9 September</div><div class="pvwho">Keyur · General health</div></div>
        <span class="chip chip-score">Good <b>78</b></span>
      </div>

      <div class="pvring">
        <svg viewBox="0 0 120 120" role="img" aria-label="1,640 of 2,050 kilocalories, 410 remaining">
          <circle cx="60" cy="60" r="{R}" fill="none" stroke="var(--track)" stroke-width="11"></circle>
          <circle cx="60" cy="60" r="{R}" fill="none" stroke="var(--accent-soft)" stroke-width="11"
                  stroke-dasharray="{RING['bandLen']} {RING['bandGap']}" stroke-dashoffset="{RING['bandOff']}"
                  transform="rotate(-90 60 60)"></circle>
          <circle cx="60" cy="60" r="{R}" fill="none" stroke="var(--accent)" stroke-width="11" stroke-linecap="round"
                  stroke-dasharray="{RING['prog']} {RING['progGap']}" transform="rotate(-90 60 60)"></circle>
          <line x1="{RING['tx1']}" y1="{RING['ty1']}" x2="{RING['tx2']}" y2="{RING['ty2']}"
                stroke="var(--ink-2)" stroke-width="2" stroke-linecap="round"></line>
        </svg>
        <div class="pvringtxt">
          <div class="pvbig">410</div>
          <div class="pvsub">kcal left</div>
        </div>
        <div class="pvringside">
          <div class="kv"><span>Eaten</span><b>1,640</b></div>
          <div class="kv"><span>Target</span><b>2,050</b></div>
          <div class="kv"><span>Band</span><b>1,845–2,255</b></div>
        </div>
      </div>

      <div class="pvsec">
      {bar_rows()}
      </div>

      <div class="pvsec">
        <div class="mrow">
          <span class="mname">Water</span>
          <span class="mtrack"><span class="mfill" style="width:{WATER_F:.1f}%;background:var(--accent)"></span><span class="mtick" style="left:{WATER_TICK:.1f}%"></span></span>
          <span class="mval"><b>1.6</b><span class="mmuted">/2.6L</span></span>
        </div>
        <div class="quick">
          <button type="button" class="qbtn">+250 ml</button>
          <button type="button" class="qbtn">+500 ml</button>
          <button type="button" class="qbtn qbtn-alt">Custom</button>
        </div>
      </div>

      <div class="chips">
        <span class="chip chip-ok"><span class="dot"></span>Protein on track</span>
        <span class="chip chip-low"><span class="dot"></span>Fibre 11 g short</span>
        <span class="chip chip-data"><span class="dot"></span>Micros: 58% covered — not scored</span>
      </div>

      <div class="pvsec">
        <div class="meal"><span class="mealname">Breakfast</span><span class="mealkcal">410</span></div>
        <div class="items">2 Thepla · Chaas 1 glass</div>
        <div class="meal"><span class="mealname">Lunch</span><span class="mealkcal">760</span></div>
        <div class="items">3 Rotli · Gujarati dal · Bhinda nu shaak · Rice</div>
        <div class="meal"><span class="mealname">Snack</span><span class="mealkcal">190</span></div>
        <div class="items">Khakhra · Filter coffee</div>
        <div class="meal meal-empty"><span class="mealname">Dinner</span><span class="mealadd">+ Add</span></div>
      </div>
    </div>
  </div>'''

def swatches(th):
    def row(mode, d):
        cells = "".join(f'<span class="sw" style="background:{c}" title="{c}"></span>' for c in
                        [d["accent"], *d["s"]])
        return f'<div class="swrow"><span class="swlab">{mode}</span>{cells}</div>'
    return row("Light", th["light"]) + row("Dark", th["dark"])

def section(i, th):
    pros = "".join(f"<li>{p}</li>" for p in th["pros"])
    cons = "".join(f"<li>{c}</li>" for c in th["cons"])
    return f'''<section class="theme" id="{th['key']}">
  <div class="tinfo">
    <div class="teyebrow">Option {i}</div>
    <h2 class="tname">{th['name']}</h2>
    <p class="ttag">{th['tag']}</p>
    <p class="tblurb">{th['blurb']}</p>
    <div class="swatches">{swatches(th)}</div>
    <p class="swcap">Accent, then the four macro hues — protein, carbs, fat, fibre</p>
    <p class="tface">Type — {th['faceNote']}</p>
    <p class="tbest"><span>Best if</span> {th['best']}.</p>
    <div class="tlists">
      <div><h3>Strengths</h3><ul>{pros}</ul></div>
      <div><h3>Trade-offs</h3><ul class="cons">{cons}</ul></div>
    </div>
  </div>
  {preview(th)}
</section>'''

sections = "\n".join(section(i + 1, th) for i, th in enumerate(THEMES))
navlinks = "".join(f'<a href="#{t["key"]}">{t["name"]}</a>' for t in THEMES)

open("/tmp/claude-0/-home-user-nourishly/79cdd004-c5bb-5f04-a427-20188ea84cd6/scratchpad/parts.json","w").write(
    json.dumps(dict(theme_css=THEME_CSS, sections=sections, navlinks=navlinks)))
print("generated", len(THEME_CSS), "css chars,", len(sections), "html chars")
