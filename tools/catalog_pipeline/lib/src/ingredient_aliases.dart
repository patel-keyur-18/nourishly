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
/// An ingredient that is a real, distinct food with no row of its own gets
/// its own row in `docs/catalog/01-common.md` rather than an alias to a near
/// neighbour — that is where `Pav`, `Broken wheat`, `Puffed rice`,
/// `Hung curd`, `Colocasia leaves`, `Black pepper` and `Flaxseed` came from.
///
/// Everything else is settled here with the closest sensible row. This is a
/// household tracker, not a lab: "oil/ghee" means oil, a 3 g tempering is
/// mostly oil, and a coconut filling is mostly coconut. Being 10% off on
/// 5 g of spice powder does not change anything a person would do; dropping
/// the paratha, the biryani and every filled sweet out of the catalog
/// because nobody wrote down a ratio very much does.
///
/// The line that still holds is the one that caused the wrong-food bug: a
/// name is only ever mapped to a row *someone chose*, never to whatever a
/// FoodData Central text search happened to return.

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

  // "A or B" — take the one the curator named first, which is the one the
  // household reaches for. The pair is always close enough that the choice
  // moves one nutrient a little, never the shape of the meal.
  'oil ghee': 'Groundnut oil',
  'ghee oil': 'Ghee',
  'butter oil': 'Butter',
  'dudhi methi': 'Bottle gourd',
  'cucumber onion': 'Cucumber',
  'onion tomato': 'Onion',
  'moong chana dal': 'Moong dal, raw',
  'urad chana dal': 'Urad dal, raw',
  'vegetable tamarind': 'Mixed vegetables',
  'mixed dal': 'Toor dal, raw',
  'mixed sprouts': 'Sprouted moong',
  'moong dal soaked': 'Moong dal, raw',
  'fish': 'Fish, seer / kingfish',
  'nuts': 'Cashew',
  'milk reduced': 'Milk, cow, whole',
  'wheat extract': 'Wheat flour, atta',

  // Spice powders: 3-8 g of roasted dal, chilli and coriander. The catalog
  // already carries one ground blend, and at that mass the difference
  // between blends is noise.
  'sambar podi': 'Garam masala',
  'rasam podi': 'Garam masala',
  'saaru podi': 'Garam masala',
  'huli podi': 'Garam masala',
  'vangi bath powder': 'Garam masala',
  'bbb powder': 'Garam masala',

  // A tempering is oil with a teaspoon of seeds in it.
  'tempering': 'Groundnut oil',

  // Batters and doughs, by what they are mostly made of.
  'batter': 'Idli rice + urad batter',
  'rice-dal batter': 'Idli rice + urad batter',
  'rice-dal paste': 'Idli rice + urad batter',
  'besan-urad': 'Besan, gram flour',
  'besan-urad batter': 'Besan, gram flour',
  'besan-rice flour': 'Besan, gram flour',

  // Fillings and pastes, likewise.
  'filling': 'Palya, potato',
  'potato filling': 'Palya, potato',
  'potato vada': 'Palya, potato',
  'coconut filling': 'Coconut, fresh grated',
  'coconut-jaggery': 'Coconut, fresh grated',
  'coconut-jaggery filling': 'Coconut, fresh grated',
  'khoya-coconut filling': 'Khoya / Mawa',
  'dal filling': 'Chana dal, raw',
  'chana dal-jaggery filling': 'Chana dal, raw',
  'peanut-coconut masala': 'Peanut chutney',
  'chutney': 'Green chutney',
  'red chutney spread': 'Green chutney',
  'puliyogare paste': 'Tamarind',
  'tamarind paste': 'Tamarind',
  'sundried vathal': 'Mixed vegetables',

  // A plate of poori kizhangu is two of them. `Puri` names two identical
  // rows across state files, so this points at the one carrying `poori`.
  '2 puri': 'poori',

  // Jalebi and malpua are soaked in it; sugar is what it is made of.
  'sugar syrup': 'Sugar',
};

/// Ingredients that are water: real mass in the pot, no nutrients.
///
/// Water has to be resolvable rather than skipped, because the yield factor
/// is derived from total ingredient mass against the serving weight — a
/// dropped 60 ml of water would silently concentrate everything else.
const waterIngredients = <String>{
  'water',
  // The thin liquid poured off cooked dal. It carries a little of the dal
  // with it, but it is overwhelmingly water, and rasam and osaman are
  // mostly this.
  'toor dal water',
  'legume stock',
};
