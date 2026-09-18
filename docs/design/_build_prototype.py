#!/usr/bin/env python3
"""Generates prototype.html from tokens/nourishly-indigo.json.

The prototype consumes the token file directly, so the screens shown can never
drift from the approved theme. Re-run after any token change.
"""
import json, math, os, pathlib

ROOT = pathlib.Path(__file__).parent
T = json.loads((ROOT / "tokens" / "nourishly-indigo.json").read_text())
C, TS = T["color"], T["typeScale"]
RATIO = T["chart"]["trackToTargetRatio"]

# ---------------------------------------------------------------- tokens → css
def css_vars(mode):
    c = C[mode]
    v = {
        "bg": c["bg"], "surface": c["surface"], "surface-2": c["surface2"], "surface-3": c["surface3"],
        "line": c["line"], "line-strong": c["lineStrong"],
        "ink": c["ink"], "ink-2": c["ink2"], "ink-3": c["ink3"], "ink-disabled": c["inkDisabled"],
        "accent": c["accent"], "accent-hover": c["accentHover"], "accent-ink": c["accentInk"],
        "accent-soft": c["accentSoft"], "accent-soft-ink": c["accentSoftInk"],
        "track": c["track"], "focus": c["focus"], "scrim": c["scrim"],
        "danger": c["danger"], "danger-soft": c["dangerSoft"],
        "ok": c["status"]["ok"], "low": c["status"]["low"], "high": c["status"]["high"],
        "unknown": c["status"]["unknown"],
        "s-protein": c["series"]["protein"], "s-carbs": c["series"]["carbs"],
        "s-fat": c["series"]["fat"], "s-fibre": c["series"]["fibre"],
        "el-1": c["elevation"]["1"], "el-2": c["elevation"]["2"], "el-3": c["elevation"]["3"],
    }
    return "".join(f"--{k}:{val};" for k, val in v.items())

STATIC_VARS = (
    "".join(f"--sp-{k}:{v}px;" for k, v in T["space"].items())
    + "".join(f"--r-{k}:{(999 if v==999 else v)}px;" for k, v in T["radius"].items())
    + f"--dur-fast:{T['motion']['fast']}ms;--dur-base:{T['motion']['base']}ms;--ease:{T['motion']['easing']};"
    + f"--font:'{T['font']['body']}',{T['font']['fallback']};"
    + f"--mono:'{T['font']['mono']}',ui-monospace,monospace;"
)

# ---------------------------------------------------------------- components
def sb():  # status bar
    return ('<div class="sb"><span>9:41</span><span class="sbr">'
            '<svg viewBox="0 0 18 12" width="16" height="11" aria-hidden="true">'
            '<rect x="0" y="7" width="3" height="5" rx="1" fill="currentColor"/>'
            '<rect x="5" y="4" width="3" height="8" rx="1" fill="currentColor"/>'
            '<rect x="10" y="1" width="3" height="11" rx="1" fill="currentColor"/></svg>'
            '<svg viewBox="0 0 24 12" width="22" height="11" aria-hidden="true">'
            '<rect x="0.5" y="0.5" width="19" height="11" rx="3" fill="none" stroke="currentColor"/>'
            '<rect x="2" y="2" width="13" height="8" rx="1.5" fill="currentColor"/>'
            '<rect x="21" y="4" width="2" height="4" rx="1" fill="currentColor"/></svg></span></div>')

def appbar(title, left="", right="", sub=""):
    l = f'<button class="ab-icon" type="button" aria-label="Back">{ICON["back"]}</button>' if left == "back" else '<span class="ab-sp"></span>'
    r = right or '<span class="ab-sp"></span>'
    s = f'<div class="ab-sub">{sub}</div>' if sub else ""
    return f'<div class="ab">{l}<div class="ab-t"><div class="ab-title">{title}</div>{s}</div>{r}</div>'

ICON = {
 "back": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>',
 "today": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
 "insights": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 19V9M9.5 19V5M15 19v-7M20.5 19v-4"/></svg>',
 "water": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M12 3.5s6 6.6 6 10.4a6 6 0 0 1-12 0C6 10.1 12 3.5 12 3.5z"/></svg>',
 "profile": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="8.5" r="3.6"/><path d="M4.8 20a7.4 7.4 0 0 1 14.4 0"/></svg>',
 "plus": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>',
 "search": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
 "chev": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M9 6l6 6-6 6"/></svg>',
 "star": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"><path d="M12 4l2.4 5 5.4.7-3.9 3.8 1 5.4-4.9-2.7-4.9 2.7 1-5.4L4.2 9.7 9.6 9z"/></svg>',
 "scan": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16M7.5 9v6M11 9v6M14 9v6M17 9v6"/></svg>',
 "check": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
}

def bottomnav(active="today"):
    items = [("today", "Today"), ("insights", "Insights"), ("__fab__", ""), ("water", "Water"), ("profile", "Profile")]
    out = []
    for key, label in items:
        if key == "__fab__":
            out.append(f'<div class="nav-fab" role="presentation"><span class="fab">{ICON["plus"]}</span></div>')
            continue
        cls = "nav-i active" if key == active else "nav-i"
        out.append(f'<div class="{cls}">{ICON[key]}<span>{label}</span></div>')
    return f'<div class="bnav">{"".join(out)}</div>'

def ring(value, target, unit="kcal", size=118, label="left"):
    r, cx = 46, 60
    circ = 2 * math.pi * r
    prog = min(value / target / RATIO, 1.0)
    band_a, band_b = 0.90 / RATIO, 1.10 / RATIO
    tf = 1.0 / RATIO
    def polar(f, rr):
        d = math.radians(f * 360 - 90)
        return cx + rr * math.cos(d), cx + rr * math.sin(d)
    x1, y1 = polar(tf, r - 9); x2, y2 = polar(tf, r + 9)
    rem = max(target - value, 0)
    return f'''<div class="ringwrap" style="--rs:{size}px">
      <svg viewBox="0 0 120 120" role="img" aria-label="{value:,} of {target:,} {unit}, {rem:,} {label}">
        <circle cx="60" cy="60" r="{r}" fill="none" stroke="var(--track)" stroke-width="{T['stroke']['ring']}"/>
        <circle cx="60" cy="60" r="{r}" fill="none" stroke="var(--accent-soft)" stroke-width="{T['stroke']['ring']}"
          stroke-dasharray="{(band_b-band_a)*circ:.2f} {circ-(band_b-band_a)*circ:.2f}" stroke-dashoffset="{-band_a*circ:.2f}" transform="rotate(-90 60 60)"/>
        <circle cx="60" cy="60" r="{r}" fill="none" stroke="var(--accent)" stroke-width="{T['stroke']['ring']}" stroke-linecap="round"
          stroke-dasharray="{prog*circ:.2f} {circ-prog*circ:.2f}" transform="rotate(-90 60 60)"/>
        <line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="var(--ink-2)" stroke-width="{T['stroke']['tick']}" stroke-linecap="round"/>
      </svg>
      <div class="ringtxt"><div class="ringnum">{rem:,}</div><div class="ringlab">{unit} {label}</div></div>
    </div>'''

def barrow(name, val, tgt, unit, slot, show_pct=False):
    fill = min(val / tgt / RATIO, 1.0) * 100
    tick = (1.0 / RATIO) * 100
    pct = round(val / tgt * 100)
    right = f'{pct}%' if show_pct else f'<b>{val}</b><span class="mu">/{tgt}{unit}</span>'
    return f'''<div class="brow">
      <span class="bname">{name}</span>
      <span class="btrack"><span class="bfill" style="width:{fill:.1f}%;background:var(--s-{slot})"></span><span class="btick" style="left:{tick:.1f}%"></span></span>
      <span class="bval">{right}</span></div>'''

def chip(text, kind=""):
    dot = f'<span class="dot dot-{kind}"></span>' if kind else ""
    return f'<span class="chip chip-{kind}">{dot}{text}</span>'

def card(inner, cls=""):
    return f'<div class="card {cls}">{inner}</div>'

def sect(title, inner, action=""):
    a = f'<span class="sec-a">{action}</span>' if action else ""
    return f'<div class="sec"><div class="sec-h"><span>{title}</span>{a}</div>{inner}</div>'

def listrow(main, sub="", right="", left="", cls=""):
    l = f'<span class="lr-l">{left}</span>' if left else ""
    s = f'<div class="lr-sub">{sub}</div>' if sub else ""
    r = f'<span class="lr-r">{right}</span>' if right else ""
    return f'<div class="lr {cls}">{l}<div class="lr-m"><div class="lr-main">{main}</div>{s}</div>{r}</div>'

def btn(label, kind="primary", full=True):
    return f'<button type="button" class="btn btn-{kind}{" btn-full" if full else ""}">{label}</button>'

def wizard(wid, steps):
    """Multi-step screen. Steps are shown one at a time; the in-screen Continue
    and back controls move between them, as does the strip under the phone."""
    body = "".join(
        f'<div class="wstep{" on" if i == 0 else ""}" data-wstep="{i}">{st}</div>'
        for i, st in enumerate(steps))
    return f'<div class="wiz" data-wiz="{wid}">{body}</div>'


def wizard_ctl(wid, labels):
    dots = "".join(
        f'<button type="button" class="wc{" on" if i == 0 else ""}" data-wgo="{i}">{i+1}</button>'
        for i in range(len(labels)))
    names = "".join(f'<span class="wc-n{" on" if i == 0 else ""}" data-wname="{i}">{n}</span>'
                    for i, n in enumerate(labels))
    return (f'<div class="wizctl" data-wizctl="{wid}"><span class="wc-l">Step</span>{dots}'
            f'<span class="wc-names">{names}</span></div>')


def screen(inner, nav=None, cls=""):
    n = bottomnav(nav) if nav else ""
    return f'<div class="scr {cls}">{sb()}<div class="scr-body">{inner}</div>{n}</div>'

# ---------------------------------------------------------------- shared data
MEALS = [("Breakfast", 410, "2 Thepla · Chaas 1 glass"),
         ("Lunch", 760, "3 Rotli · Gujarati dal · Bhinda nu shaak · Rice"),
         ("Snack", 190, "Khakhra · Filter coffee"),
         ("Dinner", None, "")]
MACROS = [("Protein", 82, 95, "g", "protein"), ("Carbs", 198, 240, "g", "carbs"),
          ("Fat", 54, 62, "g", "fat"), ("Fibre", 18, 29, "g", "fibre")]

def macro_bars(show_pct=False):
    return "".join(barrow(*m, show_pct=show_pct) for m in MACROS)

def meal_list(compact=False):
    out = []
    for name, kcal, items in MEALS:
        if kcal is None:
            out.append(f'<div class="meal empty"><span class="meal-n">{name}</span><span class="meal-add">+ Add</span></div>')
        else:
            out.append(f'<div class="meal"><span class="meal-n">{name}</span><span class="meal-k">{kcal}</span></div>')
            if not compact:
                out.append(f'<div class="meal-i">{items}</div>')
    return "".join(out)

def waterbar():
    fill = (1.6 / 2.6 / RATIO) * 100
    tick = (1.0 / RATIO) * 100
    return f'''<div class="brow"><span class="bname">Water</span>
      <span class="btrack"><span class="bfill" style="width:{fill:.1f}%;background:var(--accent)"></span><span class="btick" style="left:{tick:.1f}%"></span></span>
      <span class="bval"><b>1.6</b><span class="mu">/2.6L</span></span></div>'''

# precomputed fragments (nested quotes are not legal inside f-strings on 3.11)
GLASSES = '<div class="glasses">' + "".join(
    ('<span class="gl on"></span>' if i < 6 else '<span class="gl"></span>') for i in range(10)) + '</div>'
QUICK_GLASS = ('<div class="quick"><button class="qb" type="button">+1 glass</button>'
               '<button class="qb qb-alt" type="button">Custom amount</button></div>')
_WK = [("M", 88), ("T", 72), ("W", 95), ("T", 62), ("F", 0), ("S", 0), ("S", 0)]
WEEKBARS = ('<div class="wkbars">' + "".join(
    '<div class="wk"><span class="wk-b" style="height:%d%%"></span><i>%s</i></div>' % (h, d)
    for d, h in _WK) + '</div><div class="wk-l"><span>Avg 2.0 L over 4 logged days</span></div>')

