# Regional Pantry

*[Catalog index](./README.md) · 105 items · Read [§0.2–0.3](./README.md) before using the gram weights*

Ingredient rows the regional CSV catalogs need and the earlier files did not have. Every row here is a **direct USDA lookup** — a food, not a dish — because that is the only thing a recipe can be summed from (§0.2).

These rows exist because `app/assets/regional_food/*.csv` names them. A regional dish that lists `Curry leaves 2 g` cannot resolve to anything unless curry leaves is a row, and mapping it to a near neighbour instead would put a number in the app that nobody measured. Where an ingredient genuinely has no FoodData Central entry — kokum, ker, ajwain — it is settled in `ingredient_targets.dart` against the closest row the catalog already measures, with the reason on the line. It does not get an invented row here.

Serving weights are the raw-ingredient convention of `01-common.md`: 100 g for a pantry item, a katori for the few rows that are already cooked.

---

## 1. Spices and aromatics

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Cardamom | elaichi, elakkai, yelakki | 100 g | 100 | USDA #170919 spices cardamom |
| Cinnamon | dalchini, lavanga pattai, chakke | 100 g | 100 | USDA #171320 spices cinnamon ground |
| Bay leaf | tej patta, biryani leaf | 100 g | 100 | USDA #170917 spices bay leaf |
| Nutmeg | jaiphal, jathikai | 100 g | 100 | USDA #171326 spices nutmeg ground |
| Saffron | kesar, kunkuma puvvu | 100 g | 100 | USDA #170934 spices saffron |
| Fennel seeds | saunf, sombu, badishep | 100 g | 100 | USDA #171323 spices fennel seed |
| Fenugreek seeds | methi dana, venthayam, menthe | 100 g | 100 | USDA #171324 spices fenugreek seed |
| Poppy seeds | khus khus, gasagase, kasakasa | 100 g | 100 | USDA #171330 spices poppy seed |
| Dried red chilli | sukhi lal mirch, vatha milagai, byadgi chilli | 100 g | 100 | USDA #170106 peppers hot chili red dried |
| Curry leaves | kadi patta, karuveppilai, kari bevu | 100 g | 100 | USDA #169997 coriander cilantro leaves raw — FDC has no curry leaf; `curry leaves` returned drumstick leaves, and cilantro is the nearest measured fresh aromatic leaf |
| Mixed herbs | italian seasoning, oregano | 100 g | 100 | USDA #171328 spices oregano dried |
| Basil | tulsi, sweet basil | 100 g | 100 | USDA #172232 basil fresh |
| Parsley | — | 100 g | 100 | USDA #170416 parsley fresh |

---

## 2. Vegetables, greens and fruit

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Spring onion | scallion, green onion, hara pyaz | 100 g | 100 | USDA #170005 onions spring or scallions raw |
| Shallots | sambar onion, small onion, chinna vengayam | 100 g | 100 | USDA #170499 shallots raw |
| Lettuce | salad leaves | 100 g | 100 | USDA #2346388 lettuce iceberg raw |
| Zucchini | courgette | 100 g | 100 | USDA #168565 squash zucchini raw |
| Broccoli | — | 100 g | 100 | USDA #747447 broccoli raw |
| Sweet corn | corn kernels, makai | 100 g | 100 | USDA #169998 corn sweet yellow raw |
| Mustard greens | sarson, rai ka saag | 100 g | 100 | USDA #169256 mustard greens raw |
| Drumstick leaves | moringa leaves, murungai keerai, nugge soppu | 100 g | 100 | USDA #168416 drumstick leaves raw |
| Gongura leaves | roselle leaves, ambadi, pulicha keerai | 100 g | 100 | USDA #168170 roselle raw |
| Bamboo shoots | — | 100 g | 100 | USDA #169210 bamboo shoots raw |
| Tapioca root | kappa, cassava, maravalli kizhangu | 100 g | 100 | USDA #169985 cassava raw |
| Potato, boiled | boiled potato | 100 g | 100 | USDA #170439 potatoes boiled cooked without skin |
| Pineapple | ananas | 100 g | 100 | USDA #2346398 pineapple raw |
| Amla | indian gooseberry, nellikai, usirikaya | 100 g | 100 | USDA #173030 gooseberries raw |
| Dried apricots | khubani | 100 g | 100 | USDA #173941 apricots dried |
| Mixed fruit | fruit salad | 100 g | 100 | USDA #174668 fruit cocktail peach pineapple pear grape canned juice pack |
| Olives | black olives | 100 g | 100 | USDA #169095 olives ripe canned |
| Tomato puree | tomato paste, passata | 100 g | 100 | USDA #2685582 tomato puree canned |
| Avocado | makhanphal, butter fruit | 100 g | 100 | USDA #171705 avocados raw all commercial varieties |
| Strawberry | — | 100 g | 100 | USDA #167762 strawberries raw |
| Cherries | — | 100 g | 100 | USDA #171719 cherries sweet raw |

