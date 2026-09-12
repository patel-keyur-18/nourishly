/// The one place an ingredient string becomes a catalog row.
///
/// Every distinct ingredient name any recipe uses appears here exactly
/// once, mapped to a row **key** (`catalog_row_key.dart`). Nothing else
/// resolves an ingredient: a name that is not in this map is reported as a
/// curation gap, never guessed at.
///
/// ## Why every name, and not just the ambiguous ones
///
/// [CatalogIndex] used to infer a row from the name through three tiers —
/// the row's own name, then any `Also` synonym, then the segment before a
/// comma — and this map only held the leftovers that inference could not
/// settle. That inference is the reason adding a row could break a dish
/// nobody touched, in two ways:
///
/// * **Ambiguity drops a key.** Two rows claiming `butter` means neither
///   wins, the ingredient stops resolving, and `fetch_catalog` drops every
///   dish that used it. Loud, at least: it lands in `failures`.
/// * **A new row outranks an old resolution, silently.** `besan` resolved
///   through the *prefix* tier to `Besan, gram flour`. Add a pantry row
///   literally named `Besan` and the *name* tier wins instead — twenty
///   dishes recomputed from a different food, no failure, no warning,
///   still wearing a `verified` badge. Measured against the committed
///   catalog, four such rows silently retarget sixty-three references.
///
/// Both disappear once resolution stops depending on which other rows
/// exist. That is all this map is: the coupling removed rather than
/// detected.
///
/// This is the same rule catalog spec §0.3b already applied one level
/// down, when the blind FoodData Central search was deleted because
/// "batter" matched battered fish and "milk" matched milk crackers: **a
/// name maps to a row someone chose, never to whatever a search returned.**
/// Tier inference was the same guess, one level up.
///
/// ## Writing a new entry
///
/// `parse_catalog.dart --suggest` still runs the old inference and prints
/// ready-to-paste lines for anything unmapped, flagging the ambiguous ones
/// for a human. Inference helps write the map; it no longer resolves
/// anything at build time.
///
/// ## Two conventions the catalog follows, read off the source tables
///
/// * **A bare grain quantity is raw.** `Khichdi, plain` lists `Rice 45 g`
///   for a 180 g katori; 45 g of *cooked* rice could not become that. Rows
///   that mean cooked say so — `Lemon rice` lists `Rice cooked 150 g` —
///   and their quantities are two to three times larger. Hence `rice` ->
///   raw and `rice cooked` -> cooked, which the blind FDC path got wrong
///   in both directions.
/// * **The household's default cooking fat is groundnut oil**, the Tier-1
///   row in `01-common.md` §6.
///
/// An ingredient that is a real, distinct food with no row of its own gets
/// its own row in the catalog rather than a mapping to a near neighbour —
/// that is where `Pav`, `Broken wheat`, `Puffed rice`, `Hung curd`,
/// `Colocasia leaves`, `Black pepper` and `Flaxseed` came from.
///
/// Everything else is settled here with the closest sensible row. This is
/// a household tracker, not a lab: "oil/ghee" means oil, a 3 g tempering
/// is mostly oil, and a coconut filling is mostly coconut. Being 10% off
/// on 5 g of spice powder does not change anything a person would do;
/// dropping the paratha, the biryani and every filled sweet out of the
/// catalog because nobody wrote down a ratio very much does.
///
/// Keys are normalized names ([catalogKey]); the list is alphabetical, and
/// each line carries the row's display name so a diff reads without a
/// lookup.
library;