STATUS_CHIPS = chip("Protein on track", "ok") + chip("Fibre 11 g short", "low") + chip("Micros 58% covered", "unknown")

# ================================================================ SCREENS
# Approved 2026-09-09 — see decisions.md. Discarded options are retained.
CHOSEN = {
    "onboarding": "B", "profile-setup": "A", "dashboard": "A", "log-entry": "B",
    "food-search": "A", "food-detail": "A", "templates": "A", "water": "A",
    "daily-report": "C", "weekly-report": "A", "monthly-report": "A",
    "goals": "B", "settings": "A",
}
S = []

# ---- 1. Onboarding
S.append(dict(id="onboarding", name="Onboarding", n=1,
  purpose="Get from install to a first logged food in under 90 seconds, with no account and no permission prompts.",
  options=[
    dict(key="A", label="Value cards first", note="Three short cards explain what the app does before asking for anything. Skip is always visible.",
      html=screen(f'''<div class="ob">
        <div class="ob-mark">N</div>
        <div class="ob-h">Know what you ate.<br>Not just how much.</div>
        <p class="ob-p">Log rotli, dal and chaas the way you actually eat them — in katoris and pieces, not grams.</p>
        <div class="ob-dots"><i class="on"></i><i></i><i></i></div>
        <div class="ob-foot">{btn("Continue")}<button class="btn btn-ghost btn-full" type="button">Skip for now</button>
          <p class="ob-fine">Works offline. No account needed.</p></div></div>''')),
    dict(key="B", label="Single promise screen", note="One screen, one sentence, straight into setup. Fewer taps, less explanation.",
      html=screen(f'''<div class="ob ob-b">
        <div class="ob-mark">N</div>
        <div class="ob-h2">Nourishly</div>
        <p class="ob-p">A private food and water diary for your household. Everything stays on this phone.</p>
        <ul class="ob-list"><li>{ICON["check"]} Works with no signal</li><li>{ICON["check"]} Knows Gujarati, Tamil and Kannadiga food</li><li>{ICON["check"]} No account, no ads</li></ul>
        <div class="ob-foot">{btn("Set up my profile")}<button class="btn btn-ghost btn-full" type="button">Skip for now</button></div></div>''')),
  ]))

# ---- 2. Profile setup
S.append(dict(id="profile-setup", name="Profile setup", n=2,
  purpose="Collect only what changes the targets, and explain what each answer does.",
  options=[
    dict(key="A", label="One question per step", note="Progressive. Feels light, harder to skim, more taps. Step through all five below the phone.",
      wizard="profile-setup-A",
      steps=["Date of birth &amp; sex", "Height &amp; weight", "Activity", "Goal", "Your targets"],
      html=screen(wizard("profile-setup-A", [
        # 1 — date of birth & sex
        appbar("About you", left="back", right='<span class="ab-step">1 of 5</span>') + f'''
        <div class="pad">
          <div class="q-h">When were you born?</div>
          <p class="q-s">Recommended intakes for several nutrients change with age.</p>
          <div class="fgrid" style="margin-top:14px">
            <label class="fld"><span>Date of birth</span><input value="14 March 1992" readonly></label>
          </div>
          <p class="q-hint">34 years old</p>
          <div class="q-h2">Which reference values should we use?</div>
          <p class="q-s">Recommended intakes for iron, calcium and a few others differ. You can skip this.</p>
          <div class="opts">
            <label class="opt"><span><b>Female</b></span></label>
            <label class="opt sel"><span><b>Male</b></span><span class="opt-c">{ICON["check"]}</span></label>
            <label class="opt"><span><b>Prefer not to say</b><i>Uses a neutral reference</i></span></label>
          </div>
        </div><div class="pad-b">{btn("Continue")}</div>''',
        # 2 — height & weight
        appbar("About you", left="back", right='<span class="ab-step">2 of 5</span>') + f'''
        <div class="pad">
          <div class="q-h">Your height and weight</div>
          <p class="q-s">These set your energy and protein targets more than anything else.</p>
          <div class="frow" style="margin-top:14px">
            <label class="fld"><span>Height</span><input value="174 cm" readonly></label>
            <label class="fld"><span>Weight</span><input value="71 kg" readonly></label>
          </div>
          <div class="chipset sm" style="margin-top:10px"><span class="sch on">Metric</span><span class="sch">ft / lb</span></div>
          <div class="notebox">You can update your weight any time. Past reports keep the targets they were measured against.</div>
        </div><div class="pad-b">{btn("Continue")}</div>''',
        # 3 — activity
        appbar("About you", left="back", right='<span class="ab-step">3 of 5</span>') + f'''
        <div class="pad">
          <div class="q-h">How active are you on a normal day?</div>
          <p class="q-s">This changes your energy target more than anything else.</p>
          <div class="opts">
            <label class="opt"><span><b>Mostly sitting</b><i>Desk job, little exercise</i></span></label>
            <label class="opt sel"><span><b>Lightly active</b><i>Some walking, exercise 1&ndash;3 days</i></span><span class="opt-c">{ICON["check"]}</span></label>
            <label class="opt"><span><b>Active</b><i>Exercise 3&ndash;5 days a week</i></span></label>
            <label class="opt"><span><b>Very active</b><i>Hard exercise 6&ndash;7 days</i></span></label>
          </div>
        </div><div class="pad-b">{btn("Continue")}</div>''',
        # 4 — goal
        appbar("About you", left="back", right='<span class="ab-step">4 of 5</span>') + f'''
        <div class="pad">
          <div class="q-h">What are you tracking for?</div>
          <p class="q-s">You can change this later. It only affects targets from that day forward.</p>
          <div class="opts">
            <label class="opt sel"><span><b>General health</b><i>Eat in balance, no weight change</i></span><span class="opt-c">{ICON["check"]}</span></label>
            <label class="opt"><span><b>Weight loss</b><i>A modest, safe deficit</i></span></label>
            <label class="opt"><span><b>Muscle gain</b><i>Higher protein, small surplus</i></span></label>
            <label class="opt"><span><b>Better hydration</b><i>Water is the main target</i></span></label>
          </div>
        </div><div class="pad-b">{btn("Continue")}</div>''',
        # 5 — result
        appbar("Your targets", left="back", right='<span class="ab-step">5 of 5</span>') + f'''
        <div class="pad">
          <div class="q-h">Here is where we landed</div>
          <p class="q-s">Worked out from your height, weight, age, activity and goal. Change any of them whenever you like.</p>
          {card(listrow("Energy","Mifflin-St Jeor &times; activity level","2,050 kcal")+listrow("Protein","1.2 g per kg of body weight","95 g")+listrow("Carbs","Remainder of energy","240 g")+listrow("Fat","28% of energy","62 g")+listrow("Fibre","14 g per 1,000 kcal","29 g")+listrow("Water","35 ml per kg","2.6 L"))}
          <div class="notebox">Micronutrient targets use the ICMR-NIN 2020 values for your age and sex.</div>
        </div><div class="pad-b">{btn("Start logging")}</div>''',
      ]))),
    dict(key="B", label="Single scrollable form", note="Everything visible at once. Faster for someone who knows their numbers.",
      html=screen(appbar("About you", left="back") + f'''
        <div class="pad">
          <div class="fgrid">
            <label class="fld"><span>Date of birth</span><input value="14 Mar 1992" readonly></label>
            <label class="fld"><span>Sex <i>for nutrient reference values</i></span><input value="Male" readonly></label>
            <div class="frow"><label class="fld"><span>Height</span><input value="174 cm" readonly></label>
              <label class="fld"><span>Weight</span><input value="71 kg" readonly></label></div>
            <label class="fld"><span>Activity</span><input value="Lightly active" readonly></label>
            <label class="fld"><span>Goal</span><input value="General health" readonly></label>
          </div>
          <div class="callout"><b>Your targets</b><div class="callout-g"><span>Energy</span><b>2,050 kcal</b><span>Protein</span><b>95 g</b><span>Water</span><b>2.6 L</b></div>
          <p>Worked out from your height, weight, activity and goal. You can change any of them later.</p></div>
        </div><div class="pad-b">{btn("Looks right")}</div>''')),
  ]))

# ---- 3. Dashboard
S.append(dict(id="dashboard", name="Daily dashboard", n=3,
  purpose="Answer 'how am I doing today, and what should I do next' at a glance. The most-opened screen in the app.",
  options=[
    dict(key="A", label="Ring-led", note="Energy ring is the hero. Strongest at-a-glance read; pushes meals below the fold.",
      html=screen(f'''<div class="pad-t">
        <div class="dh"><div><div class="dh-d">Thursday, 9 Sep</div><div class="dh-w">Keyur</div></div>{chip("Good 78","score")}</div>
        {card(f'<div class="ringrow">{ring(1640,2050)}<div class="ringside"><div class="kv"><span>Eaten</span><b>1,640</b></div><div class="kv"><span>Target</span><b>2,050</b></div><div class="kv"><span>Band</span><b>1,845–2,255</b></div></div></div>')}
        {card(macro_bars())}
        {card(waterbar() + '<div class="quick"><button class="qb" type="button">+250 ml</button><button class="qb" type="button">+500 ml</button><button class="qb qb-alt" type="button">Custom</button></div>')}
        <div class="chips">{STATUS_CHIPS}</div>
        {card(meal_list())}
      </div>''', nav="today")),
    dict(key="B", label="Meals-led", note="The day reads as a timeline; stats compress into a header strip. Best if logging matters more than monitoring.",
      html=screen(f'''<div class="pad-t">
        <div class="dh"><div><div class="dh-d">Thursday, 9 Sep</div><div class="dh-w">Keyur</div></div>{chip("Good 78","score")}</div>
        <div class="strip">
          <div class="st"><b>410</b><span>kcal left</span></div>
          <div class="st"><b>82<i>/95</i></b><span>protein</span></div>
          <div class="st"><b>1.6<i>/2.6</i></b><span>litres</span></div>
        </div>
        <div class="chips">{STATUS_CHIPS}</div>
        {sect("Today's meals", card(meal_list()), "Edit")}
        {sect("Macros", card(macro_bars(show_pct=True)))}
      </div>''', nav="today")),
    dict(key="C", label="Numbers grid", note="No hero graphic. Densest option — everything above the fold, nothing decorative.",
      html=screen(f'''<div class="pad-t">
        <div class="dh"><div><div class="dh-d">Thursday, 9 Sep</div><div class="dh-w">Keyur · General health</div></div>{chip("78","score")}</div>
        <div class="grid2">
          {card('<div class="tile"><span>Energy left</span><b>410</b><i>of 2,050 kcal</i></div>')}
          {card('<div class="tile"><span>Protein</span><b>82<em>g</em></b><i>86% of 95 g</i></div>')}
          {card('<div class="tile"><span>Water</span><b>1.6<em>L</em></b><i>62% of 2.6 L</i></div>')}
          {card('<div class="tile"><span>Fibre</span><b>18<em>g</em></b><i class="warn">11 g short</i></div>')}
        </div>
        {card(macro_bars())}
        {card(meal_list(compact=True))}
      </div>''', nav="today")),
  ]))

