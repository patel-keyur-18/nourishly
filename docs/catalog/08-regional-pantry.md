# Regional Pantry

*[Catalog index](./README.md) · 89 items · Read [§0.2–0.3](./README.md) before using the gram weights*

Ingredient rows the regional CSV catalogs need and the earlier files did not have. Every row here is a **direct USDA lookup** — a food, not a dish — because that is the only thing a recipe can be summed from (§0.2).

These rows exist because `app/assets/regional_food/*.csv` names them. A regional dish that lists `Curry leaves 2 g` cannot resolve to anything unless curry leaves is a row, and mapping it to a near neighbour instead would put a number in the app that nobody measured. Where an ingredient genuinely has no FoodData Central entry — kokum, ker, ajwain — it is settled in `ingredient_targets.dart` against the closest row the catalog already measures, with the reason on the line. It does not get an invented row here.

Serving weights are the raw-ingredient convention of `01-common.md`: 100 g for a pantry item, a katori for the few rows that are already cooked.

---

## 1. Spices and aromatics

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Cardamom | elaichi, elakkai, yelakki | 100 g | 100 | USDA spices cardamom |
| Cinnamon | dalchini, lavanga pattai, chakke | 100 g | 100 | USDA spices cinnamon ground |
| Bay leaf | tej patta, biryani leaf | 100 g | 100 | USDA spices bay leaf |
| Nutmeg | jaiphal, jathikai | 100 g | 100 | USDA spices nutmeg ground |
| Saffron | kesar, kunkuma puvvu | 100 g | 100 | USDA spices saffron |
| Fennel seeds | saunf, sombu, badishep | 100 g | 100 | USDA spices fennel seed |
| Fenugreek seeds | methi dana, venthayam, menthe | 100 g | 100 | USDA spices fenugreek seed |
| Poppy seeds | khus khus, gasagase, kasakasa | 100 g | 100 | USDA spices poppy seed |
| Dried red chilli | sukhi lal mirch, vatha milagai, byadgi chilli | 100 g | 100 | USDA peppers hot chili red dried |
| Curry leaves | kadi patta, karuveppilai, kari bevu | 100 g | 100 | USDA curry leaves |
| Mixed herbs | italian seasoning, oregano | 100 g | 100 | USDA spices oregano dried |
| Basil | tulsi, sweet basil | 100 g | 100 | USDA basil fresh |
| Parsley | — | 100 g | 100 | USDA parsley fresh |

---

## 2. Vegetables, greens and fruit

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Spring onion | scallion, green onion, hara pyaz | 100 g | 100 | USDA onions spring or scallions raw |
| Shallots | sambar onion, small onion, chinna vengayam | 100 g | 100 | USDA shallots raw |
| Lettuce | salad leaves | 100 g | 100 | USDA lettuce iceberg raw |
| Zucchini | courgette | 100 g | 100 | USDA squash zucchini raw |
| Broccoli | — | 100 g | 100 | USDA broccoli raw |
| Sweet corn | corn kernels, makai | 100 g | 100 | USDA corn sweet yellow raw |
| Mustard greens | sarson, rai ka saag | 100 g | 100 | USDA mustard greens raw |
| Drumstick leaves | moringa leaves, murungai keerai, nugge soppu | 100 g | 100 | USDA drumstick leaves raw |
| Gongura leaves | roselle leaves, ambadi, pulicha keerai | 100 g | 100 | USDA roselle raw |
| Bamboo shoots | — | 100 g | 100 | USDA bamboo shoots raw |
| Tapioca root | kappa, cassava, maravalli kizhangu | 100 g | 100 | USDA cassava raw |
| Potato, boiled | boiled potato | 100 g | 100 | USDA potatoes boiled cooked without skin |
| Pineapple | ananas | 100 g | 100 | USDA pineapple raw |
| Amla | indian gooseberry, nellikai, usirikaya | 100 g | 100 | USDA gooseberries raw |
| Dried apricots | khubani | 100 g | 100 | USDA apricots dried |
| Mixed fruit | fruit salad | 100 g | 100 | USDA fruit cocktail canned in juice |
| Olives | black olives | 100 g | 100 | USDA olives ripe canned |
| Tomato puree | tomato paste, passata | 100 g | 100 | USDA tomato puree canned |

---