const ingredientTargets = <String, String>{
  '2 puri': '01:puri', // Puri
  'absorbed ghee': '01:ghee', // Ghee
  'absorbed oil': '01:groundnut-oil', // Groundnut oil
  'bajra flour': '01:bajra-flour', // Bajra flour
  'banana': '01:banana', // Banana
  'batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'bbb powder': '01:garam-masala', // Garam masala
  'besan': '01:besan-gram-flour', // Besan, gram flour
  'besan-rice flour': '01:besan-gram-flour', // Besan, gram flour
  'besan-urad': '01:besan-gram-flour', // Besan, gram flour
  'besan-urad batter': '01:besan-gram-flour', // Besan, gram flour
  'bottle gourd': '01:bottle-gourd', // Bottle gourd
  'brinjal': '01:brinjal', // Brinjal
  'broken wheat': '01:broken-wheat', // Broken wheat
  'butter': '01:butter', // Butter
  'butter oil': '01:butter', // Butter
  'buttermilk': '01:buttermilk', // Buttermilk
  'cabbage': '01:cabbage', // Cabbage
  'carrot': '01:carrot', // Carrot
  'cashew': '01:cashew', // Cashew
  'cauliflower': '01:cauliflower', // Cauliflower
  'chana dal': '01:chana-dal-raw', // Chana dal, raw
  'chana dal-jaggery filling': '01:chana-dal-raw', // Chana dal, raw
  'chicken': '01:chicken-curry-cut-raw', // Chicken, curry cut, raw
  'chickpeas': '01:chana-whole-kabuli', // Chana, whole (kabuli)
  'chutney': '01:green-chutney', // Green chutney
  'cluster beans': '01:cluster-beans', // Cluster beans
  'coconut': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut filling': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut milk': '01:coconut-milk', // Coconut milk
  'coconut oil': '01:coconut-oil', // Coconut oil
  'coconut-jaggery': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut-jaggery filling': '01:coconut-fresh-grated', // Coconut, fresh grated
  'colocasia leaves': '01:colocasia-leaves', // Colocasia leaves
  'coriander': '01:coriander-leaves', // Coriander leaves
  'cucumber': '01:cucumber', // Cucumber
  'cucumber onion': '01:cucumber', // Cucumber
  'curd': '01:curd-plain', // Curd, plain
  'dal filling': '01:chana-dal-raw', // Chana dal, raw
  'decoction': '01:coffee-decoction', // Coffee decoction
  'dosa': '03:dosa-plain', // Dosa, plain
  'dosa batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'dudhi': '01:bottle-gourd', // Bottle gourd
  'dudhi methi': '01:bottle-gourd', // Bottle gourd
  'egg': '01:egg-boiled', // Egg, boiled
  'fafda': '02:fafda', // Fafda
  'field beans': '01:field-beans', // Field beans
  'filling': '04:palya-potato', // Palya, potato
  'fish': '01:fish-seer-kingfish', // Fish, seer / kingfish
  'flaxseed': '01:flaxseed', // Flaxseed
  'french beans': '01:french-beans', // French beans
  'ganthiya': '02:gathiya', // Gathiya
  'garlic': '01:garlic', // Garlic
  'ghee': '01:ghee', // Ghee
  'ghee oil': '01:ghee', // Ghee
  'groundnut oil': '01:groundnut-oil', // Groundnut oil
  'huli podi': '01:garam-masala', // Garam masala
  'hung curd': '01:hung-curd', // Hung curd
  'idli batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'ivy gourd': '01:ivy-gourd', // Ivy gourd
  'jaggery': '01:jaggery', // Jaggery
  'jalebi': '02:jalebi', // Jalebi
  'jowar flour': '01:jowar-flour', // Jowar flour
  'kesari bath': '04:kesari-bath', // Kesari bath
  'khara bath': '04:khara-bath', // Khara bath
  'khoya': '01:khoya-mawa', // Khoya / Mawa
  'khoya-coconut filling': '01:khoya-mawa', // Khoya / Mawa
  'kori gassi': '04:kori-gassi', // Kori gassi
  'lemon': '01:lemon', // Lemon
  'mango pulp': '01:mango', // Mango
  'matki': '01:matki', // Matki
  'methi': '01:fenugreek-leaves', // Fenugreek leaves
  'methi greens': '01:fenugreek-leaves', // Fenugreek leaves
  'milk': '01:milk-cow-whole', // Milk, cow, whole
  'milk reduced': '01:milk-cow-whole', // Milk, cow, whole
  'mixed dal': '01:toor-dal-raw', // Toor dal, raw
  'mixed sprouts': '01:sprouted-moong', // Sprouted moong
  'mixed veg': '01:mixed-vegetables', // Mixed vegetables
  'mixed vegetables': '01:mixed-vegetables', // Mixed vegetables
  'moong chana dal': '01:moong-dal-raw', // Moong dal, raw
  'moong dal': '01:moong-dal-raw', // Moong dal, raw
  'moong dal soaked': '01:moong-dal-raw', // Moong dal, raw
  'muthiya': '02:muthiya-steamed', // Muthiya, steamed
  'neer dose': '04:neer-dose', // Neer dose
  'nuts': '01:cashew', // Cashew
  'oil': '01:groundnut-oil', // Groundnut oil
  'oil ghee': '01:groundnut-oil', // Groundnut oil
  'okra': '01:okra', // Okra
  'onion': '01:onion', // Onion
  'onion tomato': '01:onion', // Onion
  'parotta': '03:parotta', // Parotta
  'patra': '02:patra', // Patra
  'pav': '01:pav', // Pav
  'peanut-coconut masala': '01:peanut-chutney', // Peanut chutney
  'peanuts': '01:peanuts-raw', // Peanuts, raw
  'peas': '01:green-peas', // Green peas
  'pepper': '01:black-pepper', // Black pepper
  'podi': '03:idli-podi', // Idli podi
  'potato': '01:potato', // Potato
  'potato filling': '04:palya-potato', // Palya, potato
  'potato masala': '04:palya-potato', // Palya, potato
  'potato palya': '04:palya-potato', // Palya, potato
  'potato vada': '04:palya-potato', // Palya, potato
  'puffed rice': '01:puffed-rice', // Puffed rice
  'puliyogare paste': '01:tamarind', // Tamarind
  'ragi flour': '01:ragi-flour', // Ragi flour
  'rasam podi': '01:garam-masala', // Garam masala
  'rava': '01:semolina-rava', // Semolina, rava
  'raw poha': '01:poha-raw', // Poha, raw
  'red chutney spread': '01:green-chutney', // Green chutney
  'refined flour': '01:refined-flour-maida', // Refined flour, maida
  'rice': '01:rice-white-raw', // Rice, white, raw
  'rice batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice cooked': '01:rice-white-cooked', // Rice, white, cooked
  'rice flour': '01:rice-flour', // Rice flour
  'rice-dal batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice-dal paste': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice-urad batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'ridge gourd': '01:ridge-gourd', // Ridge gourd
  'saaru podi': '01:garam-masala', // Garam masala
  'salna': '03:salna', // Salna
  'sambar podi': '01:garam-masala', // Garam masala
  'sambharo': '02:sambharo', // Sambharo
  'sesame oil': '01:sesame-oil', // Sesame oil
  'sev': '02:sev-thin', // Sev, thin
  'spinach': '01:spinach', // Spinach
  'sugar': '01:sugar', // Sugar
  'sugar syrup': '01:sugar', // Sugar
  'sundried vathal': '01:mixed-vegetables', // Mixed vegetables
  'surti papdi': '01:field-beans', // Field beans
  'tamarind': '01:tamarind', // Tamarind
  'tamarind paste': '01:tamarind', // Tamarind
  'tempering': '01:groundnut-oil', // Groundnut oil
  'tempering oil': '01:groundnut-oil', // Groundnut oil
  'tomato': '01:tomato', // Tomato
  'toor dal': '01:toor-dal-raw', // Toor dal, raw
  'urad': '01:urad-dal-raw', // Urad dal, raw
  'urad chana dal': '01:urad-dal-raw', // Urad dal, raw
  'urad dal': '01:urad-dal-raw', // Urad dal, raw
  'urad flour': '01:urad-dal-raw', // Urad dal, raw
  'vangi bath powder': '01:garam-masala', // Garam masala
  'vegetable': '01:mixed-vegetables', // Mixed vegetables
  'vegetable tamarind': '01:mixed-vegetables', // Mixed vegetables
  'vegetables': '01:mixed-vegetables', // Mixed vegetables
  'vermicelli': '01:vermicelli-raw', // Vermicelli, raw
  'wheat extract': '01:wheat-flour-atta', // Wheat flour, atta
  'wheat flour': '01:wheat-flour-atta', // Wheat flour, atta
  'yam': '01:yam', // Yam
};

/// Ingredients that are water: mass with no nutrients.
///
/// They have to resolve rather than be skipped, because the yield factor
/// comes from total ingredient mass against the serving weight — dropping
/// the water would concentrate everything else in the dish.
const waterIngredients = <String>{
  'water',
  // The thin liquid poured off cooked dal. It carries a little of the dal
  // with it, but it is overwhelmingly water, and rasam and osaman are
  // mostly this.
  'toor dal water',
  'legume stock',
};