# ---- 4. Log entry point
S.append(dict(id="log-entry", name="Add food", n=4,
  purpose="The 3-tap path (UX-1). Repeat logging must not require typing.",
  options=[
    dict(key="A", label="Sheet with tabs", note="Opens over the dashboard; recents first, no keyboard. Dismisses back where you were.",
      html=screen(f'''<div class="sheet-bg"><div class="pad-t dim">{card('<div class="ringrow">'+ring(1640,2050,size=96)+'<div class="ringside"><div class="kv"><span>Eaten</span><b>1,640</b></div></div></div>')}</div>
        <div class="sheet"><div class="sheet-grab"></div>
          <div class="sheet-h"><b>Add to Dinner</b><span class="chg">Change</span></div>
          <div class="tabs"><span class="tab on">Recent</span><span class="tab">Favourites</span><span class="tab">Templates</span><span class="tab">Search</span></div>
          {listrow("Rotli","1 piece · 40 g · 104 kcal",'<span class="add">+</span>')}
          {listrow("Gujarati dal","1 katori · 150 g · 168 kcal",'<span class="add">+</span>')}
          {listrow("Bhinda nu shaak","1 katori · 120 g · 142 kcal",'<span class="add">+</span>')}
          {listrow("Rice, cooked","1 katori · 150 g · 195 kcal",'<span class="add">+</span>')}
          {listrow("Chaas","1 glass · 200 ml · 40 kcal",'<span class="add">+</span>')}
        </div></div>''')),
    dict(key="B", label="Full screen, search first", note="Search field focused on open. Faster when you know the name, slower for repeats.",
      html=screen(appbar("Add to Dinner", left="back", right=f'<button class="ab-icon" type="button" aria-label="Scan barcode">{ICON["scan"]}</button>') + f'''
        <div class="pad">
          <div class="search"><span class="s-i">{ICON["search"]}</span><span class="s-ph">Search 12,400 foods</span></div>
          <div class="sec-h"><span>Recent</span><span class="sec-a">See all</span></div>
          {listrow("Rotli","1 piece · 104 kcal","+")}
          {listrow("Gujarati dal","1 katori · 168 kcal","+")}
          {listrow("Bhinda nu shaak","1 katori · 142 kcal","+")}
          <div class="sec-h"><span>Your meal templates</span></div>
          {listrow("Everyday Gujarati thali","6 items · 1,240 kcal","Apply", cls="lr-accent")}
          {listrow("Thepla travel meal","3 items · 520 kcal","Apply", cls="lr-accent")}
        </div>''')),
  ]))

# ---- 5. Food search
S.append(dict(id="food-search", name="Food search", n=5,
  purpose="Find the right food fast, offline, including foods you invented. Never a dead end.",
  options=[
    dict(key="A", label="Grouped by source", note="Your foods, then recents, then catalog. Makes provenance obvious; more vertical space per result.",
      html=screen(appbar("Search", left="back") + f'''
        <div class="pad">
          <div class="search on"><span class="s-i">{ICON["search"]}</span><span class="s-v">dal</span><span class="s-x">×</span></div>
          <div class="sec-h"><span>Your foods</span></div>
          {listrow("Mummy's dal (my recipe)","1 katori · 150 g · 181 kcal","", left='<span class="qt qt-user">You</span>')}
          <div class="sec-h"><span>Recently logged</span></div>
          {listrow("Gujarati dal","1 katori · 150 g · 168 kcal","", left='<span class="qt qt-ver">Lab</span>')}
          {listrow("Dal dhokli","1 katori · 180 g · 296 kcal","", left='<span class="qt qt-der">Recipe</span>')}
          <div class="sec-h"><span>Catalog</span></div>
          {listrow("Dal, plain cooked (toor)","1 katori · 150 g · 142 kcal","", left='<span class="qt qt-ver">Lab</span>')}
          {listrow("Toor dal, raw","100 g · 343 kcal","", left='<span class="qt qt-ver">Lab</span>')}
          {listrow("Dal vada","2 pieces · 60 g · 218 kcal","", left='<span class="qt qt-der">Recipe</span>')}
          <div class="mk">Create “dal” as a custom food</div>
        </div>''')),
    dict(key="B", label="Flat ranked list", note="One ranked list with a small source badge per row. More results visible; ranking must be trusted.",
      html=screen(appbar("Search", left="back") + f'''
        <div class="pad">
          <div class="search on"><span class="s-i">{ICON["search"]}</span><span class="s-v">dal</span><span class="s-x">×</span></div>
          <div class="filters"><span class="fchip on">All</span><span class="fchip">Gujarati</span><span class="fchip">My foods</span><span class="fchip">Recipes</span></div>
          {listrow('Mummy&#39;s dal <span class="qt qt-user">You</span>',"1 katori · 181 kcal")}
          {listrow('Gujarati dal <span class="qt qt-ver">Lab</span>',"1 katori · 168 kcal")}
          {listrow('Dal dhokli <span class="qt qt-der">Recipe</span>',"1 katori · 296 kcal")}
          {listrow('Dal, plain cooked (toor) <span class="qt qt-ver">Lab</span>',"1 katori · 142 kcal")}
          {listrow('Dal vada <span class="qt qt-der">Recipe</span>',"2 pieces · 218 kcal")}
          {listrow('Toor dal, raw <span class="qt qt-ver">Lab</span>',"100 g · 343 kcal")}
          {listrow('Moong dal, raw <span class="qt qt-ver">Lab</span>',"100 g · 347 kcal")}
          <div class="mk">Create “dal” as a custom food</div>
        </div>''')),
  ]))

# ---- 6. Food detail
S.append(dict(id="food-detail", name="Portion & food detail", n=6,
  purpose="Pick the portion and confirm. Last-used serving is pre-filled — the detail that makes repeat logging fast.",
  options=[
    dict(key="A", label="Serving chips + stepper", note="Household measures as tappable chips. Fastest for the common case.",
      html=screen(appbar("Gujarati dal", left="back", right=f'<button class="ab-icon" type="button" aria-label="Favourite">{ICON["star"]}</button>', sub="Lab-measured · toor dal") + f'''
        <div class="pad">
          <div class="sec-h"><span>Serving</span></div>
          <div class="chipset"><span class="sch on">1 katori<i>150 g</i></span><span class="sch">1 vaatki<i>120 g</i></span><span class="sch">1 bowl<i>250 g</i></span><span class="sch">Grams</span></div>
          <div class="stepper"><button type="button">−</button><div class="stp-v"><b>1</b><span>× katori</span></div><button type="button">+</button></div>
          {card(f'<div class="nutrhead"><b>168</b><span>kcal · 150 g</span></div>{macro_bars()}')}
          <div class="sec-h"><span>Per serving</span><span class="sec-a">Show all 22</span></div>
          <div class="nrow"><span>Iron</span><b>1.9 mg</b></div>
          <div class="nrow"><span>Potassium</span><b>310 mg</b></div>
          <div class="nrow"><span>Vitamin B12</span><b class="unk">—</b></div>
          <p class="fine">Vitamin B12 isn't recorded for this food. It won't be counted as zero.</p>
        </div><div class="pad-b">{btn("Add to Lunch")}</div>''')),
    dict(key="B", label="Amount first", note="Big editable number leads. Better for people who weigh food; an extra tap for katori users.",
      html=screen(appbar("Gujarati dal", left="back", sub="Lab-measured") + f'''
        <div class="pad">
          <div class="amt"><div class="amt-v">150</div><div class="amt-u">grams</div></div>
          <div class="chipset sm"><span class="sch">½ katori</span><span class="sch on">1 katori</span><span class="sch">1½</span><span class="sch">2</span></div>
          <div class="kcalbig"><b>168</b><span>kcal</span></div>
          {card(macro_bars())}
          <div class="sec-h"><span>Meal</span></div>
          <div class="chipset"><span class="sch">Breakfast</span><span class="sch on">Lunch</span><span class="sch">Dinner</span><span class="sch">Snack</span></div>
        </div><div class="pad-b">{btn("Add to Lunch")}</div>''')),
  ]))

# ---- 7. Meal templates
S.append(dict(id="templates", name="Meal templates", n=7,
  purpose="Log a recurring multi-item meal in one action. Created from a meal you already logged.",
  options=[
    dict(key="A", label="Cards with contents", note="Shows what's inside without opening. Easier to pick the right one; fewer fit on screen.",
      html=screen(appbar("Templates", left="back", right='<span class="ab-act">New</span>') + f'''
        <div class="pad">
          {card('<div class="tpl-h"><b>Everyday Gujarati thali</b><span class="tpl-k">1,240 kcal</span></div><div class="tpl-i">3 Rotli · Gujarati dal · Bhinda nu shaak · Rice · Kachumber · Chaas</div><div class="tpl-f"><span class="tpl-u">Used 34 times</span><button class="btn btn-soft btn-sm" type="button">Apply</button></div>')}
          {card('<div class="tpl-h"><b>Thepla travel meal</b><span class="tpl-k">520 kcal</span></div><div class="tpl-i">3 Thepla · Pickle · Curd</div><div class="tpl-f"><span class="tpl-u">Used 11 times</span><button class="btn btn-soft btn-sm" type="button">Apply</button></div>')}
          {card('<div class="tpl-h"><b>Idli breakfast</b><span class="tpl-k">430 kcal</span></div><div class="tpl-i">2 Idli · Sambar · Coconut chutney · Filter coffee</div><div class="tpl-f"><span class="tpl-u">Used 8 times</span><button class="btn btn-soft btn-sm" type="button">Apply</button></div>')}
        </div>''')),
    dict(key="B", label="Compact rows", note="More templates visible. Contents hidden until tapped — relies on good names.",
      html=screen(appbar("Templates", left="back", right='<span class="ab-act">New</span>') + f'''
        <div class="pad">
          <div class="sec-h"><span>Most used</span></div>
          {listrow("Everyday Gujarati thali","6 items · 1,240 kcal · used 34×","Apply", cls="lr-accent")}
          {listrow("Thepla travel meal","3 items · 520 kcal · used 11×","Apply", cls="lr-accent")}
          {listrow("Idli breakfast","4 items · 430 kcal · used 8×","Apply", cls="lr-accent")}
          {listrow("Ragi mudde lunch","4 items · 690 kcal · used 5×","Apply", cls="lr-accent")}
          {listrow("Light dinner","2 items · 380 kcal · used 4×","Apply", cls="lr-accent")}
          <div class="mk">Save today's lunch as a template</div>
        </div>''')),
  ]))

# ---- 8. Water
S.append(dict(id="water", name="Water", n=8,
  purpose="One tap to log. Must be useful on its own, with no nutrition setup.",
  options=[
    dict(key="A", label="Fill visual", note="A single vessel fills as you drink. Clearest sense of proportion.",
      html=screen(f'''<div class="pad-t">
        <div class="dh"><div><div class="dh-d">Water</div><div class="dh-w">Thursday, 9 Sep</div></div>{chip("62%","score")}</div>
        {card(f'<div class="wfill"><div class="wfill-b"><div class="wfill-l" style="height:61.5%"></div><div class="wfill-t"><b>1.6</b><span>of 2.6 L</span></div></div></div><div class="quick"><button class="qb" type="button">+250 ml</button><button class="qb" type="button">+500 ml</button><button class="qb qb-alt" type="button">Custom</button></div>')}
        {sect("Today", card(listrow("500 ml","8:10 · glass","",left='<span class="wdot"></span>')+listrow("250 ml","10:45 · glass","",left='<span class="wdot"></span>')+listrow("400 ml","13:20 · bottle","",left='<span class="wdot"></span>')+listrow("450 ml","16:05 · buttermilk","",left='<span class="wdot wdot-alt"></span>')))}
        <p class="fine">Chaas and tea count toward hydration. Coffee counts at a lower rate.</p>
      </div>''', nav="water")),
    dict(key="B", label="Glass grid", note="Tap a glass to fill it. Fastest input, and countable at a glance; less precise for odd amounts.",
      html=screen(f'''<div class="pad-t">
        <div class="dh"><div><div class="dh-d">Water</div><div class="dh-w">1.6 of 2.6 L · 6 of 10 glasses</div></div>{chip("62%","score")}</div>
        {card(GLASSES + QUICK_GLASS)}
        {sect("This week", card(WEEKBARS))}
      </div>''', nav="water")),
  ]))

# ---------------------------------------------------------- report fragments
SUBSCORES = [("Energy adherence", 92, 25), ("Macro balance", 74, 30),
             ("Micronutrients", None, 20), ("Limit nutrients", 88, 15), ("Hydration", 62, 10)]

def subscore_rows():
    out = []
    for name, val, w in SUBSCORES:
        if val is None:
            out.append(f'<div class="ss"><span class="ss-n">{name} <i>{w}%</i></span>'
                       f'<span class="ss-t ss-t-off"></span>'
                       f'<span class="ss-v ss-na">&mdash;</span></div>'
                       f'<div class="ss-why">Not scored &mdash; only 58% of today&#8217;s food reports these</div>')
        else:
            out.append(f'<div class="ss"><span class="ss-n">{name} <i>{w}%</i></span>'
                       f'<span class="ss-t"><span class="ss-f" style="width:{val}%"></span></span>'
                       f'<span class="ss-v">{val}</span></div>')
    return "".join(out)