---

## 3. Pulses, grains and flours

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Dried peas | white peas, safed vatana, dried yellow peas | 100 g | 100 | USDA #172428 peas split mature seeds raw |
| Tuvar lilva | fresh pigeon peas, tuver lilva | 100 g | 100 | USDA #172436 pigeon peas immature seeds raw |
| Toor dal, cooked | cooked tuvar dal, cooked arhar dal | 1 katori | 150 | USDA #172472 pigeon peas cooked |
| Chana, boiled | boiled chickpeas, cooked chana | 1 katori | 150 | USDA #173799 chickpeas cooked |
| Fox nuts | makhana, phool makhana, lotus seeds | 100 g | 100 | USDA #170149 lotus seeds dried |
| Maize flour | makai no lot, cornmeal | 100 g | 100 | USDA #170290 corn flour whole grain yellow |
| Corn flour | cornflour, corn starch | 100 g | 100 | USDA #169698 cornstarch |
| Rice, brown, raw | brown rice | 100 g | 100 | USDA #2512380 rice brown long-grain raw |
| Rice noodles | rice sticks, rice vermicelli | 100 g | 100 | USDA #169742 rice noodles dry |
| Pasta, cooked | boiled pasta, cooked noodles | 1 katori | 150 | USDA #169751 pasta cooked |
| Sago | sabudana, javvarisi, sabakki | 100 g | 100 | USDA #169717 tapioca pearl dry |
| Breadcrumbs | bread crumbs | 100 g | 100 | USDA #174928 bread crumbs dry grated |
| Cornflakes | corn flakes | 30 g | 30 | USDA #174648 cereals ready-to-eat corn flakes |
| Muesli | — | 40 g | 40 | USDA #169075 cereals ready-to-eat muesli |
| Soya chunks | soy nuggets, meal maker | 100 g | 100 | USDA #174301 soy protein concentrate |
| Tofu | soya paneer, bean curd | 100 g | 100 | USDA #172475 tofu raw firm |
| Millet, raw | barnyard millet, foxtail millet, little millet, samai, kangni, sama | 100 g | 100 | USDA #169702 millet raw — FDC measures one millet, not the barnyard/foxtail/little varieties the CSVs name separately |
| Millet, cooked | cooked millet | 1 katori | 150 | USDA #168871 millet cooked |
| Quinoa, raw | — | 100 g | 100 | USDA #168874 quinoa uncooked |
| Quinoa, cooked | — | 1 katori | 150 | USDA #168917 quinoa cooked |
| Bread, whole wheat | brown bread, atta bread, multigrain bread | 100 g | 100 | USDA #172688 bread whole-wheat commercially prepared |
| Instant noodles, dry | maggi, instant masala noodles, cup noodles | 100 g | 100 | USDA #168905 noodles chinese chow mein — FDC publishes no instant noodle cake; `noodles instant dry` returned *rice* noodles, a different grain and almost no fat, and chow mein is the fried wheat noodle this actually is |
| Taco shells | corn taco shells | 100 g | 100 | USDA #172800 taco shells baked |
| Tortilla, wheat | wheat tortilla, flour tortilla, roti wrap | 100 g | 100 | USDA #174081 tortillas ready-to-bake or -fry whole wheat — the refined-flour tortilla FDC publishes (2758996) carries no proximates, so the whole-wheat one is the only measured wheat tortilla |

---

## 4. Dairy and cheese

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Cheddar cheese | cheddar | 100 g | 100 | USDA #328637 cheese cheddar |
| Mozzarella cheese | mozzarella, pizza cheese | 100 g | 100 | USDA #170845 cheese mozzarella whole milk |
| Parmesan cheese | parmesan, parmigiano | 100 g | 100 | USDA #171247 cheese parmesan grated |
| Ricotta cheese | ricotta | 100 g | 100 | USDA #746766 cheese ricotta whole milk |
| Cream cheese | — | 100 g | 100 | USDA #173418 cheese cream |
| Milk powder | skimmed milk powder, dairy whitener | 100 g | 100 | USDA #170876 milk dry whole |

---

