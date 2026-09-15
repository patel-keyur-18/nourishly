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
  '2 puri': 'andhra-pradesh-food-catalog:puri', // Puri
  'absorbed ghee': '01:ghee', // Ghee
  'absorbed oil': '01:groundnut-oil', // Groundnut oil
  'ajwain': '01:cumin-seeds', // Cumin seeds — carom seed: no FDC entry, and the nearest measured seed spice at the 1 g it is used in
  'almond': '01:almonds', // Almonds
  'almonds': '01:almonds', // Almonds
  'amaranth greens': '01:amaranth-leaves', // Amaranth leaves
  'amaranth spinach': '01:amaranth-leaves', // Amaranth leaves
  'amla': '08:amla', // Amla
  'anchovies': '08:fish-anchovy', // Fish, anchovy
  'apple': '01:apple', // Apple
  'arborio rice': '01:rice-white-raw', // Rice, white, raw
  'ash gourd': '01:ash-gourd', // Ash gourd
  'baby corn':
      '08:sweet-corn', // Sweet corn — the immature ear of the same plant
  'baingan chokha': 'bihar-food-catalog:baingan-chokha', // Baingan chokha
  'bajra flour': '01:bajra-flour', // Bajra flour
  'baking powder': '08:baking-powder', // Baking powder
  'balsamic vinegar': '08:vinegar', // Vinegar
  'bamboo shoots': '08:bamboo-shoots', // Bamboo shoots
  'banana': '01:banana', // Banana
  'banana blossom': '01:raw-banana', // Raw banana — the flower of the same plant; no FDC entry of its own
  'basil': '08:basil', // Basil
  'basil seeds': '01:chia-seeds', // Chia seeds — sabja swells and eats like chia, which is the row the catalog measures
  'basmati rice': '01:rice-white-raw', // Rice, white, raw
  'batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'bay leaf': '08:bay-leaf', // Bay leaf
  'bbb powder': '01:garam-masala', // Garam masala
  'beans': '01:french-beans', // French beans
  'beef': '08:beef-raw', // Beef, raw
  'beef mince': '08:beef-raw', // Beef, raw
  'beetroot': '01:beetroot', // Beetroot
  'bell pepper': '01:capsicum', // Capsicum
  'besan': '01:besan-gram-flour', // Besan, gram flour
  'besan dumplings': '01:besan-gram-flour', // Besan, gram flour
  'besan-rice flour': '01:besan-gram-flour', // Besan, gram flour
  'besan-urad': '01:besan-gram-flour', // Besan, gram flour
  'besan-urad batter': '01:besan-gram-flour', // Besan, gram flour
  'bhaji masala': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'bhatura': 'andhra-pradesh-food-catalog:bhatura', // Bhatura
  'bhetki fish': '01:fish-pomfret', // Fish, pomfret
  'biryani masala': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'bitter gourd': '01:bitter-gourd', // Bitter gourd
  'black chickpeas': '01:chana-whole-kala', // Chana, whole (kala)
  'black chickpeas cooked': '01:chana-whole-kala', // Chana, whole (kala)
  'black gram whole': '01:urad-dal-raw', // Urad dal, raw
  'black olives': '08:olives', // Olives
  'black peas': '08:dried-peas', // Dried peas
  'black pepper': '01:black-pepper', // Black pepper
  'black salt': '01:salt', // Salt — kala namak — salt with a trace of sulphur
  'black-eyed peas': '01:chawli-lobia', // Chawli / Lobia
  'black-eyed peas cooked': '01:chawli-lobia', // Chawli / Lobia
  'bombay duck fish': '01:fish-pomfret', // Fish, pomfret
  'boondi': '02:sev-thin', // Sev, thin — fried besan droplets, the same food as sev in a different shape
  'bottle gourd': '01:bottle-gourd', // Bottle gourd
  'bottle gourd dumplings': '01:bottle-gourd', // Bottle gourd
  'bread': '01:bread-white', // Bread, white
  'bread croutons': '01:bread-white', // Bread, white
  'bread crumbs': '08:breadcrumbs', // Breadcrumbs
  'breadcrumbs': '08:breadcrumbs', // Breadcrumbs
  'brinjal': '01:brinjal', // Brinjal
  'broccoli': '08:broccoli', // Broccoli
  'broken wheat': '01:broken-wheat', // Broken wheat
  'brown rice': '08:rice-brown-raw', // Rice, brown, raw
  'bun': '01:pav', // Pav
  'burger bun': '01:pav', // Pav
  'butter': '01:butter', // Butter
  'butter oil': '01:butter', // Butter
  'buttermilk': 'andhra-pradesh-food-catalog:buttermilk', // Buttermilk
  'cabbage': '01:cabbage', // Cabbage
  'cannelloni pasta': '07:pasta-dry', // Pasta, dry
  'capsicum': '01:capsicum', // Capsicum
  'cardamom': '08:cardamom', // Cardamom
  'carrot': '01:carrot', // Carrot
  'carrot cooked': '01:carrot', // Carrot
  'cashew': '01:cashew', // Cashew
  'cashews': '01:cashew', // Cashew
  'cauliflower': '01:cauliflower', // Cauliflower
  'cauliflower cooked': '01:cauliflower', // Cauliflower
  'chana dal': '01:chana-dal-raw', // Chana dal, raw
  'chana dal cake': '01:chana-dal-raw', // Chana dal, raw
  'chana dal-jaggery filling': '01:chana-dal-raw', // Chana dal, raw
  'chana spices': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'chawli': '01:chawli-lobia', // Chawli / Lobia
  'cheddar cheese': '08:cheddar-cheese', // Cheddar cheese
  'cheese': '01:cheese-processed', // Cheese, processed
  'chhena': '01:paneer', // Paneer — chhena is paneer before it is pressed
  'chia seeds': '01:chia-seeds', // Chia seeds
  'chicken': '01:chicken-curry-cut-raw', // Chicken, curry cut, raw
  'chicken breast': '01:chicken-curry-cut-raw', // Chicken, curry cut, raw
  'chicken cooked': '08:chicken-cooked', // Chicken, cooked
  'chicken curry': 'indian-food-catalog:chicken-curry', // Chicken curry
  'chicken mince': '01:chicken-curry-cut-raw', // Chicken, curry cut, raw
  'chicken stock': '08:chicken-stock', // Chicken stock
  'chicken wings': '01:chicken-curry-cut-raw', // Chicken, curry cut, raw
  'chickpeas': '01:chana-whole-kabuli', // Chana, whole (kabuli)
  'chickpeas cooked': '08:chana-boiled', // Chana, boiled
  'chicory': '08:coffee-powder', // Coffee powder — roasted chicory, blended into filter coffee at the same quantities
  'chili': '01:green-chilli', // Green chilli
  'chili paste': '08:chilli-sauce', // Chilli sauce
  'chili powder': '01:red-chilli-powder', // Red chilli powder
  'chili sauce': '08:chilli-sauce', // Chilli sauce
  'chutney': '01:green-chutney', // Green chutney
  'chutneys': '01:green-chutney', // Green chutney
  'ciabatta bread': '01:bread-white', // Bread, white
  'cinnamon': '08:cinnamon', // Cinnamon
  'cluster beans': '01:cluster-beans', // Cluster beans
  'cocoa powder': '08:cocoa-powder', // Cocoa powder
  'coconut': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut filling': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut milk': '01:coconut-milk', // Coconut milk
  'coconut oil': '01:coconut-oil', // Coconut oil
  'coconut-jaggery': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coconut-jaggery filling': '01:coconut-fresh-grated', // Coconut, fresh grated
  'coffee': '08:coffee-powder', // Coffee powder
  'coffee decoction': '01:coffee-decoction', // Coffee decoction
  'coffee powder': '08:coffee-powder', // Coffee powder
  'colocasia': '01:colocasia', // Colocasia
  'colocasia leaf': '01:colocasia-leaves', // Colocasia leaves
  'colocasia leaves': '01:colocasia-leaves', // Colocasia leaves
  'coriander': '01:coriander-leaves', // Coriander leaves
  'coriander chutney':
      'andhra-pradesh-food-catalog:coriander-chutney', // Coriander chutney
  'coriander leaves': '01:coriander-leaves', // Coriander leaves
  'coriander seeds':
      '01:coriander-powder', // Coriander powder — the powder is the ground seed
  'corn flour': '08:corn-flour', // Corn flour
  'cornflakes': '08:cornflakes', // Cornflakes
  'cornflour': '08:corn-flour', // Corn flour
  'cornmeal': '08:maize-flour', // Maize flour
  'country chicken curry': 'indian-food-catalog:chicken-curry', // Chicken curry
  'cowpeas': '01:chawli-lobia', // Chawli / Lobia
  'crab': '08:crab', // Crab
  'cream': '01:malai-fresh-cream', // Malai / fresh cream
  'cream cheese': '08:cream-cheese', // Cream cheese
  'cucumber': '01:cucumber', // Cucumber
  'cucumber onion': '01:cucumber', // Cucumber
  'cumin': '01:cumin-seeds', // Cumin seeds
  'curd': '01:curd-plain', // Curd, plain
  'curry leaves': '08:curry-leaves', // Curry leaves
  'curry powder': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'custard': '08:custard', // Custard
  'dabeli masala': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'dal filling': '01:chana-dal-raw', // Chana dal, raw
  'dark chocolate': '08:dark-chocolate', // Dark chocolate
  'date palm jaggery': '01:jaggery', // Jaggery
  'dates': '01:dates', // Dates
  'decoction': '01:coffee-decoction', // Coffee decoction
  'dhokla': 'indian-food-catalog:dhokla', // Dhokla
  'digestive biscuits': '08:biscuits-digestive', // Biscuits, digestive
  'dosa': '03:dosa-plain', // Dosa, plain
  'dosa batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'dried apricots': '08:dried-apricots', // Dried apricots
  'dried chili': '08:dried-red-chilli', // Dried red chilli
  'dried peas cooked': '08:dried-peas', // Dried peas
  'dried red chili': '08:dried-red-chilli', // Dried red chilli
  'dried vegetables': '01:mixed-vegetables', // Mixed vegetables — sundried vathal, as elsewhere in this map
  'dried yellow peas': '08:dried-peas', // Dried peas
  'drumstick': '01:drumstick', // Drumstick
  'drumstick leaves': '08:drumstick-leaves', // Drumstick leaves
  'duck': '08:duck', // Duck
  'dudhi': '01:bottle-gourd', // Bottle gourd
  'dudhi methi': '01:bottle-gourd', // Bottle gourd
  'edible gum': '08:edible-gum', // Edible gum
  'egg': '01:egg-boiled', // Egg, boiled
  'egg boiled': '01:egg-boiled', // Egg, boiled
  'egg yolk': '01:egg-boiled', // Egg, boiled
  'eggplant': '01:brinjal', // Brinjal
  'elephant yam': '01:yam', // Yam
  'eno': '08:baking-soda', // Baking soda — fruit salt is sodium bicarbonate with an acid
  'fafda': 'indian-food-catalog:fafda', // Fafda
  'farsan': '02:sev-thin', // Sev, thin
  'fennel': '08:fennel-seeds', // Fennel seeds
  'fenugreek': '08:fenugreek-seeds', // Fenugreek seeds
  'fenugreek dumpling': '02:muthiya-steamed', // Muthiya, steamed
  'fenugreek leaves': '01:fenugreek-leaves', // Fenugreek leaves
  'fenugreek seeds': '08:fenugreek-seeds', // Fenugreek seeds
  'field beans': '01:field-beans', // Field beans
  'filling': '04:palya-potato', // Palya, potato
  'fish': '01:fish-seer-kingfish', // Fish, seer / kingfish
  'fish curry': 'indian-food-catalog:fish-curry', // Fish curry
  'fish head': '01:fish-seer-kingfish', // Fish, seer / kingfish
  'flattened rice': '01:poha-raw', // Poha, raw
  'flaxseed': '01:flaxseed', // Flaxseed
  'fox nuts': '08:fox-nuts', // Fox nuts
  'french beans': '01:french-beans', // French beans
  'fresh coconut': '01:coconut-fresh-grated', // Coconut, fresh grated
  'fresh mozzarella': '08:mozzarella-cheese', // Mozzarella cheese
  'fresh pigeon peas': '08:tuvar-lilva', // Tuvar lilva
  'fresh turmeric': '01:turmeric', // Turmeric
  'fried garlic': '01:garlic', // Garlic
  'fried noodles': '07:pasta-dry', // Pasta, dry
  'fruit jam': '08:jam', // Jam
  'full-fat milk': '01:milk-cow-whole', // Milk, cow, whole
  'ganthiya': 'gujarat-food-catalog:gathiya', // Gathiya
  'garam masala': '01:garam-masala', // Garam masala
  'garlic': '01:garlic', // Garlic
  'garlic chutney': 'gujarat-food-catalog:lasaniya-chutney', // Lasaniya chutney
  'gelatin': '08:gelatin', // Gelatin
  'ghee': '01:ghee', // Ghee
  'ghee oil': '01:ghee', // Ghee
  'ginger': '01:ginger', // Ginger
  'goat brain': '01:mutton-raw', // Mutton, raw
  'goat head meat': '01:mutton-raw', // Mutton, raw
  'goat intestine': '01:mutton-raw', // Mutton, raw
  'goat liver': '08:goat-liver', // Goat liver
  'goat trotters': '01:mutton-raw', // Mutton, raw
  'gobindobhog rice': '01:rice-white-raw', // Rice, white, raw
  'goda masala': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'gondhoraj lime': '01:lemon', // Lemon
  'gongura leaves': '08:gongura-leaves', // Gongura leaves
  'gouda cheese': '08:cheddar-cheese', // Cheddar cheese — a hard cheese used once, at cheddar's composition
  'gram flour': '01:besan-gram-flour', // Besan, gram flour
  'gram flour batter': '01:besan-gram-flour', // Besan, gram flour
  'grated carrot': '01:carrot', // Carrot
  'grated coconut': '01:coconut-fresh-grated', // Coconut, fresh grated
  'green beans': '01:french-beans', // French beans
  'green chickpeas': '01:chana-whole-kabuli', // Chana, whole (kabuli)
  'green chili': '01:green-chilli', // Green chilli
  'green gram': '01:green-moong-whole', // Green moong, whole
  'green peas': '01:green-peas', // Green peas
  'ground rice': '01:rice-flour', // Rice flour
  'groundnut oil': '01:groundnut-oil', // Groundnut oil
  'hilsa fish': '08:fish-hilsa', // Fish, hilsa
  'honey': '01:honey', // Honey
  'horse gram': '01:chana-whole-kala', // Chana, whole (kala) — kulthi has no FDC entry; kala chana is the nearest whole pulse the catalog measures
  'huli podi': '01:garam-masala', // Garam masala
  'hung curd': '01:hung-curd', // Hung curd
  'hung yogurt': '01:hung-curd', // Hung curd
  'hyacinth beans':
      '01:field-beans', // Field beans — valor / avarekai is the hyacinth bean
  'idli': 'indian-food-catalog:idli', // Idli
  'idli batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'idli dosa batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'idli rice': '01:rice-white-raw', // Rice, white, raw — the raw grain; the cooked parboiled row is a separate food
  'italian bread': '01:bread-white', // Bread, white
  'ivy gourd': '01:ivy-gourd', // Ivy gourd
  'jaggery': '01:jaggery', // Jaggery
  'jalapeno': '01:green-chilli', // Green chilli
  'jalebi': 'indian-food-catalog:jalebi', // Jalebi
  'jelly': '08:jam', // Jam
  'jowar bhakri': 'indian-food-catalog:jowar-bhakri', // Jowar bhakri
  'jowar flour': '01:jowar-flour', // Jowar flour
  'kabuli chana': '01:chana-whole-kabuli', // Chana, whole (kabuli) — the white chickpea, not the brown `kala` row beside it
  'kachampuli': '01:tamarind', // Tamarind — the Coorg souring vinegar, as above
  'kachori': 'indian-food-catalog:kachori', // Kachori
  'kachri': '01:cucumber', // Cucumber — a desert melon with no FDC entry, at cucumber's composition
  'kadai spices': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'kashmiri chili': '01:red-chilli-powder', // Red chilli powder
  'ker': '01:cluster-beans', // Cluster beans — a dried desert berry with no FDC entry; cluster beans is the nearest dried pod the catalog measures
  'kesari bath':
      'karnataka-tamilnadu-gujarat-food-catalog:kesari-bath', // Kesari bath
  'khandvi': 'indian-food-catalog:khandvi', // Khandvi
  'khara bath':
      'karnataka-tamilnadu-gujarat-food-catalog:khara-bath', // Khara bath
  'khoya': '01:khoya-mawa', // Khoya / Mawa
  'khoya-coconut filling': '01:khoya-mawa', // Khoya / Mawa
  'kidney beans': '01:rajma', // Rajma
  'kidney beans cooked': '01:rajma', // Rajma
  'kokum': '01:tamarind', // Tamarind — a souring agent with no FDC entry, used at tamarind's quantities
  'kori gassi': '04:kori-gassi', // Kori gassi
  'kundapura spice blend': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'ladyfinger biscuits': '08:sponge-cake', // Sponge cake
  'ladyfish': '01:fish-sardine', // Fish, sardine
  'lamb mince': '01:mutton-raw', // Mutton, raw
  'large green chili': '01:green-chilli', // Green chilli
  'lasagna sheets': '07:pasta-dry', // Pasta, dry
  'lemon': '01:lemon', // Lemon
  'lemon juice': '01:lemon', // Lemon
  'lettuce': '08:lettuce', // Lettuce
  'lime': '01:lemon', // Lemon
  'lime juice': '01:lemon', // Lemon
  'litti': 'bihar-food-catalog:litti', // Litti
  'macaroni': '07:pasta-dry', // Pasta, dry
  'mackerel': '08:fish-mackerel', // Fish, mackerel
  'maize flour': '08:maize-flour', // Maize flour
  'malabar spinach': '01:spinach', // Spinach
  'mango': '01:mango', // Mango
  'mango pulp': '01:mango', // Mango
  'mascarpone cheese': '08:cream-cheese', // Cream cheese
  'masoor dal': '01:masoor-dal-raw', // Masoor dal, raw
  'matki': '01:matki', // Matki
  'matki sprouts curry': 'indian-food-catalog:matki-usal', // Matki usal
  'mawa': '01:khoya-mawa', // Khoya / Mawa
  'mayonnaise': '08:mayonnaise', // Mayonnaise
  'methi': '01:fenugreek-leaves', // Fenugreek leaves
  'methi greens': '01:fenugreek-leaves', // Fenugreek leaves
  'methi leaves': '01:fenugreek-leaves', // Fenugreek leaves
  'milk': '01:milk-cow-whole', // Milk, cow, whole
  'milk powder': '08:milk-powder', // Milk powder
  'milk reduced': '01:milk-cow-whole', // Milk, cow, whole
  'milk solids': '01:khoya-mawa', // Khoya / Mawa
  'milk solids khoya': '01:khoya-mawa', // Khoya / Mawa
  'millet pasta': '07:millet-pasta-dry', // Millet pasta, dry — a dish's ingredient list means the dry pasta that goes in the pot, never the cooked dish of the same name
  'millet vermicelli': '07:millet-vermicelli-raw', // Millet vermicelli, raw
  'minced beef': '08:beef-raw', // Beef, raw
  'minced mutton': '01:mutton-raw', // Mutton, raw
  'mint': '01:mint-leaves', // Mint leaves
  'mint chutney': 'indian-food-catalog:mint-chutney', // Mint chutney
  'mint leaves': '01:mint-leaves', // Mint leaves
  'mixed dal': '01:toor-dal-raw', // Toor dal, raw
  'mixed dals': '01:toor-dal-raw', // Toor dal, raw
  'mixed fruit': '08:mixed-fruit', // Mixed fruit
  'mixed greens': '01:spinach', // Spinach
  'mixed herbs': '08:mixed-herbs', // Mixed herbs
  'mixed nuts': '01:cashew', // Cashew
  'mixed sprouts': '01:sprouted-moong', // Sprouted moong
  'mixed veg': '01:mixed-vegetables', // Mixed vegetables
  'mixed vegetables': '01:mixed-vegetables', // Mixed vegetables
  'mola fish': '01:fish-sardine', // Fish, sardine
  'moong chana dal': '01:moong-dal-raw', // Moong dal, raw
  'moong dal': '01:moong-dal-raw', // Moong dal, raw
  'moong dal soaked': '01:moong-dal-raw', // Moong dal, raw
  'moth bean flour': '01:matki', // Matki
  'moth beans': '01:matki', // Matki
  'mozzarella cheese': '08:mozzarella-cheese', // Mozzarella cheese
  'muesli': '08:muesli', // Muesli
  'multigrain flour': '01:wheat-flour-atta', // Wheat flour, atta
  'murrel fish': '01:fish-seer-kingfish', // Fish, seer / kingfish
  'mushroom': '01:mushroom', // Mushroom
  'mussels': '08:mussels', // Mussels
  'mustard': '01:mustard-seeds', // Mustard seeds
  'mustard greens': '08:mustard-greens', // Mustard greens
  'mustard oil': '01:mustard-oil', // Mustard oil
  'mustard paste': '01:mustard-seeds', // Mustard seeds
  'mustard seeds': '01:mustard-seeds', // Mustard seeds
  'muthiya': '02:muthiya-steamed', // Muthiya, steamed
  'mutton': '01:mutton-raw', // Mutton, raw
  'mutton mince': '01:mutton-raw', // Mutton, raw
  'mysore rasam powder': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'neer dose': '04:neer-dose', // Neer dose
  'nigella seeds': '01:cumin-seeds', // Cumin seeds — kalonji: as above
  'nutmeg': '08:nutmeg', // Nutmeg
  'nuts': '01:cashew', // Cashew
  'oats': '01:oats-rolled', // Oats, rolled
  'oil': '01:groundnut-oil', // Groundnut oil
  'oil absorbed': '01:groundnut-oil', // Groundnut oil
  'oil ghee': '01:groundnut-oil', // Groundnut oil
  'okra': '01:okra', // Okra
  'olive oil': '08:olive-oil', // Olive oil
  'onion': '01:onion', // Onion
  'onion pakora': 'andhra-pradesh-food-catalog:onion-pakora', // Onion pakora
  'onion tomato': '01:onion', // Onion
  'oyster sauce': '08:soy-sauce', // Soy sauce
  'paneer': '01:paneer', // Paneer
  'papaya': '01:papaya', // Papaya
  'papdi': 'karnataka-tamilnadu-gujarat-food-catalog:papdi', // Papdi
  'paprika': '01:red-chilli-powder', // Red chilli powder
  'paratha': '01:paratha-plain', // Paratha, plain — a wrap is rolled in a plain paratha, not a stuffed one
  'parmesan cheese': '08:parmesan-cheese', // Parmesan cheese
  'parotta': 'karnataka-tamilnadu-gujarat-food-catalog:parotta', // Parotta
  'parsley': '08:parsley', // Parsley
  'pasta': '07:pasta-dry', // Pasta, dry
  'pasta cooked': '08:pasta-cooked', // Pasta, cooked
  'patra': 'indian-food-catalog:patra', // Patra
  'pav': '01:pav', // Pav
  'pav 1 piece': '01:pav', // Pav
  'peanut': '01:peanuts-raw', // Peanuts, raw
  'peanut powder': '01:peanuts-raw', // Peanuts, raw
  'peanut-coconut masala': '01:peanut-chutney', // Peanut chutney
  'peanuts': '01:peanuts-raw', // Peanuts, raw
  'peanuts cooked': '01:peanuts-raw', // Peanuts, raw
  'pearl millet': '01:bajra-flour', // Bajra flour
  'pearl millet flour': '01:bajra-flour', // Bajra flour
  'pearl spot fish': '01:fish-pomfret', // Fish, pomfret
  'peas': '01:green-peas', // Green peas
  'peas cooked': '01:green-peas', // Green peas
  'penne pasta': '07:pasta-dry', // Pasta, dry
  'pepper': '01:black-pepper', // Black pepper
  'pepperoni': '08:pepperoni', // Pepperoni
  'pesto': '08:pesto', // Pesto
  'pickle masala': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'pineapple': '08:pineapple', // Pineapple
  'pistachio': '01:pistachio', // Pistachio
  'podi': 'karnataka-tamilnadu-gujarat-food-catalog:idli-podi', // Idli podi
  'poha': '01:poha-raw', // Poha, raw
  'pointed gourd': '01:ivy-gourd', // Ivy gourd — parwal has no FDC entry; ivy gourd is the same kind of small gourd, within a few kcal
  'pomegranate': '01:pomegranate', // Pomegranate
  'poppy seed paste': '08:poppy-seeds', // Poppy seeds
  'poppy seeds': '08:poppy-seeds', // Poppy seeds
  'pork': '08:pork', // Pork
  'potato': '01:potato', // Potato
  'potato cooked': '08:potato-boiled', // Potato, boiled
  'potato curry': '04:palya-potato', // Palya, potato
  'potato filling': '04:palya-potato', // Palya, potato
  'potato masala': '04:palya-potato', // Palya, potato
  'potato palya': '04:palya-potato', // Palya, potato
  'potato patty': '04:palya-potato', // Palya, potato
  'potato vada': '04:palya-potato', // Palya, potato
  'powdered sugar': '01:sugar', // Sugar
  'prawns': '01:prawns', // Prawns
  'puffed rice': '01:puffed-rice', // Puffed rice
  'puliyogare paste': '01:tamarind', // Tamarind
  'pumpkin': '01:pumpkin', // Pumpkin
  'pumpkin seeds': '01:pumpkin-seeds', // Pumpkin seeds
  'puri': 'andhra-pradesh-food-catalog:puri', // Puri
  'purple yam': '01:yam', // Yam
  'radish': '01:radish', // Radish
  'ragi flour': '01:ragi-flour', // Ragi flour
  'ragi mudda':
      'karnataka-tamilnadu-gujarat-food-catalog:ragi-mudde', // Ragi mudde
  'raisin': '01:raisins', // Raisins
  'raisins': '01:raisins', // Raisins
  'rasam podi': '01:garam-masala', // Garam masala
  'rasam powder': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'rava': '01:semolina-rava', // Semolina, rava
  'raw banana': '01:raw-banana', // Raw banana
  'raw jackfruit': '01:jackfruit', // Jackfruit
  'raw mango': '01:raw-mango', // Raw mango
  'raw papaya': '01:papaya', // Papaya
  'raw poha': '01:poha-raw', // Poha, raw
  'red chili': '08:dried-red-chilli', // Dried red chilli
  'red chili flakes': '01:red-chilli-powder', // Red chilli powder
  'red chutney':
      'karnataka-tamilnadu-gujarat-food-catalog:kara-chutney', // Kara chutney
  'red chutney spread': '01:green-chutney', // Green chutney
  'refined flour': '01:refined-flour-maida', // Refined flour, maida
  'refined flour roti': '01:refined-flour-maida', // Refined flour, maida
  'refined wheat flour': '01:refined-flour-maida', // Refined flour, maida
  'rice': '01:rice-white-raw', // Rice, white, raw
  'rice ada': '01:rice-flour', // Rice flour — rice-flour sheets
  'rice batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice cooked': '01:rice-white-cooked', // Rice, white, cooked
  'rice dumplings': '04:pundi', // Pundi
  'rice flour': '01:rice-flour', // Rice flour
  'rice noodles': '08:rice-noodles', // Rice noodles
  'rice starch':
      '08:corn-flour', // Corn flour — the thickener, not the cooking water
  'rice vade': '01:rice-flour', // Rice flour
  'rice-dal batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice-dal paste': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'rice-urad batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'ricotta cheese': '08:ricotta-cheese', // Ricotta cheese
  'ridge gourd': '01:ridge-gourd', // Ridge gourd
  'ripe banana': '01:banana', // Banana
  'ripe plantain': '01:banana', // Banana
  'risotto rice cooked': '01:rice-white-cooked', // Rice, white, cooked
  'roasted bengal gram': '01:chana-dal-raw', // Chana dal, raw
  'roasted chana dal': '01:chana-dal-raw', // Chana dal, raw
  'roasted chickpeas': '01:chana-dal-raw', // Chana dal, raw
  'roasted coconut': '01:coconut-fresh-grated', // Coconut, fresh grated
  'roasted cumin': '01:cumin-seeds', // Cumin seeds
  'roasted gram flour': '01:besan-gram-flour', // Besan, gram flour
  'roasted spices': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'rohu fish': '08:fish-rohu', // Fish, rohu
  'rolled oats': '01:oats-rolled', // Oats, rolled
  'rosemary': '08:mixed-herbs', // Mixed herbs
  'rotti': 'karnataka-tamilnadu-gujarat-food-catalog:akki-rotti', // Akki rotti
  'saaru podi': '01:garam-masala', // Garam masala
  'sabudana': '08:sago', // Sago
  'saffron': '08:saffron', // Saffron
  'sago': '08:sago', // Sago
  'salna': '03:salna', // Salna
  'salt': '01:salt', // Salt
  'sambar': 'indian-food-catalog:sambar', // Sambar
  'sambar podi': '01:garam-masala', // Garam masala
  'sambar powder': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'sambar spice': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'sambharo': '02:sambharo', // Sambharo
  'sangri':
      '01:cluster-beans', // Cluster beans — the dried khejri pod, as above
  'sattu': '01:besan-gram-flour', // Besan, gram flour — roasted chana flour
  'sauces': '08:tomato-sauce', // Tomato sauce
  'schezwan sauce': '08:chilli-sauce', // Chilli sauce
  'seer fish': '01:fish-seer-kingfish', // Fish, seer / kingfish
  'semolina': '01:semolina-rava', // Semolina, rava
  'semolina upma': 'andhra-pradesh-food-catalog:upma', // Upma
  'sesame': '01:sesame-seeds', // Sesame seeds
  'sesame oil': '01:sesame-oil', // Sesame oil
  'sesame seeds': '01:sesame-seeds', // Sesame seeds
  'sev': '02:sev-thin', // Sev, thin
  'shallots': '08:shallots', // Shallots
  'small eggplant': '01:brinjal', // Brinjal
  'small fish': '01:fish-sardine', // Fish, sardine
  'sorghum flour': '01:jowar-flour', // Jowar flour
  'sour curd': '01:curd-plain', // Curd, plain
  'soy sauce': '08:soy-sauce', // Soy sauce
  'soya chunks': '08:soya-chunks', // Soya chunks
  'spaghetti': '07:pasta-dry', // Pasta, dry
  'spice mix': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'spice powder': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'spices': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'spinach': '01:spinach', // Spinach
  'sponge cake': '08:sponge-cake', // Sponge cake
  'sponge gourd': '01:ridge-gourd', // Ridge gourd
  'spring onion': '08:spring-onion', // Spring onion
  'spring roll wrappers': '01:refined-flour-maida', // Refined flour, maida
  'sprouted moth beans': '01:matki', // Matki
  'sugar': '01:sugar', // Sugar
  'sugar syrup': '01:sugar', // Sugar
  'sundried vathal': '01:mixed-vegetables', // Mixed vegetables
  'sunflower seeds': '01:sunflower-seeds', // Sunflower seeds
  'surti papdi': '01:field-beans', // Field beans
  'sweet corn': '08:sweet-corn', // Sweet corn
  'sweet corn cooked': '08:sweet-corn', // Sweet corn
  'sweet potato': '01:sweet-potato', // Sweet potato
  'tamarind': '01:tamarind', // Tamarind
  'tamarind chutney':
      'indian-food-catalog:tamarind-chutney', // Tamarind chutney
  'tamarind leaves': '01:tamarind', // Tamarind
  'tamarind paste': '01:tamarind', // Tamarind
  'tamarind pulp': '01:tamarind', // Tamarind
  'tapioca cooked': '08:tapioca-root', // Tapioca root
  'taro leaves': '01:colocasia-leaves', // Colocasia leaves
  'tea infusion': '08:tea-leaves', // Tea leaves
  'tea leaves': '08:tea-leaves', // Tea leaves
  'tempering': '01:groundnut-oil', // Groundnut oil
  'tempering oil': '01:groundnut-oil', // Groundnut oil
  'tender coconut': '01:coconut-water', // Coconut water
  'tikka seasoning': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'tofu': '08:tofu', // Tofu
  'tomato': '01:tomato', // Tomato
  'tomato pesto': '08:pesto', // Pesto
  'tomato puree': '08:tomato-puree', // Tomato puree
  'tomato sauce': '08:tomato-sauce', // Tomato sauce
  'toor dal': '01:toor-dal-raw', // Toor dal, raw
  'toor dal cooked': '08:toor-dal-cooked', // Toor dal, cooked
  'tuna canned drained': '08:tuna-canned', // Tuna, canned
  'turmeric': '01:turmeric', // Turmeric
  'tuvar lilva': '08:tuvar-lilva', // Tuvar lilva
  'urad': '01:urad-dal-raw', // Urad dal, raw
  'urad chana dal': '01:urad-dal-raw', // Urad dal, raw
  'urad dal': '01:urad-dal-raw', // Urad dal, raw
  'urad dal batter': '01:idli-rice-urad-batter', // Idli rice + urad batter
  'urad dal flour': '01:urad-dal-raw', // Urad dal, raw
  'urad dal papad': '01:urad-dal-raw', // Urad dal, raw
  'urad dal vada': 'indian-food-catalog:medu-vada', // Medu vada
  'urad flour': '01:urad-dal-raw', // Urad dal, raw
  'vangi bath powder': '01:garam-masala', // Garam masala
  'vanilla': '08:vanilla-essence', // Vanilla essence
  'vegetable': '01:mixed-vegetables', // Mixed vegetables
  'vegetable manchurian balls': 'common-international-food-catalog:vegetable-manchurian-dry', // Vegetable Manchurian dry
  'vegetable salna': '03:salna', // Salna
  'vegetable stock': '08:vegetable-stock', // Vegetable stock
  'vegetable tamarind': '01:mixed-vegetables', // Mixed vegetables
  'vegetables': '01:mixed-vegetables', // Mixed vegetables
  'vermicelli': '01:vermicelli-raw', // Vermicelli, raw
  'vinegar': '08:vinegar', // Vinegar
  'watermelon seeds': '01:watermelon-seeds', // Watermelon seeds
  'wheat extract': '01:wheat-flour-atta', // Wheat flour, atta
  'wheat flour': '01:wheat-flour-atta', // Wheat flour, atta
  'wheat milk': '01:wheat-flour-atta', // Wheat flour, atta — the starch pressed from soaked wheat, as 'wheat extract' elsewhere in this map
  'wheat noodles': '07:pasta-dry', // Pasta, dry
  'wheat noodles cooked': '08:pasta-cooked', // Pasta, cooked
  'whipped cream': '01:malai-fresh-cream', // Malai / fresh cream
  'white beans cooked': '01:rajma', // Rajma
  'white bread': '01:bread-white', // Bread, white
  'white fish': '01:fish-pomfret', // Fish, pomfret
  'white peas cooked': '08:dried-peas', // Dried peas
  'whole masoor': '01:masoor-dal-raw', // Masoor dal, raw
  'whole moong': '01:green-moong-whole', // Green moong, whole
  'whole spices': '01:garam-masala', // Garam masala — one of the catalog's named blends; garam masala is its measured mixed-spice row
  'whole wheat dhokli': '01:wheat-flour-atta', // Wheat flour, atta
  'whole wheat flour': '01:wheat-flour-atta', // Wheat flour, atta
  'wood apple pulp': '01:custard-apple', // Custard apple — bel has no FDC entry; the nearest pulpy tropical fruit the catalog measures
  'yam': '01:yam', // Yam
  'yeast': '08:yeast', // Yeast
  'yellow cucumber': '01:cucumber', // Cucumber
  'yogurt': '01:curd-plain', // Curd, plain
  'zucchini': '08:zucchini', // Zucchini
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
  // Added with the regional CSVs. Pani puri's spiced water, the
  // starch water a dal or a pan of pasta is finished with, and the ice
  // in a cold coffee are all mass the yield factor has to see.
  'chana dal stock',
  'cooked dal water',
  'ice',
  'pasta cooking water',
  'spiced water',
};