NUTR_TABLE = "".join(
    f'<div class="nt"><span>{n}</span><span class="nt-b"><span class="nt-f" style="width:{min(p,100)}%;background:var(--{c})"></span></span><b>{v}</b><span class="nt-s st-{s}">{lab}</span></div>'
    for n, v, p, c, s, lab in [
        ("Energy", "1,640 kcal", 80, "accent", "low", "Under"),
        ("Protein", "82 g", 86, "s-protein", "ok", "On"),
        ("Carbs", "198 g", 82, "s-carbs", "ok", "On"),
        ("Fat", "54 g", 87, "s-fat", "ok", "On"),
        ("Fibre", "18 g", 62, "s-fibre", "low", "Short"),
        ("Sodium", "2,310 mg", 115, "high", "high", "Over"),
        ("Iron", "11.4 mg", 63, "unknown", "low", "Short"),
        ("Calcium", "—", 0, "unknown", "na", "No data"),
    ])

WEEK_BARS = "".join(
    '<div class="cb"><span class="cb-b%s" style="height:%d%%"></span><i>%s</i></div>' % (
        (" cb-off" if h == 0 else ""), (h if h else 4), d)
    for d, h in [("M", 84), ("T", 91), ("W", 78), ("T", 80), ("F", 0), ("S", 96), ("S", 88)])

MONTH_CELLS = "".join(
    '<span class="hm hm-%s"></span>' % lvl for lvl in
    "2233104223341022334102233410223341022331".__iter__())

def sparkline(points, w=280, h=64):
    mx, mn = max(points), min(points)
    rng = (mx - mn) or 1
    step = w / (len(points) - 1)
    pts = [(i * step, h - 6 - ((p - mn) / rng) * (h - 16)) for i, p in enumerate(points)]
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    area = d + f" L{w},{h} L0,{h} Z"
    last = pts[-1]
    return (f'<svg viewBox="0 0 {w} {h}" class="spark" role="img" aria-label="Daily score trend, 68 to 84">'
            f'<path d="{area}" fill="var(--accent-soft)" stroke="none"/>'
            f'<path d="{d}" fill="none" stroke="var(--accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<circle cx="{last[0]:.1f}" cy="{last[1]:.1f}" r="3.5" fill="var(--accent)" stroke="var(--surface)" stroke-width="2"/></svg>')

# ---- 9. Daily report
S.append(dict(id="daily-report", name="Daily report", n=9,
  purpose="Turn the day into understanding. The verdict comes first because most people read only that.",
  options=[
    dict(key="A", label="Verdict first", note="A sentence, then the score, then what to do. Most readable; the numbers sit lower.",
      html=screen(appbar("Thursday, 9 Sep", left="back", right='<span class="ab-act">Share</span>') + f'''
        <div class="pad">
          {card('<div class="verdict">A solid day. Protein and fat landed where you wanted; fibre was the gap again.</div><div class="vscore"><span class="band">Good</span><b>78</b><span class="of">/100</span></div>')}
          {sect("What went well", card('<div class="ins ins-ok">Protein met for the third day running.</div><div class="ins ins-ok">Sugar stayed well inside your limit.</div>'))}
          {sect("What fell short", card('<div class="ins ins-low">Fibre came in at 18 g against your 29 g target. A katori of dal or a guava would close most of it.</div><div class="ins ins-high">Sodium was above the recommended limit — the pickle and papad together account for most of it.</div>'))}
          {sect("Meals", card(meal_list()))}
        </div>''')),
    dict(key="B", label="Score breakdown first", note="Shows exactly how the 78 was built, including the component that was withheld. Most transparent.",
      html=screen(appbar("Thursday, 9 Sep", left="back") + f'''
        <div class="pad">
          {card(f'<div class="vscore vscore-lg"><span class="band">Good</span><b>78</b><span class="of">/100</span></div><p class="fine ctr">How closely today matched <b>your</b> targets — not a health verdict.</p>')}
          {sect("How it was worked out", card(subscore_rows() + '<p class="fine">Micronutrients were left out because only 58% of today&#8217;s food reports them. Their 20% weight was shared across the rest.</p>'))}
          {sect("Gaps and excesses", card('<div class="ins ins-low">Fibre 18 g of 29 g</div><div class="ins ins-high">Sodium 2,310 mg of 2,000 mg limit</div>'))}
        </div>''')),
    dict(key="C", label="Full table", note="Every tracked nutrient against target in one scan, with the verdict above it and the insights below. Densest option that still reads in two seconds.",
      html=screen(appbar("Thursday, 9 Sep", left="back", right='<span class="ab-act">Share</span>') + f'''
        <div class="pad">
          {card('<div class="verdict">A solid day. Protein and fat landed where you wanted; fibre was the gap again.</div><div class="vscore"><span class="band">Good</span><b>78</b><span class="of">/100</span></div>')}
          <div class="sec-h"><span>Every nutrient</span><span class="sec-a">1,640 of 2,050 kcal</span></div>
          {card(NUTR_TABLE)}
          <p class="fine">Calcium shows &ldquo;no data&rdquo; rather than zero &mdash; none of today&#8217;s foods report it.</p>
          <div class="sec-h"><span>What to do about it</span></div>
          {card('<div class="ins ins-low">Fibre came in at 18 g against your 29 g target. A katori of dal or a guava would close most of it.</div><div class="ins ins-high">Sodium was above the recommended limit &mdash; the pickle and papad together account for most of it.</div><div class="ins ins-ok">Protein met for the third day running.</div>')}
          <div class="sec-h"><span>Meals</span></div>
          {card(meal_list(compact=True))}
        </div>''')),
  ]))

# ---- 10. Weekly report
S.append(dict(id="weekly-report", name="Weekly report", n=10,
  purpose="Show patterns a single day cannot. Every average states how many days it is based on.",
  options=[
    dict(key="A", label="Charts first", note="Bars and trend lead; findings underneath. Best for spotting the shape of the week.",
      html=screen(appbar("Week of 3–9 Sep", left="back", right='<span class="ab-act">Prev</span>') + f'''
        <div class="pad">
          {card(f'<div class="ch-h"><span>Energy per day</span><i>Target 2,050</i></div><div class="chart">{WEEK_BARS}<span class="ch-tgt"></span></div><p class="ch-f">Friday not logged</p>')}
          {card(f'<div class="ch-h"><span>Daily score</span><i>6 days scored</i></div>{sparkline([68,74,71,78,0,84,79][:4] + [84,79])}')}
          {sect("Averages", card('<div class="avg"><span>Energy</span><b>1,910</b><i>over 6 logged days</i></div><div class="avg"><span>Protein</span><b>88 g</b><i>target met on 5 of 6</i></div><div class="avg"><span>Fibre</span><b>19 g</b><i>target met on 1 of 6</i></div><div class="avg"><span>Water</span><b>2.1 L</b><i>target met on 3 of 6</i></div>'))}
        </div>''', nav="insights")),
    dict(key="B", label="Findings first", note="Plain-language findings lead, charts support. Best if nobody in the house wants to read a chart.",
      html=screen(appbar("Week of 3–9 Sep", left="back") + f'''
        <div class="pad">
          {card('<div class="verdict">Your steadiest week so far — six days logged, and protein met on five of them.</div>')}
          {sect("Worth knowing", card('<div class="ins ins-ok">Best day was Saturday (84) — the only day fibre was met.</div><div class="ins ins-low">Fibre missed on 5 of 6 days. It is the one target that is consistently short.</div><div class="ins ins-note">Friday has no entries, so it is left out of every average below.</div>'))}
          {sect("The numbers", card('<div class="avg"><span>Energy</span><b>1,910</b><i>over 6 logged days</i></div><div class="avg"><span>Protein</span><b>88 g</b><i>5 of 6 days met</i></div><div class="avg"><span>Fibre</span><b>19 g</b><i>1 of 6 days met</i></div>'))}
          {card(f'<div class="ch-h"><span>Energy per day</span></div><div class="chart">{WEEK_BARS}<span class="ch-tgt"></span></div>')}
        </div>''', nav="insights")),
  ]))

# ---- 11. Monthly report
S.append(dict(id="monthly-report", name="Monthly report", n=11,
  purpose="Long-horizon perspective. Daily nutrition is noisy, so the smoothed line is the signal.",
  options=[
    dict(key="A", label="Trend line", note="Score over the month with a 7-day average. Reads change clearly.",
      html=screen(appbar("September", left="back", right='<span class="ab-act">Aug</span>') + f'''
        <div class="pad">
          {card(f'<div class="ch-h"><span>Daily score</span><i>7-day average</i></div>{sparkline([62,68,64,71,69,74,72,78,75,81,79,84])}<div class="cmp"><span>vs August</span><b class="up">+6</b></div>')}
          {sect("Month at a glance", card('<div class="avg"><span>Days logged</span><b>24</b><i>of 30</i></div><div class="avg"><span>Avg energy</span><b>1,940</b><i>target 2,050</i></div><div class="avg"><span>Avg score</span><b>74</b><i>August 68</i></div>'))}
          {sect("Consistently short", card(chip("Fibre · 19 of 24 days","low") + chip("Iron · 14 of 24 days","low")))}
          {sect("Consistently over", card(chip("Sodium · 16 of 24 days","high")))}
        </div>''', nav="insights")),
    dict(key="B", label="Calendar heat-map", note="Every day as a cell. Best for seeing gaps in logging and weekend patterns.",
      html=screen(appbar("September", left="back") + f'''
        <div class="pad">
          {card(f'<div class="ch-h"><span>Daily score</span></div><div class="hm-days"><i>M</i><i>T</i><i>W</i><i>T</i><i>F</i><i>S</i><i>S</i></div><div class="hmgrid">{MONTH_CELLS}</div><div class="hm-key"><span>Lower</span><span class="hm hm-1"></span><span class="hm hm-2"></span><span class="hm hm-3"></span><span class="hm hm-4"></span><span>Higher</span><span class="hm hm-0"></span><span>Not logged</span></div>')}
          {sect("Month at a glance", card('<div class="avg"><span>Days logged</span><b>24</b><i>of 30</i></div><div class="avg"><span>Avg score</span><b>74</b><i>August 68</i></div><div class="avg"><span>Best stretch</span><b>6 days</b><i>15–20 Sep</i></div>'))}
          <p class="fine">Weekends score lower than weekdays by 9 points on average.</p>
        </div>''', nav="insights")),
  ]))

# ---- 12. Goals & targets
S.append(dict(id="goals", name="Goals & targets", n=12,
  purpose="Change targets without needing to understand the derivation. Changes apply from today forward — history keeps the targets it was measured against.",
  options=[
    dict(key="A", label="Grouped list", note="Compact. Derived vs overridden shown as a badge on each row.",
      html=screen(appbar("Goals & targets", left="back") + f'''
        <div class="pad">
          {card(listrow("Goal","What the targets are built for","General health " + ICON["chev"], cls="lr-tap"))}
          <div class="sec-h"><span>Daily targets</span><span class="sec-a">Reset all</span></div>
          {card(listrow("Energy","Derived from profile","2,050 kcal")+listrow("Protein","Derived · 1.2 g/kg","95 g")+listrow("Carbs","Remainder of energy","240 g")+listrow("Fat","28% of energy","62 g")+listrow("Fibre","14 g per 1,000 kcal","29 g")+listrow('Water <span class="qt qt-user">Yours</span>',"You set this","2.6 L"))}
          <div class="sec-h"><span>Focus on the dashboard</span></div>
          {card('<div class="chipset"><span class="sch on">Fibre</span><span class="sch on">Iron</span><span class="sch on">Sodium</span><span class="sch">+ Add</span></div>')}
          <div class="notebox">Changes apply from today. Past reports keep the targets they were measured against.</div>
        </div>''')),
    dict(key="B", label="Card per target", note="A card with a slider and its reasoning for the six headline targets; the other 18 nutrients as a compact list that expands to a card when edited.",
      html=screen(appbar("Goals & targets", left="back") + f'''
        <div class="pad">
          <div class="sec-h"><span>The six you look at</span></div>
          {card('<div class="tgt-h"><b>Energy</b><span class="qt qt-ver">Derived</span></div><div class="tgt-v">2,050<i>kcal</i></div><div class="slider"><span class="sl-t"><span class="sl-f"></span></span><span class="sl-k"></span></div><p class="fine">Mifflin-St Jeor from your height, weight and age, times your activity level.</p>')}
          {card('<div class="tgt-h"><b>Protein</b><span class="qt qt-ver">Derived</span></div><div class="tgt-v">95<i>g</i></div><div class="slider"><span class="sl-t"><span class="sl-f sl-70"></span></span><span class="sl-k sl-k70"></span></div><p class="fine">1.2 g per kg of body weight for general health.</p>')}
          {card('<div class="tgt-h"><b>Fibre</b><span class="qt qt-ver">Derived</span></div><div class="tgt-v">29<i>g</i></div><div class="slider"><span class="sl-t"><span class="sl-f sl-60"></span></span><span class="sl-k sl-k60"></span></div><p class="fine">14 g per 1,000 kcal. Missed on 19 of your last 24 logged days.</p>')}
          {card('<div class="tgt-h"><b>Water</b><span class="qt qt-user">You set this</span></div><div class="tgt-v">2.6<i>L</i></div><div class="slider"><span class="sl-t"><span class="sl-f sl-60"></span></span><span class="sl-k sl-k60"></span></div><p class="fine">You raised this from the derived 2.5 L. <span class="lnk">Reset to derived</span></p>')}
          <p class="fine">Carbs and fat follow the same pattern below.</p>
          <div class="sec-h"><span>Micronutrients</span><span class="sec-a">18 tracked</span></div>
          {card(listrow("Iron","ICMR-NIN, male 19&ndash;59","19 mg " + ICON["chev"], cls="lr-tap")+listrow("Calcium","ICMR-NIN","1,000 mg " + ICON["chev"], cls="lr-tap")+listrow('Sodium <span class="qt qt-user">Yours</span>',"Upper limit, WHO","2,000 mg " + ICON["chev"], cls="lr-tap")+listrow("Vitamin C","ICMR-NIN","80 mg " + ICON["chev"], cls="lr-tap")+listrow("Show all 18","","", cls="lr-tap lr-accent"))}
          <p class="fine">Tap any of these to open it as a card and adjust it.</p>
          <div class="notebox">Changes apply from today. Past reports keep the targets they were measured against.</div>
        </div>''')),
  ]))

