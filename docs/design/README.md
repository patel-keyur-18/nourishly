# Design

*[Architecture index](../architecture/README.md) · [Catalog specification](../catalog/README.md)*

## Theme options — awaiting decision

**[`theme-options.html`](./theme-options.html)** — five candidate visual directions for Nourishly, each rendered as the same dashboard so the comparison is theme-only. One toggle switches every preview between its light and dark variant.

| Option | Direction | Character |
|---|---|---|
| **Haldi** | Turmeric on warm paper | The only palette drawn from the kitchen rather than from software convention |
| **Neem** | Green-forward, crisp | The conventional health-app read, executed with restraint |
| **Indigo** | Deep indigo, cool neutrals | Reads as an instrument you consult, not an app that nags |
| **Kora** | Near-colourless chrome | Colour means data and nothing else |
| **Nilgiri** | Teal, dark-first | Dark mode designed first, light derived from it |

### What was decided before the colours were picked

Each theme is a complete token set: surfaces, ink at three weights, an accent, and **four macro hues** for protein, carbs, fat and fibre.

Those four hues are the part that had to be right rather than pretty. All ten palettes (five themes × two modes) were checked programmatically for colour-blindness separation, chroma floor, lightness band, and contrast against their own surface. **Every one passes in both modes**, so the choice is purely about character — no option costs legibility.

Two collisions were caught and fixed this way: Indigo's accent originally matched its carbohydrate hue, and Nilgiri's teal accent matched its fibre hue. An accent that doubles as a data colour makes "brand" and "measurement" indistinguishable on screen.

### Design rules the previews demonstrate

These hold whichever theme is chosen, and they come from the architecture rather than from taste:

| Rule | Where you see it | Source |
|---|---|---|
| Bars are read against a target, not filled to an edge | The tick mark on every macro bar sits at 100% of target; the track runs to 125% so overshoot has somewhere to go | §27.11 |
| Over-target is never alarming | `above` uses a violet, not red. A food tracker must not scold | §21.8 |
| Never colour alone | Every status chip carries a dot **and** a label | NFR-A-04 |
| The score is withheld when the data is too thin | The "Micros: 58% covered — not scored" chip is coverage gating showing its work | §21.5 |
| Energy shows remaining, not consumed | "410 kcal left" is the large number; eaten and target sit beside it | UX-3 |
| Numbers align | Tabular figures throughout | §27.11 |

### Next

Pick one. It becomes the token set in `nourishly_ui` (§12.3) and the basis for the screen prototypes.

Nothing here is locked — the tokens are data, so a chosen theme can be re-tuned without touching feature code. That is the point of keeping the design system in one package.

---

`_generate.py` emits the per-theme CSS and preview markup for `theme-options.html`, so the light and dark token sets cannot drift apart by hand-editing.