## 3. Pulses, grains and flours

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Dried peas | white peas, safed vatana, dried yellow peas | 100 g | 100 | USDA peas split mature seeds raw |
| Tuvar lilva | fresh pigeon peas, tuver lilva | 100 g | 100 | USDA pigeon peas immature seeds raw |
| Toor dal, cooked | cooked tuvar dal, cooked arhar dal | 1 katori | 150 | USDA pigeon peas cooked |
| Chana, boiled | boiled chickpeas, cooked chana | 1 katori | 150 | USDA chickpeas cooked |
| Fox nuts | makhana, phool makhana, lotus seeds | 100 g | 100 | USDA lotus seeds dried |
| Maize flour | makai no lot, cornmeal | 100 g | 100 | USDA corn flour whole grain yellow |
| Corn flour | cornflour, corn starch | 100 g | 100 | USDA cornstarch |
| Rice, brown, raw | brown rice | 100 g | 100 | USDA rice brown long-grain raw |
| Rice noodles | rice sticks, rice vermicelli | 100 g | 100 | USDA rice noodles dry |
| Pasta, cooked | boiled pasta, cooked noodles | 1 katori | 150 | USDA pasta cooked |
| Sago | sabudana, javvarisi, sabakki | 100 g | 100 | USDA tapioca pearl dry |
| Breadcrumbs | bread crumbs | 100 g | 100 | USDA bread crumbs dry grated |
| Cornflakes | corn flakes | 30 g | 30 | USDA cereals ready-to-eat corn flakes |
| Muesli | — | 40 g | 40 | USDA cereals ready-to-eat muesli |
| Soya chunks | soy nuggets, meal maker | 100 g | 100 | USDA soy protein concentrate |
| Tofu | soya paneer, bean curd | 100 g | 100 | USDA tofu raw firm |

---

## 4. Dairy and cheese

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Cheddar cheese | cheddar | 100 g | 100 | USDA cheese cheddar |
| Mozzarella cheese | mozzarella, pizza cheese | 100 g | 100 | USDA cheese mozzarella whole milk |
| Parmesan cheese | parmesan, parmigiano | 100 g | 100 | USDA cheese parmesan grated |
| Ricotta cheese | ricotta | 100 g | 100 | USDA cheese ricotta whole milk |
| Cream cheese | — | 100 g | 100 | USDA cheese cream |
| Milk powder | skimmed milk powder, dairy whitener | 100 g | 100 | USDA milk dry whole |

---

## 5. Meat, fish and seafood

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Chicken, cooked | cooked chicken, roast chicken | 100 g | 100 | USDA chicken breast roasted |
| Pork | — | 100 g | 100 | USDA pork fresh loin raw |
| Beef, raw | beef mince, minced beef | 100 g | 100 | USDA beef ground raw |
| Duck | — | 100 g | 100 | USDA duck meat raw |
| Goat liver | kaleji, mutton liver | 100 g | 100 | USDA lamb variety meats liver raw |
| Fish, rohu | rui, rohu, carp | 100 g | 100 | USDA fish carp raw |
| Fish, mackerel | bangda, ayala, aiyla | 100 g | 100 | USDA fish mackerel raw |
| Fish, hilsa | ilish, palla | 100 g | 100 | USDA fish shad american raw |
| Fish, anchovy | nethili, kozhuva, anchovies | 100 g | 100 | USDA fish anchovy raw |
| Tuna, canned | canned tuna | 100 g | 100 | USDA fish tuna light canned in water drained |
| Crab | njandu, nandu, kekda | 100 g | 100 | USDA crab blue raw |
| Mussels | kadukka, kalluma kaya | 100 g | 100 | USDA mussels blue raw |

---

## 6. Western pantry

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Olive oil | — | 100 g | 100 | USDA oil olive salad or cooking |
| Soy sauce | soya sauce | 100 g | 100 | USDA soy sauce made from soy and wheat |
| Chilli sauce | chili sauce, hot sauce | 100 g | 100 | USDA hot chili sauce |
| Tomato sauce | tomato ketchup, ketchup | 100 g | 100 | USDA catsup |
| Vinegar | sirka | 100 g | 100 | USDA vinegar distilled |
| Mayonnaise | mayo | 100 g | 100 | USDA mayonnaise regular |
| Pesto | basil pesto | 100 g | 100 | USDA pesto sauce |
| Vegetable stock | vegetable broth | 1 katori | 150 | USDA soup stock vegetable |
| Chicken stock | chicken broth | 1 katori | 150 | USDA soup stock chicken home-prepared |
| Yeast | baker's yeast, active dry yeast | 100 g | 100 | USDA yeast baker's active dry |
| Baking powder | — | 100 g | 100 | USDA leavening agents baking powder double-acting |
| Baking soda | mitha soda, sodium bicarbonate | 100 g | 100 | USDA leavening agents baking soda |
| Gelatin | china grass, agar agar | 100 g | 100 | USDA gelatins dry powder unsweetened |
| Edible gum | gond, dinkh, gum acacia | 100 g | 100 | USDA gum arabic |
| Cocoa powder | — | 100 g | 100 | USDA cocoa dry powder unsweetened |
| Dark chocolate | — | 100 g | 100 | USDA chocolate dark 70-85% cacao |
| Vanilla essence | vanilla extract | 100 g | 100 | USDA vanilla extract |
| Jam | fruit jam, mixed fruit jam | 100 g | 100 | USDA jams and preserves |
| Coffee powder | instant coffee | 100 g | 100 | USDA coffee instant powder |
| Tea leaves | chai patti, black tea | 100 g | 100 | USDA tea instant unsweetened powder |
| Sponge cake | plain cake | 100 g | 100 | USDA cake sponge commercially prepared |
| Custard | custard powder, vanilla custard | 1 katori | 150 | USDA puddings vanilla ready-to-eat |
| Biscuits, digestive | marie biscuit, digestive biscuit | 100 g | 100 | USDA cookies digestive |
| Pepperoni | — | 100 g | 100 | USDA pepperoni pork beef |