# ---- 13. Settings & data
S.append(dict(id="settings", name="Settings & data", n=13,
  purpose="Profiles, units, reminders, and the two things that matter most with no server: export and backup.",
  options=[
    dict(key="A", label="Grouped list", note="Familiar platform pattern. Dense, scannable, nothing to read.",
      html=screen(appbar("Settings") + f'''
        <div class="pad">
          <div class="sec-h"><span>Profiles on this phone</span></div>
          {card(listrow('<span class="av av-1">K</span> Keyur',"General health · active","Active", cls="lr-tap")+listrow('<span class="av av-2">A</span> Aarti',"Improved hydration","", cls="lr-tap")+listrow("+ Add a profile","","", cls="lr-tap lr-accent"))}
          <div class="sec-h"><span>Preferences</span></div>
          {card(listrow("Units","","Metric "+ICON["chev"], cls="lr-tap")+listrow("Week starts","","Monday "+ICON["chev"], cls="lr-tap")+listrow("Day rolls over","","4:00 am "+ICON["chev"], cls="lr-tap")+listrow("Reminders","","3 on "+ICON["chev"], cls="lr-tap")+listrow("Show daily score","","On "+ICON["chev"], cls="lr-tap"))}
          <div class="sec-h"><span>Your data</span></div>
          {card(listrow("Export everything","JSON and CSV",ICON["chev"], cls="lr-tap")+listrow("Backup","Last backed up 2 days ago",ICON["chev"], cls="lr-tap")+listrow('<span class="dgr">Delete a profile</span>',"","", cls="lr-tap"))}
          <p class="fine ctr">Nourishly v1.0 · catalog 2026.09 · all data stays on this phone</p>
        </div>''', nav="profile")),
    dict(key="B", label="Cards with reasons", note="Each group explains itself. Better for the backup section, which is the one people ignore until it matters.",
      html=screen(appbar("Settings") + f'''
        <div class="pad">
          {card('<div class="prof"><span class="av av-1 av-lg">K</span><div><b>Keyur</b><i>General health · 174 cm · 71 kg</i></div><span class="sw-b">Switch</span></div>')}
          {card('<div class="sec-t">Backup</div><p class="fine">Your phone backs this app up automatically. The food catalog is left out — it is rebuilt from the app, so it does not need saving.</p><div class="bk"><span class="bk-ok">'+ICON["check"]+'</span><div><b>Backed up 2 days ago</b><i>To your Google account</i></div></div>'+btn("Export a copy now","soft"))}
          {card('<div class="sec-t">Reminders</div><div class="rm"><span>Drink water</span><b>Every 2 hours</b></div><div class="rm"><span>Log dinner</span><b>8:30 pm</b></div><div class="rm"><span>Day summary</span><b>10:00 pm</b></div>')}
          {card('<div class="sec-t">Preferences</div>'+listrow("Units","","Metric")+listrow("Week starts","","Monday")+listrow("Show daily score","","On"))}
          <p class="fine ctr">v1.0 · catalog 2026.09 · nothing leaves this phone</p>
        </div>''', nav="profile")),
  ]))

