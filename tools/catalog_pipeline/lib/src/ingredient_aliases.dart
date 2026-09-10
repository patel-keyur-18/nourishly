/// Curated aliases from the ingredient strings recipes actually use to the
/// catalog row that supplies their nutrients.
///
/// [CatalogIndex] deliberately drops a name that several rows claim, because
/// guessing between them would put the wrong food's nutrients in the answer.
/// That is the right instinct, but it leaves the *most common* staples
/// unresolved — `oil` heads six rows, `curd` and `milk` two or three each —
/// and an unresolved ingredient used to fall through to a blind FoodData
/// Central search that returned whatever matched the string first. That is
/// how idli came to be computed from `APPLEBEE'S, fish, hand battered` and
/// tea from `Crackers, milk`.
///
/// So the ambiguity is resolved here instead: explicitly, as data, one line
/// per decision, reviewable in a diff. Everything not listed stays
/// unresolved and is *reported as a failure* rather than guessed at — the
/// catalog spec's own rule that nothing is invented (§0.2, AP-4).
///
/// Two conventions the catalog follows, both read off the source tables
/// rather than assumed:
///
/// - **A bare grain quantity is raw.** `Khichdi, plain` lists `Rice 45 g`
///   for a 180 g katori; 45 g of *cooked* rice could not become that. Rows
///   that mean cooked say so — `Lemon rice` lists `Rice cooked 150 g` — and
///   their quantities are two to three times larger. Hence `rice` -> raw and
///   `rice cooked` -> cooked, which the blind FDC path got wrong in both
///   directions.
/// - **The household's default cooking fat is groundnut oil**, the Tier-1
///   row in `01-common.md` §6.
///
/// An ingredient that is a real, distinct food with no row of its own is
/// not aliased to a near neighbour — it gets its own row in
/// `docs/catalog/01-common.md` instead, sourced like every other row. That
/// is where `Pav`, `Broken wheat`, `Puffed rice`, `Hung curd` (drained, so
/// denser than plain curd), `Colocasia leaves` (the catalog's `Colocasia`
/// is the root), `Black pepper`, `Flaxseed`, `Refined flour, maida`,
/// `Mixed vegetables` and `Lemon` came from.
///
/// Deliberately left *unresolved*, because no honest single row exists and
/// a plausible-looking wrong number is worse than a reported gap:
/// `oil/ghee`, `ghee/oil`, `butter/oil` and the other slashed alternates
/// (ghee is ~62% saturated against groundnut oil's ~17%, and saturated fat
/// is a limit nutrient — §22.5); `sugar syrup` (a sugar-to-water ratio
/// nobody wrote down); `moong dal soaked` (soaked weight is ~2x dry);
/// `toor dal water`, `legume stock`, `milk reduced` and `wheat extract`
/// (concentrations, not the ingredient); the spice powders `sambar podi`,
/// `rasam podi`, `saaru podi`, `huli podi`, `vangi bath powder` and
/// `BBB powder`; and the composite pastes, batters and fillings
/// (`rice-dal batter`, `besan-urad`, `khoya-coconut filling`,
/// `puliyogare paste`, `potato filling`, …). Each is a curation decision
/// for a human with the recipe in front of them, and `fetch_catalog.dart`
/// names the dish and the ingredient when it hits one.
const ingredientAliases = <String, String>{
  // Fats. Groundnut oil is the household default (Tier-1, §6); "absorbed"
  // is the deep-frying pickup, the same fat by another name.
  'oil': 'Groundnut oil',
  'absorbed oil': 'Groundnut oil',
  'tempering oil': 'Groundnut oil',
  'absorbed ghee': 'Ghee',

  // Grains and flours. See the raw/cooked convention above.
  'rice': 'Rice, white, raw',
  'rice cooked': 'Rice, white, cooked',
  'rava': 'Semolina, rava',
  'urad flour': 'Urad dal, raw',

  // The fermented batter behind the whole South Indian breakfast section.
  // The catalog row says so itself: "the base for idli, dosa, uttapam".
  'idli batter': 'Idli rice + urad batter',
  'dosa batter': 'Idli rice + urad batter',
  'rice batter': 'Idli rice + urad batter',

  // Dairy.
  'curd': 'Curd, plain',
  'milk': 'Milk, cow, whole',

  // Produce. `coriander` and `pepper` each head two rows (leaves/powder,
  // black/red-chilli); the recipes that use the bare word mean the first.
  'coconut': 'Coconut, fresh grated',
  'methi greens': 'Fenugreek leaves',
  'mango pulp': 'Mango',
  'egg': 'Egg, boiled',
  'coriander': 'Coriander leaves',
  'pepper': 'Black pepper',
  'peas': 'Green peas',
  'chickpeas': 'Chana, whole (kabuli)',

  // Pulses named by the grain rather than the split dal. `Idli` lists
  // "rice 45 g + urad 16 g raw basis"; "urad" there is the dal.
  'urad': 'Urad dal, raw',

  // Dishes used as an ingredient by another dish. Each names one row
  // unambiguously once the dish is read: a masala dosa is built on a plain
  // dosa, "podi with oil" is idli podi, and Dhokla's "rice-urad batter" is
  // the same fermented batter as idli's.
  'dosa': 'Dosa, plain',
  'rice-urad batter': 'Idli rice + urad batter',
  'podi': 'Idli podi',
  'potato masala': 'Palya, potato',
};

/// Ingredients that are water: real mass in the pot, no nutrients.
///
/// Water has to be resolvable rather than skipped, because the yield factor
/// is derived from total ingredient mass against the serving weight — a
/// dropped 60 ml of water would silently concentrate everything else.
const waterIngredients = <String>{'water'};