## 5. Meat, fish and seafood

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Chicken, cooked | cooked chicken, roast chicken | 100 g | 100 | USDA #171477 chicken broilers or fryers breast meat only roasted — `chicken breast roasted` returned a deli roll |
| Pork | — | 100 g | 100 | USDA #168312 pork fresh loin raw |
| Beef, raw | beef mince, minced beef | 100 g | 100 | USDA #168608 beef ground raw |
| Duck | — | 100 g | 100 | USDA #172408 duck meat raw |
| Goat liver | kaleji, mutton liver | 100 g | 100 | USDA #172531 lamb variety meats liver raw |
| Fish, rohu | rui, rohu, carp | 100 g | 100 | USDA #171952 fish carp raw |
| Fish, mackerel | bangda, ayala, aiyla | 100 g | 100 | USDA #175119 fish mackerel raw |
| Fish, hilsa | ilish, palla | 100 g | 100 | USDA #173696 fish shad american raw |
| Fish, anchovy | nethili, kozhuva, anchovies | 100 g | 100 | USDA #174182 fish anchovy raw |
| Tuna, canned | canned tuna | 100 g | 100 | USDA #334194 fish tuna light canned in water drained |
| Crab | njandu, nandu, kekda | 100 g | 100 | USDA #174204 crab blue raw |
| Mussels | kadukka, kalluma kaya | 100 g | 100 | USDA #174216 mussels blue raw |

---

## 6. Western pantry

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Olive oil | — | 100 g | 100 | USDA #171413 oil olive salad or cooking |
| Soy sauce | soya sauce | 100 g | 100 | USDA #174277 soy sauce made from soy and wheat |
| Chilli sauce | chili sauce, hot sauce | 100 g | 100 | USDA #171605 hot chili sauce |
| Tomato sauce | tomato ketchup, ketchup | 100 g | 100 | USDA #168556 catsup |
| Vinegar | sirka | 100 g | 100 | USDA #172237 vinegar distilled |
| Mayonnaise | mayo | 100 g | 100 | USDA #171009 salad dressing mayonnaise regular with salt |
| Pesto | basil pesto | 100 g | 100 | USDA #171582 pesto sauce |
| Vegetable stock | vegetable broth | 1 katori | 150 | USDA #171583 soup vegetable broth ready to serve — `soup stock vegetable` returned beef stock |
| Chicken stock | chicken broth | 1 katori | 150 | USDA #172884 soup stock chicken home-prepared |
| Yeast | baker's yeast, active dry yeast | 100 g | 100 | USDA #175043 yeast baker's active dry |
| Baking powder | — | 100 g | 100 | USDA #172804 leavening agents baking powder double-acting |
| Baking soda | mitha soda, sodium bicarbonate | 100 g | 100 | USDA #175040 leavening agents baking soda |
| Gelatin | china grass, agar agar | 100 g | 100 | USDA #169599 gelatins dry powder unsweetened |
| Edible gum | gond, dinkh, gum acacia | 100 g | 100 | USDA #168771 chewing gum — no FDC entry for gond; chewing gum is the nearest measured gum |
| Cocoa powder | — | 100 g | 100 | USDA #169593 cocoa dry powder unsweetened |
| Dark chocolate | — | 100 g | 100 | USDA #170273 chocolate dark 70-85% cacao |
| Vanilla essence | vanilla extract | 100 g | 100 | USDA #173471 vanilla extract |
| Jam | fruit jam, mixed fruit jam | 100 g | 100 | USDA #169641 jams and preserves |
| Coffee powder | instant coffee | 100 g | 100 | USDA #174133 coffee instant powder |
| Tea leaves | chai patti, black tea | 100 g | 100 | USDA #173230 tea instant unsweetened powder |
| Sponge cake | plain cake | 100 g | 100 | USDA #172706 cake sponge commercially prepared |
| Custard | custard powder, vanilla custard | 1 katori | 150 | USDA #169608 puddings vanilla ready-to-eat |
| Biscuits, digestive | marie biscuit, digestive biscuit | 100 g | 100 | USDA #174957 cookies graham crackers plain or honey includes cinnamon — FDC has no digestive; the graham cracker is the same semi-sweet wholemeal biscuit |
| Pepperoni | — | 100 g | 100 | USDA #174603 salami italian pork — FDC publishes no pepperoni with proximates; salami is the same cured pork-and-beef family |
| Peanut butter | — | 100 g | 100 | USDA #172470 peanut butter smooth style without salt |
| Chocolate syrup | chocolate sauce | 100 g | 100 | USDA #174117 syrups chocolate |
| Ice cream, vanilla | vanilla ice cream | 100 g | 100 | USDA #167575 ice creams vanilla |
| Salsa | tomato salsa | 100 g | 100 | USDA #746777 sauce salsa ready to serve |
| Whey protein | protein powder, whey isolate | 100 g | 100 | USDA #173177 whey protein powder isolate |