# ================================================================ PAGE
PAGE_CSS = """
:root{
  --pg-bg:#f2f3f8; --pg-surface:#ffffff; --pg-surface-2:#e9ebf4; --pg-line:#d6d9e8;
  --pg-ink:#161829; --pg-ink-2:#4b4f66; --pg-ink-3:#7b8098;
  --pg-accent:#3b4d9e; --pg-accent-ink:#ffffff; --pg-accent-soft:#dfe3f4;
  --pg-shadow:0 2px 4px rgba(22,24,41,.06), 0 10px 28px -14px rgba(22,24,41,.22);
  color-scheme:light;
  __STATIC__
}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){
  --pg-bg:#0b0d14; --pg-surface:#141722; --pg-surface-2:#1c2030; --pg-line:#282d40;
  --pg-ink:#e9ebf6; --pg-ink-2:#a8adc4; --pg-ink-3:#787e96;
  --pg-accent:#8b99ea; --pg-accent-ink:#0e1018; --pg-accent-soft:#232847;
  --pg-shadow:0 2px 4px rgba(0,0,0,.5), 0 10px 28px -14px rgba(0,0,0,.8);
  color-scheme:dark;}}
:root[data-theme="dark"]{
  --pg-bg:#0b0d14; --pg-surface:#141722; --pg-surface-2:#1c2030; --pg-line:#282d40;
  --pg-ink:#e9ebf6; --pg-ink-2:#a8adc4; --pg-ink-3:#787e96;
  --pg-accent:#8b99ea; --pg-accent-ink:#0e1018; --pg-accent-soft:#232847;
  --pg-shadow:0 2px 4px rgba(0,0,0,.5), 0 10px 28px -14px rgba(0,0,0,.8);
  color-scheme:dark;}

/* the app theme, straight from tokens/nourishly-indigo.json */
.scr{__LIGHT__}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]) .scr{__DARK__}}
:root[data-theme="dark"] .scr{__DARK__}

*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--pg-bg);color:var(--pg-ink);font-family:var(--font);font-size:15px;line-height:1.55;-webkit-font-smoothing:antialiased}
h1,h2,h3{margin:0;text-wrap:balance}p{margin:0}
:focus-visible{outline:2px solid var(--pg-accent);outline-offset:2px;border-radius:4px}
.wrap{max-width:1240px;margin:0 auto;padding:0 24px}

.bar{position:sticky;top:0;z-index:40;background:color-mix(in srgb,var(--pg-bg) 90%,transparent);backdrop-filter:blur(10px);border-bottom:1px solid var(--pg-line)}
.barin{display:flex;align-items:center;gap:14px;padding:10px 0;flex-wrap:wrap}
.brand{font-weight:700;font-size:15px;letter-spacing:-.01em;white-space:nowrap}
.brand i{color:var(--pg-ink-3);font-style:normal;font-weight:500}
.spacer{margin-left:auto}
.tgl,.selbtn{display:inline-flex;align-items:center;gap:7px;border:1px solid var(--pg-line);background:var(--pg-surface);color:var(--pg-ink);border-radius:999px;padding:7px 14px;font:inherit;font-size:13px;font-weight:600;cursor:pointer;white-space:nowrap}
.tgl:hover,.selbtn:hover{border-color:var(--pg-ink-3)}
.tgl svg{width:15px;height:15px}
.selbtn b{background:var(--pg-accent);color:var(--pg-accent-ink);border-radius:999px;padding:1px 8px;font-size:11px;font-weight:700}

.intro{padding:44px 0 4px;max-width:66ch}
.kick{font-size:11px;font-weight:600;letter-spacing:.1em;text-transform:uppercase;color:var(--pg-accent);margin-bottom:12px}
.intro h1{font-size:clamp(27px,3.8vw,40px);line-height:1.1;letter-spacing:-.025em;margin-bottom:14px;font-weight:700}
.lede{font-size:16px;color:var(--pg-ink-2)}
.lede+.lede{margin-top:10px}
.hownote{margin-top:22px;padding:14px 16px;background:var(--pg-surface);border:1px solid var(--pg-line);border-left:3px solid var(--pg-accent);border-radius:9px;font-size:14px;color:var(--pg-ink-2)}
.hownote b{color:var(--pg-ink)}

.rail{position:sticky;top:52px;z-index:30;background:color-mix(in srgb,var(--pg-bg) 92%,transparent);backdrop-filter:blur(8px);border-bottom:1px solid var(--pg-line);margin-top:30px}
.railin{display:flex;gap:6px;overflow-x:auto;padding:10px 0;scrollbar-width:thin}
.rl{display:inline-flex;align-items:center;gap:6px;white-space:nowrap;text-decoration:none;font-size:13px;font-weight:600;color:var(--pg-ink-2);background:var(--pg-surface);border:1px solid var(--pg-line);border-radius:999px;padding:6px 13px}
.rl:hover{border-color:var(--pg-ink-3);color:var(--pg-ink)}
.rl i{font-style:normal;color:var(--pg-ink-3);font-weight:500}
.rl.done{border-color:var(--pg-accent);background:var(--pg-accent-soft);color:var(--pg-ink)}
.rl.done i{color:var(--pg-accent)}

.grp{padding:42px 0;border-top:1px solid var(--pg-line);scroll-margin-top:104px}
.grp:first-of-type{border-top:none}
.grp-h{max-width:70ch;margin-bottom:22px}
.grp-n{font-size:11px;font-weight:600;letter-spacing:.1em;text-transform:uppercase;color:var(--pg-ink-3)}
.grp-t{font-size:26px;font-weight:700;letter-spacing:-.02em;margin-top:5px}
.grp-p{margin-top:8px;color:var(--pg-ink-2);font-size:14.5px}
.opts-row{display:flex;gap:26px;flex-wrap:wrap;align-items:flex-start}
.opt-col{width:340px;flex:none}
.opt-hd{display:flex;align-items:flex-start;gap:10px;margin-bottom:12px;min-height:74px}
.opt-k{font-size:12px;font-weight:700;background:var(--pg-surface-2);color:var(--pg-ink-2);border-radius:6px;padding:2px 7px;flex:none;margin-top:2px}
.opt-l{font-weight:700;font-size:15px;letter-spacing:-.01em}
.opt-n{font-size:13px;color:var(--pg-ink-2);margin-top:2px;line-height:1.45}
.stamp{display:inline-block;font-size:10px;font-weight:700;letter-spacing:.05em;text-transform:uppercase;border-radius:999px;padding:2px 8px;vertical-align:2px;margin-left:4px;background:var(--pg-surface-2);color:var(--pg-ink-3);border:1px solid var(--pg-line)}
.stamp-on{background:var(--pg-accent);color:var(--pg-accent-ink);border-color:transparent}
.opt-col.chosen .phone{outline:2px solid var(--pg-accent);outline-offset:4px}
.opt-col.passed .phone{opacity:.72}
.opt-col.passed:hover .phone{opacity:1}
.opt-col[hidden]{display:none}

/* ---- phone ---- */
.phone{width:340px;border-radius:26px;padding:8px;background:var(--pg-surface);border:1px solid var(--pg-line);box-shadow:var(--pg-shadow)}
.scr{width:100%;height:640px;border-radius:19px;overflow:hidden;background:var(--bg);color:var(--ink);display:flex;flex-direction:column;position:relative;font-size:14px;font-variant-numeric:tabular-nums}
.scr-body{flex:1;overflow-y:auto;overflow-x:hidden;scrollbar-width:thin}
.scr-body::-webkit-scrollbar{width:5px}
.scr-body::-webkit-scrollbar-thumb{background:var(--line);border-radius:3px}
.sb{display:flex;justify-content:space-between;align-items:center;padding:8px 16px 4px;font-size:11px;font-weight:600;color:var(--ink-2);flex:none}
.sbr{display:flex;gap:5px;align-items:center;color:var(--ink-2)}
.ab{display:flex;align-items:center;gap:8px;padding:6px 12px 12px;flex:none}
.ab-t{flex:1;min-width:0}
.ab-title{font-size:16px;font-weight:700;letter-spacing:-.01em}
.ab-sub{font-size:11.5px;color:var(--ink-3)}
.ab-icon{width:30px;height:30px;border-radius:8px;border:none;background:transparent;color:var(--ink-2);display:grid;place-items:center;cursor:pointer;flex:none}
.ab-icon svg{width:19px;height:19px}
.ab-sp{width:30px;flex:none}
.ab-act,.ab-step{font-size:12.5px;font-weight:600;color:var(--accent);flex:none}
.ab-step{color:var(--ink-3)}
.pad{padding:0 14px 20px}.pad-t{padding:2px 14px 20px}.pad-b{padding:12px 14px 16px;flex:none}

.card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r-lg);padding:12px 14px;margin-bottom:10px}
.sec{margin-bottom:10px}
.sec-h{display:flex;justify-content:space-between;align-items:baseline;font-size:11px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3);padding:12px 2px 6px}
.sec-a{color:var(--accent);letter-spacing:0;text-transform:none;font-size:12px}
.sec-t{font-size:13px;font-weight:700;margin-bottom:6px}

.dh{display:flex;justify-content:space-between;align-items:flex-start;gap:10px;padding:4px 0 12px}
.dh-sm{padding-bottom:8px}
.dh-d{font-size:16px;font-weight:700;letter-spacing:-.01em}
.dh-w{font-size:11.5px;color:var(--ink-3);margin-top:1px}

.ringrow{display:grid;grid-template-columns:auto 1fr;gap:14px;align-items:center}
.ringwrap{position:relative;width:var(--rs,118px);height:var(--rs,118px)}
.ringwrap svg{width:100%;height:100%;display:block}
.ringtxt{position:absolute;inset:0;display:grid;place-content:center;text-align:center}
.ringnum{font-size:26px;font-weight:700;line-height:1;letter-spacing:-.02em}
.ringlab{font-size:10px;color:var(--ink-3);margin-top:3px}
.ringside{display:flex;flex-direction:column;gap:5px;min-width:0}
.kv{display:flex;justify-content:space-between;gap:8px;font-size:12.5px;border-bottom:1px dotted var(--line);padding-bottom:4px}
.kv:last-child{border-bottom:none;padding-bottom:0}
.kv span{color:var(--ink-3)}.kv b{font-weight:600}

.brow{display:grid;grid-template-columns:50px 1fr 72px;align-items:center;gap:9px;padding:5px 0}
.bname{font-size:12.5px;color:var(--ink-2);font-weight:600}
.btrack{position:relative;height:9px;background:var(--track);border-radius:999px}
.bfill{position:absolute;left:0;top:0;bottom:0;border-radius:999px;box-shadow:0 0 0 2px var(--surface)}
.btick{position:absolute;top:-3px;bottom:-3px;width:2px;background:var(--ink-2);border-radius:2px;opacity:.6}
.bval{font-size:12.5px;text-align:right;white-space:nowrap}
.bval b{font-weight:700}.mu{color:var(--ink-3);font-size:11.5px}

.quick{display:flex;gap:6px;margin-top:9px}
.qb{flex:1;font:inherit;font-size:12px;font-weight:600;cursor:pointer;background:var(--accent);color:var(--accent-ink);border:1px solid transparent;border-radius:999px;padding:9px 4px;min-height:36px}
.qb-alt{background:var(--accent-soft);color:var(--accent-soft-ink);border-color:var(--line)}

.chips{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}
.chip{display:inline-flex;align-items:center;gap:5px;font-size:11.5px;font-weight:600;background:var(--surface-2);color:var(--ink-2);border:1px solid var(--line);border-radius:999px;padding:4px 10px}
.chip-score{background:var(--accent-soft);color:var(--accent-soft-ink);border-color:transparent;font-size:12px}
.dot{width:7px;height:7px;border-radius:50%;flex:none}
.dot-ok{background:var(--ok)}.dot-low{background:var(--low)}.dot-high{background:var(--high)}.dot-unknown{background:var(--unknown)}

.meal{display:flex;justify-content:space-between;align-items:baseline;gap:8px;font-size:13.5px;font-weight:600;padding-top:9px}
.card .meal:first-child{padding-top:0}
.meal-k{color:var(--ink-2);font-size:12.5px}
.meal-i{font-size:11.5px;color:var(--ink-3);line-height:1.45;margin-top:2px}
.meal.empty .meal-n{color:var(--ink-3)}
.meal-add{color:var(--accent);font-size:12.5px;font-weight:700}

.bnav{display:flex;align-items:center;border-top:1px solid var(--line);background:var(--surface);padding:6px 4px 8px;flex:none}
.nav-i{flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;font-size:10px;font-weight:600;color:var(--ink-3);padding:4px 0}
.nav-i svg{width:20px;height:20px}
.nav-i.active{color:var(--accent)}
.nav-fab{flex:1;display:grid;place-items:center}
.fab{width:44px;height:44px;border-radius:999px;background:var(--accent);color:var(--accent-ink);display:grid;place-items:center;box-shadow:var(--el-2)}
.fab svg{width:22px;height:22px}

.lr{display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid var(--line)}
.card .lr:last-child{border-bottom:none;padding-bottom:0}
.card .lr:first-child{padding-top:0}
.lr-m{flex:1;min-width:0}
.lr-main{font-size:13.5px;font-weight:600;display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.lr-sub{font-size:11.5px;color:var(--ink-3);margin-top:1px}
.lr-r{font-size:12.5px;color:var(--ink-2);font-weight:600;display:inline-flex;align-items:center;gap:4px;flex:none}
.lr-r svg{width:15px;height:15px;color:var(--ink-3)}
.lr-l{flex:none;display:inline-flex}
.lr-accent .lr-r{color:var(--accent)}
.lr-tap .lr-r{color:var(--ink-3)}
.add{width:26px;height:26px;border-radius:999px;background:var(--accent-soft);color:var(--accent-soft-ink);display:grid;place-items:center;font-weight:700;font-size:15px}

.btn{font:inherit;font-weight:600;font-size:14px;cursor:pointer;border-radius:999px;padding:12px 18px;border:1px solid transparent;min-height:46px}
.btn-full{display:block;width:100%}
.btn-primary{background:var(--accent);color:var(--accent-ink)}
.btn-soft{background:var(--accent-soft);color:var(--accent-soft-ink);border-color:var(--line)}
.btn-ghost{background:transparent;color:var(--ink-2)}
.btn-sm{min-height:32px;padding:6px 14px;font-size:12.5px;width:auto;display:inline-block}

.ob{padding:24px 20px 18px;display:flex;flex-direction:column;height:100%;gap:14px}
.ob-mark{width:44px;height:44px;border-radius:13px;background:var(--accent);color:var(--accent-ink);display:grid;place-items:center;font-weight:700;font-size:21px}
.ob-h{font-size:27px;font-weight:700;line-height:1.15;letter-spacing:-.025em;margin-top:6px}
.ob-h2{font-size:25px;font-weight:700;letter-spacing:-.02em}
.ob-p{color:var(--ink-2);font-size:14.5px}
.ob-dots{display:flex;gap:6px;margin-top:auto}
.ob-dots i{width:6px;height:6px;border-radius:999px;background:var(--line)}
.ob-dots i.on{background:var(--accent);width:18px}
.ob-foot{display:flex;flex-direction:column;gap:6px}
.ob-fine{font-size:11.5px;color:var(--ink-3);text-align:center}
.ob-list{list-style:none;padding:0;margin:4px 0 auto;display:flex;flex-direction:column;gap:9px;font-size:13.5px;color:var(--ink-2)}
.ob-list li{display:flex;align-items:center;gap:9px}
.ob-list svg{width:15px;height:15px;color:var(--ok);flex:none}

.wiz{min-height:100%;display:flex;flex-direction:column}
.wstep{display:none;flex-direction:column;flex:1;min-height:100%}
.wstep.on{display:flex}
.wstep .pad{flex:1}
.wizctl{display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-top:12px;padding:9px 11px;border:1px solid var(--pg-line);background:var(--pg-surface);border-radius:9px}
.wc-l{font-size:11px;font-weight:600;letter-spacing:.07em;text-transform:uppercase;color:var(--pg-ink-3)}
.wc{width:26px;height:26px;border-radius:999px;border:1px solid var(--pg-line);background:transparent;color:var(--pg-ink-2);font:inherit;font-size:12px;font-weight:700;cursor:pointer;padding:0}
.wc:hover{border-color:var(--pg-ink-3);color:var(--pg-ink)}
.wc.on{background:var(--pg-accent);border-color:transparent;color:var(--pg-accent-ink)}
.wc-names{position:relative;flex:1;min-width:110px;height:16px}
.wc-n{position:absolute;inset:0;font-size:12px;font-weight:600;color:var(--pg-ink-2);opacity:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.wc-n.on{opacity:1}
.q-h{font-size:19px;font-weight:700;letter-spacing:-.015em;margin-top:4px}
.q-h2{font-size:16px;font-weight:700;letter-spacing:-.01em;margin-top:20px}
.q-hint{font-size:12px;color:var(--ink-3);margin-top:6px}
.q-s{font-size:13px;color:var(--ink-3);margin-top:4px}
.opts{display:flex;flex-direction:column;gap:8px;margin-top:14px}
.opt{display:flex;justify-content:space-between;align-items:center;gap:8px;border:1px solid var(--line);border-radius:var(--r-md);padding:11px 13px;background:var(--surface);min-height:48px}
.opt b{font-size:13.5px;display:block}
.opt i{font-size:11.5px;color:var(--ink-3);font-style:normal;display:block;margin-top:1px}
.opt.sel{border-color:var(--accent);background:var(--accent-soft)}
.opt-c{color:var(--accent)}.opt-c svg{width:17px;height:17px}
.fgrid{display:flex;flex-direction:column;gap:10px;margin-top:4px}
.frow{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.fld span{font-size:11.5px;font-weight:600;color:var(--ink-2);display:block;margin-bottom:4px}
.fld i{font-weight:400;color:var(--ink-3);font-style:normal}
.fld input{width:100%;font:inherit;font-size:14px;color:var(--ink);background:var(--surface);border:1px solid var(--line);border-radius:var(--r-md);padding:11px 12px;min-height:44px}
.callout{margin-top:14px;background:var(--accent-soft);border-radius:var(--r-md);padding:12px 14px;color:var(--accent-soft-ink)}
.callout b{font-size:12.5px}
.callout-g{display:grid;grid-template-columns:auto auto;gap:3px 14px;margin:8px 0;font-size:13px}
.callout-g b{text-align:right}
.callout p{font-size:11.5px;opacity:.85}

.strip{display:flex;gap:8px;margin-bottom:10px}
.st{flex:1;background:var(--surface);border:1px solid var(--line);border-radius:var(--r-md);padding:9px 10px}
.st b{font-size:19px;font-weight:700;display:block;letter-spacing:-.02em}
.st b i{font-size:12px;color:var(--ink-3);font-style:normal;font-weight:600}
.st span{font-size:10.5px;color:var(--ink-3)}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:10px}
.grid2 .card{margin:0;padding:11px 12px}
.tile span{font-size:10.5px;color:var(--ink-3);display:block}
.tile b{font-size:24px;font-weight:700;letter-spacing:-.02em;display:block;line-height:1.1;margin:2px 0}
.tile b em{font-size:13px;font-style:normal;color:var(--ink-2)}
.tile i{font-size:11px;color:var(--ink-3);font-style:normal}
.tile i.warn{color:var(--low)}

.sheet-bg{position:absolute;inset:0;display:flex;flex-direction:column;background:var(--scrim)}
.sheet-bg .dim{opacity:.5;pointer-events:none}
.sheet{margin-top:auto;background:var(--surface-3);border-radius:var(--r-xl) var(--r-xl) 0 0;padding:8px 14px 18px;box-shadow:var(--el-3);max-height:74%;overflow-y:auto}
.sheet-grab{width:36px;height:4px;border-radius:999px;background:var(--line-strong);margin:0 auto 10px}
.sheet-h{display:flex;justify-content:space-between;align-items:baseline;font-size:15px;font-weight:700;margin-bottom:10px}
.chg{font-size:12.5px;color:var(--accent);font-weight:600}
.tabs{display:flex;gap:6px;margin-bottom:6px;overflow-x:auto}
.tab{font-size:12px;font-weight:600;color:var(--ink-2);background:var(--surface-2);border-radius:999px;padding:6px 12px;white-space:nowrap}
.tab.on{background:var(--accent);color:var(--accent-ink)}

.search{display:flex;align-items:center;gap:8px;background:var(--surface-2);border:1px solid var(--line);border-radius:var(--r-md);padding:11px 12px;min-height:46px;margin-top:2px}
.search .s-i{color:var(--ink-3);display:inline-flex}.search svg{width:17px;height:17px}
.s-ph{color:var(--ink-3);font-size:13.5px}
.s-v{font-size:14px;flex:1}
.s-x{color:var(--ink-3);font-size:16px}
.search.on{border-color:var(--accent)}
.filters{display:flex;gap:6px;margin-top:10px;overflow-x:auto}
.fchip{font-size:12px;font-weight:600;color:var(--ink-2);background:var(--surface-2);border:1px solid var(--line);border-radius:999px;padding:5px 11px;white-space:nowrap}
.fchip.on{background:var(--accent);color:var(--accent-ink);border-color:transparent}
.qt{font-size:9.5px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;border-radius:4px;padding:2px 5px;background:var(--surface-2);color:var(--ink-3);border:1px solid var(--line)}
.qt-ver{color:var(--ok)}.qt-der{color:var(--accent-soft-ink);background:var(--accent-soft);border-color:transparent}.qt-user{color:var(--high)}
.mk{margin-top:12px;text-align:center;font-size:13px;font-weight:600;color:var(--accent);border:1px dashed var(--line-strong);border-radius:var(--r-md);padding:11px;min-height:44px;display:grid;place-items:center}

.chipset{display:flex;flex-wrap:wrap;gap:6px}
.sch{font-size:12.5px;font-weight:600;border:1px solid var(--line);background:var(--surface);border-radius:var(--r-md);padding:8px 11px;min-height:40px;display:flex;flex-direction:column;justify-content:center}
.sch i{font-size:10.5px;color:var(--ink-3);font-style:normal;font-weight:500}
.sch.on{border-color:var(--accent);background:var(--accent-soft);color:var(--accent-soft-ink)}
.chipset.sm .sch{min-height:34px;padding:6px 12px}
.stepper{display:flex;align-items:center;gap:10px;margin-top:12px;background:var(--surface);border:1px solid var(--line);border-radius:var(--r-md);padding:6px}
.stepper button{width:42px;height:42px;border-radius:var(--r-sm);border:1px solid var(--line);background:var(--surface-2);color:var(--ink);font:inherit;font-size:20px;font-weight:600;cursor:pointer}
.stp-v{flex:1;text-align:center}
.stp-v b{font-size:19px;font-weight:700}
.stp-v span{font-size:11.5px;color:var(--ink-3);display:block}
.nutrhead{display:flex;align-items:baseline;gap:7px;padding-bottom:8px;border-bottom:1px solid var(--line);margin-bottom:6px}
.nutrhead b{font-size:23px;font-weight:700;letter-spacing:-.02em}
.nutrhead span{font-size:11.5px;color:var(--ink-3)}
.nrow{display:flex;justify-content:space-between;font-size:13px;padding:7px 2px;border-bottom:1px solid var(--line)}
.nrow span{color:var(--ink-2)}
.unk{color:var(--ink-3)}
.fine{font-size:11.5px;color:var(--ink-3);margin-top:8px;line-height:1.45}
.fine.ctr{text-align:center}
.amt{text-align:center;padding:18px 0 8px}
.amt-v{font-size:44px;font-weight:700;letter-spacing:-.03em;line-height:1}
.amt-u{font-size:12px;color:var(--ink-3);margin-top:4px}
.kcalbig{text-align:center;padding:14px 0 10px}
.kcalbig b{font-size:30px;font-weight:700;letter-spacing:-.02em}
.kcalbig span{font-size:12px;color:var(--ink-3);margin-left:4px}

.tpl-h{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
.tpl-h b{font-size:14px}
.tpl-k{font-size:12px;color:var(--ink-2);font-weight:600}
.tpl-i{font-size:11.5px;color:var(--ink-3);margin-top:4px;line-height:1.45}
.tpl-f{display:flex;justify-content:space-between;align-items:center;margin-top:10px}
.tpl-u{font-size:11px;color:var(--ink-3)}

.wfill{display:grid;place-items:center;padding:6px 0 12px}
.wfill-b{width:106px;height:132px;border:2px solid var(--line-strong);border-radius:10px 10px 18px 18px;position:relative;overflow:hidden;background:var(--surface-2)}
.wfill-l{position:absolute;left:0;right:0;bottom:0;background:var(--accent);opacity:.85}
.wfill-t{position:absolute;inset:0;display:grid;place-content:center;text-align:center}
.wfill-t b{font-size:25px;font-weight:700;display:block;color:var(--ink)}
.wfill-t span{font-size:11px;color:var(--ink-2)}
.wdot{width:9px;height:9px;border-radius:999px;background:var(--accent);display:block}
.wdot-alt{background:var(--accent-soft);border:1.5px solid var(--accent)}
.glasses{display:grid;grid-template-columns:repeat(5,1fr);gap:9px;padding:6px 0 4px}
.gl{height:42px;border-radius:5px 5px 9px 9px;border:2px solid var(--line-strong);background:var(--surface-2)}
.gl.on{background:var(--accent);border-color:var(--accent)}
.wkbars{display:flex;align-items:flex-end;gap:7px;height:70px;padding-top:6px}
.wk{flex:1;display:flex;flex-direction:column;align-items:center;gap:5px;height:100%;justify-content:flex-end}
.wk-b{width:100%;background:var(--accent);border-radius:4px 4px 0 0;min-height:3px}
.wk i{font-size:10px;color:var(--ink-3);font-style:normal}
.wk-l{font-size:11px;color:var(--ink-3);margin-top:7px}

.verdict{font-size:15.5px;font-weight:600;line-height:1.45;letter-spacing:-.005em}
.vscore{display:flex;align-items:baseline;gap:8px;margin-top:12px}
.vscore-lg{margin-top:0;justify-content:center;padding:6px 0}
.band{font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;background:var(--accent-soft);color:var(--accent-soft-ink);border-radius:999px;padding:3px 9px}
.vscore b{font-size:32px;font-weight:700;letter-spacing:-.02em}
.vscore-lg b{font-size:46px}
.of{font-size:13px;color:var(--ink-3)}
.ins{font-size:13px;line-height:1.45;padding:9px 0 9px 12px;border-left:3px solid var(--line);border-bottom:1px solid var(--line)}
.card .ins:last-child{border-bottom:none;padding-bottom:0}
.ins-ok{border-left-color:var(--ok)}.ins-low{border-left-color:var(--low)}.ins-high{border-left-color:var(--high)}.ins-note{border-left-color:var(--unknown)}
.ss{display:grid;grid-template-columns:1fr 74px 28px;align-items:center;gap:9px;padding:7px 0}
.ss-n{font-size:12.5px;font-weight:600}
.ss-n i{font-size:10.5px;color:var(--ink-3);font-style:normal;font-weight:500}
.ss-t{height:7px;background:var(--track);border-radius:999px;position:relative;overflow:hidden}
.ss-f{position:absolute;inset:0 auto 0 0;background:var(--accent);border-radius:999px}
.ss-t-off{background:transparent;border:1px dashed var(--line-strong);height:9px}
.ss-why{font-size:10.5px;color:var(--ink-3);margin:-2px 0 4px;line-height:1.4}
.ss-v{font-size:13.5px;font-weight:700;text-align:right}
.ss-na{color:var(--ink-3)}
.nt{display:grid;grid-template-columns:60px 1fr 70px 46px;align-items:center;gap:7px;padding:6px 0;border-bottom:1px solid var(--line);font-size:12px}
.card .nt:last-child{border-bottom:none}
.nt>span:first-child{color:var(--ink-2);font-weight:600}
.nt-b{height:6px;background:var(--track);border-radius:999px;position:relative;overflow:hidden}
.nt-f{position:absolute;inset:0 auto 0 0;border-radius:999px}
.nt b{text-align:right;font-weight:700;white-space:nowrap}
.nt-s{font-size:9.5px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;text-align:right;white-space:nowrap}
.st-ok{color:var(--ok)}.st-low{color:var(--low)}.st-high{color:var(--high)}.st-na{color:var(--ink-3)}

.ch-h{display:flex;justify-content:space-between;align-items:baseline;font-size:12px;font-weight:600;margin-bottom:8px}
.ch-h i{font-size:10.5px;color:var(--ink-3);font-style:normal;font-weight:500}
.chart{display:flex;align-items:flex-end;gap:7px;height:88px;position:relative;padding-bottom:16px}
.cb{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;gap:4px;position:relative}
.cb-b{width:100%;background:var(--accent);border-radius:4px 4px 0 0}
.cb-b.cb-off{background:var(--track)}
.cb i{font-size:10px;color:var(--ink-3);font-style:normal;position:absolute;bottom:-15px}
.ch-tgt{position:absolute;left:0;right:0;top:22%;border-top:1.5px dashed var(--ink-3);opacity:.6}
.ch-f{font-size:10.5px;color:var(--ink-3);margin-top:4px}
.spark{width:100%;height:64px;display:block;margin:2px 0 4px}
.cmp{display:flex;justify-content:space-between;align-items:baseline;font-size:12px;border-top:1px solid var(--line);padding-top:9px;margin-top:6px}
.cmp span{color:var(--ink-3)}
.cmp b.up{color:var(--ok);font-size:15px}
.avg{display:grid;grid-template-columns:1fr auto;gap:2px 10px;padding:8px 0;border-bottom:1px solid var(--line)}
.card .avg:last-child{border-bottom:none;padding-bottom:0}
.avg span{font-size:12.5px;color:var(--ink-2);font-weight:600}
.avg b{font-size:15px;font-weight:700;text-align:right}
.avg i{grid-column:1/-1;font-size:10.5px;color:var(--ink-3);font-style:normal}
.hm-days{display:grid;grid-template-columns:repeat(7,1fr);gap:4px;margin-bottom:4px}
.hm-days i{font-size:9.5px;color:var(--ink-3);font-style:normal;text-align:center}
.hmgrid{display:grid;grid-template-columns:repeat(7,1fr);gap:4px}
.hm{aspect-ratio:1;border-radius:4px;background:var(--track);display:block}
.hm-0{background:var(--track)}
.hm-1{background:var(--accent);opacity:.22}
.hm-2{background:var(--accent);opacity:.45}
.hm-3{background:var(--accent);opacity:.7}
.hm-4{background:var(--accent)}
.hm-key{display:flex;align-items:center;gap:4px;margin-top:9px;font-size:9.5px;color:var(--ink-3)}
.hm-key .hm{width:11px;height:11px;aspect-ratio:auto;flex:none}

.notebox{margin-top:12px;background:var(--accent-soft);color:var(--accent-soft-ink);border-radius:var(--r-md);padding:11px 13px;font-size:12px;line-height:1.45}
.tgt-h{display:flex;justify-content:space-between;align-items:center}
.tgt-h b{font-size:14px}
.tgt-v{font-size:28px;font-weight:700;letter-spacing:-.02em;margin:4px 0 10px}
.tgt-v i{font-size:14px;color:var(--ink-3);font-style:normal;margin-left:3px}
.slider{position:relative;height:22px;display:flex;align-items:center}
.sl-t{height:5px;background:var(--track);border-radius:999px;width:100%;position:relative;overflow:hidden}
.sl-f{position:absolute;inset:0 auto 0 0;width:55%;background:var(--accent);border-radius:999px}
.sl-f.sl-70{width:70%}.sl-f.sl-60{width:60%}
.sl-k{position:absolute;left:55%;width:20px;height:20px;border-radius:999px;background:var(--surface);border:2px solid var(--accent);transform:translateX(-50%);box-shadow:var(--el-1)}
.sl-k.sl-k70{left:70%}.sl-k.sl-k60{left:60%}
.lnk{color:var(--accent);font-weight:600}
.av{width:26px;height:26px;border-radius:999px;display:grid;place-items:center;font-size:11.5px;font-weight:700;flex:none}
.av-1{background:var(--accent);color:var(--accent-ink)}
.av-2{background:var(--high);color:var(--surface)}
.av-lg{width:42px;height:42px;font-size:17px}
.prof{display:flex;align-items:center;gap:11px}
.prof b{font-size:15px;display:block}
.prof i{font-size:11.5px;color:var(--ink-3);font-style:normal}
.sw-b{margin-left:auto;font-size:12.5px;font-weight:600;color:var(--accent)}
.bk{display:flex;align-items:center;gap:10px;background:var(--surface-2);border-radius:var(--r-md);padding:10px 12px;margin:10px 0}
.bk-ok{width:26px;height:26px;border-radius:999px;background:var(--ok);color:var(--surface);display:grid;place-items:center;flex:none}
.bk-ok svg{width:15px;height:15px}
.bk b{font-size:13px;display:block}
.bk i{font-size:11px;color:var(--ink-3);font-style:normal}
.rm{display:flex;justify-content:space-between;font-size:13px;padding:7px 0;border-bottom:1px solid var(--line)}
.card .rm:last-child{border-bottom:none;padding-bottom:0}
.rm span{color:var(--ink-2)}.rm b{font-weight:600}
.dgr{color:var(--danger)}

/* ---- selections panel ---- */
.panel{position:fixed;inset:0;z-index:60;display:none}
.panel.open{display:block}
.panel-bg{position:absolute;inset:0;background:rgba(10,12,20,.5)}
.panel-in{position:absolute;right:0;top:0;bottom:0;width:min(420px,100%);background:var(--pg-surface);border-left:1px solid var(--pg-line);display:flex;flex-direction:column;box-shadow:var(--pg-shadow)}
.panel-h{display:flex;justify-content:space-between;align-items:center;padding:16px 20px;border-bottom:1px solid var(--pg-line)}
.panel-h b{font-size:16px}
.panel-x{border:none;background:transparent;color:var(--pg-ink-2);font-size:22px;cursor:pointer;line-height:1;padding:4px 8px}
.panel-b{flex:1;overflow-y:auto;padding:8px 20px 20px}
.pr{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:11px 0;border-bottom:1px solid var(--pg-line);font-size:14px}
.pr b{font-weight:700;display:block}
.pr i{font-style:normal;font-size:12px;color:var(--pg-ink-3);display:block;margin-top:2px;line-height:1.4}
.prk{flex:none;width:26px;height:26px;border-radius:999px;background:var(--pg-accent);color:var(--pg-accent-ink);display:grid;place-items:center;font-size:12px;font-weight:700}
.panel-f{padding:16px 20px;border-top:1px solid var(--pg-line);display:flex;flex-direction:column;gap:9px}
.cpy{font:inherit;font-size:14px;font-weight:600;cursor:pointer;border-radius:9px;padding:11px;border:1px solid transparent;background:var(--pg-accent);color:var(--pg-accent-ink)}
.clr{font:inherit;font-size:13px;font-weight:600;cursor:pointer;border-radius:9px;padding:9px;border:1px solid var(--pg-line);background:transparent;color:var(--pg-ink-2)}
.panel-note{font-size:12px;color:var(--pg-ink-3);line-height:1.5}
.panel-note code{font-family:var(--mono);font-size:11.5px;background:var(--pg-surface-2);padding:1px 4px;border-radius:4px}

.close{padding:40px 0 70px;border-top:1px solid var(--pg-line)}
.close h2{font-size:24px;font-weight:700;letter-spacing:-.02em;margin-bottom:14px}
.close p{color:var(--pg-ink-2);font-size:14.5px;max-width:70ch}
.close p+p{margin-top:10px}
.close code{font-family:var(--mono);font-size:12.5px;background:var(--pg-surface-2);padding:1px 5px;border-radius:4px}

@media (max-width:768px){
  .opt-col{width:100%;max-width:340px}
  .wrap{padding:0 16px}
}
@media (prefers-reduced-motion: reduce){*{animation:none!important;transition:none!important;scroll-behavior:auto!important}}
"""

def build():
    css = (PAGE_CSS.replace("__STATIC__", STATIC_VARS)
                   .replace("__LIGHT__", css_vars("light"))
                   .replace("__DARK__", css_vars("dark")))
    rail = "".join(
        f'<a class="rl" href="#{s["id"]}">{s["n"]}. {s["name"]} <i>{CHOSEN.get(s["id"],"—")}</i></a>'
        for s in S)
    groups = []
    for s in S:
        cols = []
        for o in s["options"]:
            is_chosen = CHOSEN.get(s["id"]) == o["key"]
            state = "chosen" if is_chosen else "passed"
            stamp = ('<span class="stamp stamp-on">Chosen</span>' if is_chosen
                     else '<span class="stamp">Not chosen</span>')
            cols.append(f'''<div class="opt-col {state}" data-state="{state}">
        <div class="opt-hd"><span class="opt-k">{o['key']}</span><div><div class="opt-l">{o['label']} {stamp}</div><div class="opt-n">{o['note']}</div></div></div>
        <div class="phone">{o['html']}</div>
        {wizard_ctl(o["wizard"], o["steps"]) if o.get("wizard") else ""}
      </div>''')
        groups.append(f'''<section class="grp" id="{s['id']}">
      <div class="grp-h"><div class="grp-n">Screen {s['n']} of {len(S)} &middot; chosen: option {CHOSEN.get(s['id'],'—')}</div><h2 class="grp-t">{s['name']}</h2><p class="grp-p">{s['purpose']}</p></div>
      <div class="opts-row">{"".join(cols)}</div>
    </section>''')

    def _alts(s):
        return " · ".join(o["key"] + " " + o["label"] for o in s["options"] if o["key"] != CHOSEN.get(s["id"]))
    panel_rows = "".join(
        f'<div class="pr"><div><b>{s["n"]}. {s["name"]}</b>'
        f'<i>not chosen: {_alts(s)}</i></div>'
        f'<span class="prk">{CHOSEN.get(s["id"],"—")}</span></div>' for s in S)

    js = """
(function(){
  var root=document.documentElement, KEY='nourishly.proto.picks.v1';
  var btn=document.getElementById('modeBtn'), lab=document.getElementById('modeLabel'), ico=document.getElementById('modeIcon');
  var SUN='<circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path>';
  var MOON='<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path>';
  function paint(m){root.setAttribute('data-theme',m);lab.textContent=m==='dark'?'Dark':'Light';ico.innerHTML=m==='dark'?MOON:SUN;
    btn.setAttribute('aria-label','Showing '+m+' mode. Switch to '+(m==='dark'?'light':'dark')+'.');}
  paint(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light');
  btn.addEventListener('click',function(){paint(root.getAttribute('data-theme')==='dark'?'light':'dark');});

  var showAll=false;
  var fBtn=document.getElementById('filterBtn'), fCount=document.getElementById('filterCount');
  function applyFilter(){
    document.querySelectorAll('.opt-col').forEach(function(c){
      c.hidden = (!showAll && c.dataset.state==='passed');
    });
    fCount.textContent = showAll ? 'all 28 options' : '13 chosen';
    fBtn.setAttribute('aria-pressed', String(!showAll));
    fBtn.title = showAll ? 'Show only the chosen option per screen' : 'Show every option, including those not chosen';
  }
  fBtn.addEventListener('click',function(){showAll=!showAll;applyFilter();});
  applyFilter();

  document.querySelectorAll('[data-wiz]').forEach(function(wiz){
    var id=wiz.getAttribute('data-wiz');
    var steps=wiz.querySelectorAll('[data-wstep]');
    var ctl=document.querySelector('[data-wizctl="'+id+'"]');
    var cur=0;
    function go(n){
      cur=Math.max(0,Math.min(steps.length-1,n));
      steps.forEach(function(s,i){s.classList.toggle('on',i===cur);});
      if(ctl){
        ctl.querySelectorAll('[data-wgo]').forEach(function(b,i){b.classList.toggle('on',i===cur);});
        ctl.querySelectorAll('[data-wname]').forEach(function(b,i){b.classList.toggle('on',i===cur);});
      }
      wiz.closest('.scr-body').scrollTop=0;
    }
    wiz.addEventListener('click',function(e){
      if(e.target.closest('.btn-primary')){go(cur+1);}
      else if(e.target.closest('.ab-icon')){go(cur-1);}
    });
    if(ctl){ctl.addEventListener('click',function(e){
      var b=e.target.closest('[data-wgo]'); if(b) go(parseInt(b.getAttribute('data-wgo'),10));
    });}
  });

  var panel=document.getElementById('panel');
  document.getElementById('selBtn').addEventListener('click',function(){panel.classList.add('open');});
  document.getElementById('panelX').addEventListener('click',function(){panel.classList.remove('open');});
  document.getElementById('panelBg').addEventListener('click',function(){panel.classList.remove('open');});
  document.addEventListener('keydown',function(e){if(e.key==='Escape')panel.classList.remove('open');});


})();
"""

    return f'''<title>Nourishly Approved Screens</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap">
<style>{css}</style>

<div class="bar"><div class="wrap barin">
  <div class="brand">Nourishly <i>· screen prototype · Indigo</i></div>
  <span class="spacer"></span>
  <button type="button" class="selbtn" id="filterBtn" aria-pressed="true">Showing <b id="filterCount">13 chosen</b></button>
  <button type="button" class="selbtn" id="selBtn">Decisions</button>
  <button type="button" class="tgl" id="modeBtn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true" id="modeIcon"></svg><span id="modeLabel">Light</span></button>
</div></div>

<main class="wrap">
  <div class="intro">
    <div class="kick">Approved · Indigo theme · {len(S)} screens decided</div>
    <h1>The approved screens</h1>
    <p class="lede">One treatment chosen per screen. The page opens showing only those — switch to <b>All 28 options</b> in the header to see the alternatives, which are kept rather than deleted.</p>
    <p class="lede">Every pixel is driven by <code>tokens/nourishly-indigo.json</code>, the approved theme. The prototype cannot drift from it, because it reads the same file.</p>
    <div class="hownote"><b>Nothing is functional.</b> These are static screens showing layout, hierarchy and density — one plausible Thursday in a Gujarati household. Profile setup is the exception: its five steps are steppable, so the flow can be judged.</div>
  </div>
</main>

<div class="rail"><div class="wrap railin">{rail}</div></div>

<main class="wrap">
  {"".join(groups)}

  <section class="close">
    <h2>Where this goes next</h2>
    <p>These 13 screens are the implementation targets: the token file becomes the <code>nourishly_ui</code> package, and each screen becomes a feature module under the structure in §12.3 of the architecture.</p>
    <p><code>decisions.md</code> records the full set alongside two refinements worth settling first — the daily report keeping its verdict line and insights around the table, and a length strategy for the goals screen once all 24 nutrients are on it.</p>
    <p><b>No implementation has begun.</b></p>
  </section>
</main>

<div class="panel" id="panel" role="dialog" aria-modal="true" aria-label="Your screen choices">
  <div class="panel-bg" id="panelBg"></div>
  <div class="panel-in">
    <div class="panel-h"><b>Decisions</b><button class="panel-x" id="panelX" type="button" aria-label="Close">×</button></div>
    <div class="panel-b">{panel_rows}</div>
    <div class="panel-f">
      <p class="panel-note">Approved 9 September 2026. Discarded options are kept in the prototype, not deleted — see <code>decisions.md</code>.</p>
    </div>
  </div>
</div>
<script>{js}</script>
'''

if __name__ == "__main__":
    out = ROOT / "prototype.html"
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out} — {len(S)} screens, {sum(len(s['options']) for s in S)} options, {out.stat().st_size:,} bytes")
