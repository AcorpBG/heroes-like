"""The artifact catalogue: the 150 artifacts, the sets and the special effects
(docs/artifact-system.md). The one copy of the data: the plan page, the
catalogue doc and the icon tool read it.

Each row: (name, slot, band, bonuses, extras). Bonuses are (kind, amount) or
(kind, amount, school); the plan page's build prices them (one point is one
rank of a hero specialty) and refuses a row that misses its band's budget. Extras: faction (with
"home", the extra line for that faction's heroes), set, special (an epic's rule),
price (a drawback), what (the object, in a few words).
"""

EM, MI, SU, TH, BR, VE = "Embercourt", "Mireclaw", "Sunvault", "Thornwake", "Brasshollow", "Veilmourn"

REGALIA = "Regalia of the Empty Throne"
PENITENT = "The Penitent's Burden"
CARTO = "Cartographer's Table"
CAMP = "Camp Kit"
FERRY = "Ferryman's Fare"
WATCH = "Night Watch"
VOWS = "Twin Vows"
QA = "Question and Answer"
CHIMES = "The Four Chimes"
LENS = "Lens and Flame"

ARTIFACTS = [
    # --- Head: Knowledge, mana, experience ---
    ("Scribe's Cap", "head", "common", [("mana", 3)], {"what": "a felt cap with a quill loop"}),
    ("Novice Circlet", "head", "common", [("kno", 1)], {"what": "a thin copper circlet"}),
    ("Surveyor's Cap", "head", "common", [("scout", 1)], {"set": CARTO, "what": "a peaked cap with a brass sighting ring"}),
    ("Lector's Hood", "head", "uncommon", [("kno", 1), ("mana", 3)], {"faction": SU, "home": [("pow", 1)], "what": "a white hood stitched with glass thread"}),
    ("Candlewright's Coif", "head", "uncommon", [("kno", 1), ("exp", 5)], {"what": "a linen coif spotted with wax"}),
    ("Drum-Speaker's Mask", "head", "uncommon", [("kno", 1), ("cres", 5)], {"faction": MI, "home": [("mom", 1)], "what": "a hide mask with a painted open mouth"}),
    ("Lens-Reader's Spectacles", "head", "rare", [("kno", 2), ("exp", 5)], {"faction": SU, "home": [("pow", 1)], "what": "spectacles with three stacked lenses"}),
    ("Helm of Quiet Counsel", "head", "rare", [("kno", 1), ("mana", 6)], {"what": "a plain helm lined with blue felt"}),
    ("Furnace-Seer's Visor", "head", "rare", [("kno", 1), ("pow", 1), ("scost", 1, "furnace")], {"faction": BR, "home": [("school", 8, "furnace")], "what": "a smoked-glass visor in a brass frame"}),
    ("Crown of Green Wood", "head", "rare", [("kno", 2), ("recover", 5)], {"faction": TH, "home": [("school", 8, "root")], "what": "a living wreath of budding twigs"}),
    ("Twofold Diadem", "head", "epic", [("kno", 2), ("pow", 2), ("mana", 3)], {"special": "The hero may cast a second spell in the first round of each battle.", "what": "a diadem with two faces looking opposite ways"}),
    ("Crown of the Empty Throne", "head", "epic", [("kno", 2), ("coh", 1), ("atk", 2), ("def", 2)], {"set": REGALIA, "special": "The hero may hold a seventh specialty.", "what": "a heavy gold crown with one stone missing"}),

    # --- Neck: Power, spell damage, one school's spells ---
    ("Prism Bead", "neck", "common", [("pow", 1)], {"faction": SU, "home": [("mana", 3)], "what": "a single cut-glass bead on a cord"}),
    ("Ember Locket", "neck", "common", [("sdmg", 5)], {"what": "an iron locket that glows at the seam"}),
    ("Seedling Pendant", "neck", "common", [("school", 8, "root")], {"what": "a sprouting acorn in a wire cage"}),
    ("Cinder Pendant", "neck", "uncommon", [("pow", 1), ("school", 8, "furnace")], {"what": "a black coal with a red heart"}),
    ("Mist Vial", "neck", "uncommon", [("pow", 1), ("school", 8, "veil")], {"what": "a stoppered vial of grey fog"}),
    ("Daybreak Torc", "neck", "uncommon", [("pow", 1), ("school", 8, "beacon")], {"what": "a gold torc ending in two small suns"}),
    ("Collar of the Loud Voice", "neck", "rare", [("pow", 2), ("sdmg", 5)], {"what": "a stiff silver collar engraved with open mouths"}),
    ("Thornmother's Necklace", "neck", "rare", [("pow", 1), ("school", 16, "root")], {"faction": TH, "home": [("recover", 5)], "what": "a string of rose hips and long thorns"}),
    ("Penitent's Chain", "neck", "rare", [("pow", 3), ("sdmg", 10)], {"set": PENITENT, "price": "-1 Knowledge", "what": "a rusted iron neck chain carrying a plain square block of lead"}),
    ("Bog-Witch Teeth", "neck", "rare", [("pow", 2), ("curse", 1)], {"faction": MI, "home": [("school", 8, "veil")], "what": "a necklace of yellow teeth and reed knots"}),
    ("The Unanswered Word", "neck", "epic", [("pow", 3), ("sdmg", 10)], {"special": "Your spells count only half of the enemy hero's Knowledge.", "what": "a silver tongue on a black ribbon"}),
    ("The Flame", "neck", "epic", [("pow", 2), ("mana", 9)], {"set": LENS, "special": "The first spell of each battle costs no mana.", "what": "a small flame that burns inside a crystal drop"}),

    # --- Cloak: spell and control resistance, scouting ---
    ("Traveller's Cloak", "cloak", "common", [("scout", 1)], {"set": CAMP, "what": "a patched grey travelling cloak"}),
    ("Warded Shawl", "cloak", "common", [("sres", 5)], {"what": "a wool shawl with a stitched ward along the hem"}),
    ("Reedskin Mantle", "cloak", "common", [("cres", 5)], {"faction": MI, "home": [("scout", 1)], "what": "a mantle woven of green reeds"}),
    ("Fogcutter Cape", "cloak", "uncommon", [("scout", 1), ("sres", 5)], {"faction": VE, "home": [("move", 1)], "what": "an oilcloth cape beaded with mist"}),
    ("Watchman's Greatcoat", "cloak", "uncommon", [("scout", 1), ("carry", 1)], {"set": WATCH, "what": "a long dark coat with a high collar"}),
    ("Mirrorweave Cloak", "cloak", "uncommon", [("sres", 10)], {"what": "a cloak that shines like dull tin"}),
    ("Oathkeeper's Mantle", "cloak", "uncommon", [("cres", 5), ("coh", 1)], {"faction": EM, "home": [("guard", 1)], "what": "a red mantle pinned with a lock-shaped clasp"}),
    ("Cloak of Turned Words", "cloak", "rare", [("sres", 10), ("cres", 5)], {"what": "a cloak embroidered with mirrored writing"}),
    ("Mantle of the Empty Throne", "cloak", "rare", [("sres", 5), ("cres", 5), ("coh", 1)], {"set": REGALIA, "what": "an ermine mantle gone grey with age"}),
    ("Stalker's Pelt", "cloak", "rare", [("scout", 2), ("init", 1)], {"faction": MI, "home": [("mom", 1)], "what": "a mottled marsh-cat pelt with the head on"}),
    ("Cinderproof Cape", "cloak", "rare", [("sres", 10), ("taken", 4)], {"what": "a cape of grey felted ash-cloth"}),
    ("Shroud of the Unseen Fleet", "cloak", "epic", [("sres", 10), ("scout", 2), ("init", 1)], {"faction": VE, "home": [("scout", 1)], "special": "Enemy shots from more than five hexes away do half damage to your stacks.", "what": "a sailcloth shroud that trails thick fog"}),

    # --- Armor: Defense, creature health, less damage taken ---
    ("Padded Jack", "armor", "common", [("def", 2)], {"set": CAMP, "what": "a quilted soldier's jacket"}),
    ("Drover's Vest", "armor", "common", [("health", 3)], {"what": "a thick leather vest with horn buttons"}),
    ("Pikeward Plate", "armor", "common", [("def", 2)], {"faction": EM, "home": [("coh", 1)], "what": "a plain breastplate with a pike rest"}),
    ("Banded Hauberk", "armor", "uncommon", [("def", 2), ("health", 3)], {"what": "a mail shirt banded with steel"}),
    ("Boilerplate Cuirass", "armor", "uncommon", [("def", 2), ("taken", 4)], {"faction": BR, "home": [("health", 3)], "what": "a riveted cuirass cut from boiler plate"}),
    ("Barkskin Vest", "armor", "uncommon", [("health", 3), ("recover", 5)], {"faction": TH, "home": [("def", 2)], "what": "a vest of overlapping living bark"}),
    ("Relief-Line Breastplate", "armor", "rare", [("def", 2), ("guard", 1), ("coh", 1)], {"faction": EM, "home": [("taken", 4)], "what": "a breastplate stamped with a river lock"}),
    ("Penitent's Hairshirt", "armor", "rare", [("def", 4), ("taken", 8), ("coh", 1)], {"set": PENITENT, "price": "-2 map movement", "what": "a coarse shirt sewn with iron plates"}),
    ("Wardens' Lamellar", "armor", "rare", [("def", 4), ("health", 3)], {"what": "laced lamellar in green lacquer"}),
    ("Prismatic Harness", "armor", "rare", [("def", 2), ("sres", 10)], {"faction": SU, "home": [("kno", 1)], "what": "a harness of crystal plates over white leather"}),
    ("The Unbroken Wall", "armor", "epic", [("def", 4), ("taken", 8), ("coh", 1)], {"special": "Your stacks' cohesion never falls below where it began the battle.", "what": "a tower-breastplate built like dressed stone"}),
    ("Mother-Graft Mail", "armor", "epic", [("def", 4), ("health", 6), ("recover", 5)], {"faction": TH, "home": [("recover", 5)], "special": "As each round begins, your most wounded stack heals the health of one creature.", "what": "mail of woven roots with green shoots"}),

    # --- Hand: weapons (Attack, melee, ranged) and instruments (scouting, movement) ---
    ("Soldier's Sidearm", "hand", "common", [("atk", 2)], {"what": "a short plain sword"}),
    ("Hunter's Bow", "hand", "common", [("ranged", 5)], {"what": "a short hunting bow"}),
    ("Foot Lantern", "hand", "common", [("scout", 1)], {"set": WATCH, "what": "a tin lantern on a carrying ring"}),
    ("Pocket Compass", "hand", "common", [("move", 1)], {"set": CARTO, "what": "a small brass compass with a lid"}),
    ("Rivet Hammer", "hand", "common", [("melee", 5)], {"faction": BR, "home": [("siege", 10)], "what": "a long-handled foundry hammer"}),
    ("Reed Spear", "hand", "common", [("atk", 2)], {"faction": MI, "home": [("init", 1)], "what": "a light spear with a bone point"}),
    ("Captain's Sabre", "hand", "uncommon", [("atk", 2), ("melee", 5)], {"what": "a curved sabre with a worn grip"}),
    ("Longwatch Spyglass", "hand", "uncommon", [("scout", 2)], {"what": "a four-draw brass spyglass"}),
    ("Yew Warbow", "hand", "uncommon", [("ranged", 10)], {"what": "a tall yew bow"}),
    ("Parrying Dagger", "hand", "uncommon", [("def", 2), ("retal", 10)], {"what": "a dagger with a wide basket guard"}),
    ("Lockkeeper's Pike", "hand", "uncommon", [("atk", 2), ("guard", 1)], {"faction": EM, "home": [("coh", 1)], "what": "a pike with a hooked lock-gate blade"}),
    ("Harpoon of the Wake", "hand", "uncommon", [("ranged", 5), ("init", 1)], {"faction": VE, "home": [("ranged", 5)], "what": "a barbed harpoon on a coiled line"}),
    ("Signal Mirror", "hand", "uncommon", [("scout", 1), ("init", 1)], {"faction": SU, "home": [("pow", 1)], "what": "a round hand mirror with a sighting hole"}),
    ("Pruning Hook", "hand", "uncommon", [("atk", 2), ("recover", 5)], {"faction": TH, "home": [("health", 3)], "what": "a curved pruning blade on a staff"}),
    ("The Question", "hand", "rare", [("atk", 2), ("melee", 10)], {"set": QA, "what": "a slim duelling sword with a hooked point"}),
    ("The Answer", "hand", "rare", [("def", 2), ("retal", 20)], {"set": QA, "what": "a left-hand blade with a notched edge"}),
    ("Sceptre of the Empty Throne", "hand", "rare", [("atk", 2), ("coh", 1), ("init", 1)], {"set": REGALIA, "what": "a gold sceptre with a cracked orb"}),
    ("Stormcaller's Horn", "hand", "rare", [("init", 2), ("mom", 1)], {"what": "a great ram's horn bound in silver"}),
    ("Astrolabe of Far Roads", "hand", "rare", [("move", 2), ("scout", 1)], {"what": "a brass astrolabe engraved with roads"}),
    ("Butcher's Maul", "hand", "rare", [("atk", 4), ("melee", 15)], {"price": "your troops take 4% more damage", "what": "a huge spiked maul, stained dark"}),
    ("Siege Mattock", "hand", "rare", [("atk", 2), ("siege", 20)], {"faction": BR, "home": [("melee", 5)], "what": "a heavy mattock with a steel beak"}),
    ("Boarding Axe", "hand", "rare", [("atk", 2), ("mom", 1), ("init", 1)], {"faction": VE, "home": [("retal", 10)], "what": "a hooked ship's axe hung with rope"}),
    ("The Last Gate", "hand", "epic", [("atk", 4), ("def", 4), ("coh", 1)], {"special": "The enemy cannot retreat or surrender.", "what": "a tall shield shaped like a barred gate"}),
    ("Never-Empty Quiver", "hand", "epic", [("ranged", 15), ("init", 2)], {"special": "Your shooters never run out of shots.", "what": "a quiver packed with white-fletched arrows"}),
    ("Staff of the First Tree", "hand", "epic", [("pow", 2), ("school", 16, "root"), ("mana", 3)], {"special": "The hero casts Green Return as if it knew it.", "what": "a gnarled staff with one green leaf"}),
    ("The Opening Cut", "hand", "epic", [("atk", 4), ("melee", 10), ("mom", 1)], {"special": "The first strike of each of your stacks in a battle is not struck back.", "what": "a long thin blade, bright as a razor"}),

    # --- Ring: spell cost, spell length, income ---
    ("Copper Signet", "ring", "common", [("gold", 75)], {"what": "a copper ring with a merchant's mark"}),
    ("Bosun's Ring", "ring", "common", [("woodore", 1)], {"faction": VE, "home": [("scout", 1)], "what": "a rope-pattern iron ring"}),
    ("Apprentice's Band", "ring", "common", [("mana", 3)], {"what": "a plain silver band with one rune"}),
    ("Knot Ring", "ring", "common", [("boost", 1)], {"what": "a ring tied from red cord"}),
    ("Vow of Giving", "ring", "uncommon", [("mana", 6)], {"set": VOWS, "what": "a gold ring with an open hand"}),
    ("Vow of Keeping", "ring", "uncommon", [("mvic", 4)], {"set": VOWS, "what": "a gold ring with a closed hand"}),
    ("Merchant's Seal", "ring", "uncommon", [("gold", 150)], {"what": "a heavy seal ring with a set of scales"}),
    ("Hexwright's Loop", "ring", "uncommon", [("curse", 1), ("sdmg", 5)], {"what": "a twisted black ring"}),
    ("Granary Seal", "ring", "uncommon", [("gold", 75), ("rare", 1)], {"what": "a bronze ring with a wheat sheaf"}),
    ("Ring of the Short Road", "ring", "rare", [("cost", 1), ("mana", 3)], {"what": "a ring cut with a straight line through a maze"}),
    ("Signet of the Empty Throne", "ring", "rare", [("gold", 150), ("coh", 1)], {"set": REGALIA, "what": "a gold signet with a throne and no king"}),
    ("The Lens", "ring", "rare", [("pow", 1), ("sdmg", 10)], {"set": LENS, "what": "a ring set with a clear round lens"}),
    ("Debtor's Band", "ring", "rare", [("cost", 2), ("mana", 3)], {"price": "-1 Power", "what": "a tight iron band stamped with tally marks"}),
    ("Saltcounter's Ring", "ring", "rare", [("gold", 150), ("plunder", 10)], {"faction": VE, "home": [("rare", 1)], "what": "a pale ring crusted with salt crystals"}),
    ("Ring of the Noon Hour", "ring", "epic", [("pow", 2), ("school", 16, "beacon"), ("scost", 1, "beacon")], {"special": "The hero casts Eternal Noon as if it knew it.", "what": "a gold ring holding a tiny sun at its height"}),
    ("The Open Hand", "ring", "epic", [("cost", 1), ("mana", 6), ("boost", 1)], {"special": "Your spells that strike an area do not hurt your own stacks.", "what": "a white ring shaped like fingers spread wide"}),

    # --- Boots: map movement, movement kept for the next day ---
    ("Marching Boots", "boots", "common", [("move", 1)], {"set": CAMP, "what": "hobnailed army boots"}),
    ("Surveyor's Boots", "boots", "common", [("carry", 1)], {"set": CARTO, "what": "tall waxed boots with measuring marks"}),
    ("Night Watch Boots", "boots", "uncommon", [("move", 1), ("carry", 1)], {"set": WATCH, "what": "soft black boots with felt soles"}),
    ("Fenwalkers", "boots", "uncommon", [("move", 2)], {"faction": MI, "home": [("scout", 1)], "what": "wide boots webbed like a frog's feet"}),
    ("Courier's Spurs", "boots", "uncommon", [("move", 2)], {"what": "riding boots with silver spurs"}),
    ("Longstride Greaves", "boots", "rare", [("move", 3)], {"what": "steel greaves with winged ankles"}),
    ("Penitent's Sandals", "boots", "rare", [("move", 3), ("carry", 2)], {"set": PENITENT, "price": "-1 initiative", "what": "rope sandals worn thin"}),
    ("Deckhand's Seaboots", "boots", "rare", [("move", 2), ("scout", 1)], {"set": FERRY, "what": "tarred sea boots folded at the knee"}),
    ("Rail-Walker's Boots", "boots", "rare", [("move", 2), ("carry", 1)], {"faction": BR, "home": [("move", 1)], "what": "iron-shod boots with a wheel at the heel"}),
    ("Roadeater Boots", "boots", "epic", [("move", 4), ("carry", 1)], {"special": "Movement on roads costs half.", "what": "boots whose soles are a strip of paved road"}),

    # --- Banner: the whole army ---
    ("Company Pennant", "banner", "common", [("coh", 1)], {"what": "a small swallow-tailed pennant"}),
    ("Drummer's Guidon", "banner", "common", [("init", 1)], {"what": "a short flag on a drumstick staff"}),
    ("Harvest Flag", "banner", "common", [("muster", 10)], {"faction": TH, "home": [("health", 3)], "what": "a green flag with a fruiting branch"}),
    ("Banner of the Empty Throne", "banner", "uncommon", [("coh", 1), ("mom", 1)], {"set": REGALIA, "what": "a faded royal banner with the arms cut out"}),
    ("Recruiter's Colours", "banner", "uncommon", [("muster", 20)], {"what": "a bright flag hung with coins"}),
    ("Charge Standard", "banner", "uncommon", [("mom", 1), ("init", 1)], {"what": "a red standard with a lance head"}),
    ("Herald's Ensign", "banner", "uncommon", [("init", 1), ("sres", 5)], {"what": "a white ensign with a silver trumpet"}),
    ("Standard of the Long March", "banner", "rare", [("init", 1), ("coh", 1), ("move", 1)], {"what": "a dust-brown standard sewn with road names"}),
    ("War-Drum of the Red Hour", "banner", "rare", [("mom", 2), ("init", 2), ("atk", 2)], {"price": "-1 cohesion", "what": "a red war drum on a banner pole"}),
    ("Oathfire Standard", "banner", "rare", [("coh", 2), ("guard", 1)], {"faction": EM, "home": [("def", 2)], "what": "a standard topped with a lit brazier"}),
    ("Wake-Lantern Ensign", "banner", "rare", [("init", 2), ("scout", 1)], {"faction": VE, "home": [("mom", 1)], "what": "a black ensign under a pale ship's lantern"}),
    ("Colours of the Sworn", "banner", "rare", [("coh", 2), ("recover", 5)], {"what": "a blue banner covered in signed names"}),
    ("Vanguard's Thunder", "banner", "epic", [("init", 3), ("mom", 2)], {"special": "Your stacks act before every enemy stack in the first round.", "what": "a storm-grey banner that cracks like a whip"}),
    ("The Blood-Drum", "banner", "epic", [("mom", 2), ("init", 2), ("atk", 2)], {"faction": MI, "home": [("mom", 1)], "special": "Your stacks do 15% more damage to stacks that have lost creatures in this battle.", "what": "a hide drum on a pole, painted with red hands"}),

    # --- Trinket: income, rewards, oddities ---
    ("First Coin", "trinket", "common", [("plunder", 10)], {"set": FERRY, "what": "a worn silver coin with a boat"}),
    ("Second Coin", "trinket", "common", [("gold", 75)], {"set": FERRY, "what": "a worn silver coin with an oar"}),
    ("Tin Cup", "trinket", "common", [("recover", 5)], {"set": CAMP, "what": "a dented tin camp cup"}),
    ("Field Journal", "trinket", "common", [("exp", 5)], {"what": "a small notebook tied with string"}),
    ("Sun Dial Charm", "trinket", "common", [("mana", 3)], {"faction": SU, "home": [("sdmg", 5)], "what": "a pocket sundial of white stone"}),
    ("Salt Pouch", "trinket", "common", [("rare", 1)], {"faction": VE, "home": [("plunder", 10)], "what": "a grey pouch leaking salt"}),
    ("Toll Token", "trinket", "common", [("gold", 75)], {"faction": EM, "home": [("woodore", 1)], "what": "a stamped brass toll disc"}),
    ("Seed Purse", "trinket", "common", [("rare", 1)], {"faction": TH, "home": [("muster", 10)], "what": "a leaf-wrapped purse of seeds"}),
    ("Pressure Whistle", "trinket", "common", [("init", 1)], {"faction": BR, "home": [("def", 2)], "what": "a brass steam whistle on a chain"}),
    ("Dawn Chime", "trinket", "uncommon", [("school", 8, "beacon"), ("scost", 1, "beacon")], {"set": CHIMES, "what": "a gold chime shaped like a sunrise"}),
    ("Ember Chime", "trinket", "uncommon", [("school", 8, "furnace"), ("scost", 1, "furnace")], {"set": CHIMES, "what": "an iron chime that glows at the rim"}),
    ("Leaf Chime", "trinket", "uncommon", [("school", 8, "root"), ("scost", 1, "root")], {"set": CHIMES, "what": "a wooden chime carved as a leaf"}),
    ("Mist Chime", "trinket", "uncommon", [("school", 8, "veil"), ("scost", 1, "veil")], {"set": CHIMES, "what": "a glass chime filled with fog"}),
    ("Quartermaster's Ledger", "trinket", "uncommon", [("gold", 75), ("woodore", 1)], {"what": "a thick ledger with a brass lock"}),
    ("Trophy Belt", "trinket", "uncommon", [("plunder", 20)], {"what": "a belt hung with captured buckles"}),
    ("Old Campaign Map", "trinket", "uncommon", [("scout", 1), ("exp", 5)], {"what": "a creased map marked with old battles"}),
    ("Surgeon's Roll", "trinket", "uncommon", [("recover", 10)], {"what": "a canvas roll of bone needles and thread"}),
    ("Guild Stamp", "trinket", "uncommon", [("gold", 150)], {"what": "a carved seal stamp and red wax"}),
    ("Gauge of Fair Weight", "trinket", "uncommon", [("woodore", 1), ("rare", 1)], {"faction": BR, "home": [("gold", 75)], "what": "a brass dial gauge with two needles"}),
    ("Herbalist's Satchel", "trinket", "uncommon", [("recover", 5), ("health", 3)], {"what": "a satchel stuffed with dried herbs"}),
    ("Tax-Farmer's Strongbox", "trinket", "rare", [("gold", 300), ("woodore", 1)], {"price": "-1 map movement", "what": "an iron strongbox with three locks"}),
    ("Hourglass of the Second Wind", "trinket", "rare", [("init", 1), ("carry", 1), ("move", 1)], {"what": "an hourglass whose sand runs upward"}),
    ("Master's Primer", "trinket", "rare", [("exp", 10), ("kno", 1)], {"what": "a small book with a hundred bookmarks"}),
    ("Brimming Horn", "trinket", "rare", [("gold", 150), ("rare", 1)], {"what": "a drinking horn spilling grain and coins"}),
    ("Medal of the Thirty", "trinket", "rare", [("coh", 1), ("mom", 1), ("atk", 2)], {"what": "a bronze medal with thirty tiny shields"}),
    ("Wardstone", "trinket", "rare", [("sres", 10), ("cres", 5)], {"what": "a flat river stone cut with a ward"}),
    ("Assayer's Scales", "trinket", "rare", [("gold", 150), ("plunder", 10)], {"faction": EM, "home": [("rare", 1)], "what": "folding brass scales in a red case"}),
    ("Hunt-Tally Cord", "trinket", "rare", [("mom", 1), ("plunder", 20)], {"faction": MI, "home": [("init", 1)], "what": "a short straight tally cord with knots and three claws tied along it"}),
    ("Tuning Crystal", "trinket", "rare", [("pow", 1), ("boost", 1), ("sdmg", 5)], {"faction": SU, "home": [("school", 8, "beacon")], "what": "a humming crystal fork"}),
    ("Seedbank Reliquary", "trinket", "rare", [("muster", 10), ("recover", 10)], {"faction": TH, "home": [("health", 3)], "what": "a wooden box of labelled seeds"}),
    ("The Reader's Case", "trinket", "epic", [("kno", 2), ("mana", 6), ("pow", 1)], {"special": "Worn scrolls are cast at +2 Power.", "what": "a tooled leather scroll case with four tubes"}),
    ("The Ever-Coal", "trinket", "epic", [("pow", 2), ("school", 16, "furnace"), ("sdmg", 5)], {"special": "The hero casts Second Sun as if it knew it.", "what": "a coal that burns white and never shrinks"}),
    ("Mirror of the Far Shore", "trinket", "epic", [("pow", 2), ("school", 16, "veil"), ("curse", 1)], {"special": "The hero casts Hollow Crown as if it knew it.", "what": "a black hand mirror showing another coast"}),
    ("The Standing Order", "trinket", "epic", [("def", 4), ("taken", 8), ("siege", 10)], {"faction": BR, "home": [("siege", 10)], "special": "A stack of yours that has not moved this round takes 25% less damage.", "what": "a brass plaque engraved with one command"}),
    ("Writ of Relief", "trinket", "epic", [("coh", 2), ("def", 4), ("gold", 75)], {"faction": EM, "home": [("coh", 1)], "special": "A stack of yours that defends also gives +2 Defense to your stacks beside it.", "what": "a rolled parchment charter tied with ribbon and hung with seven wax seals"}),
    ("The Prime Lens", "trinket", "epic", [("pow", 2), ("boost", 1), ("sdmg", 10)], {"faction": SU, "home": [("pow", 1)], "special": "Boosts the hero casts in the first round last the whole battle.", "what": "a flawless lens in a gold ring stand"}),
]

# name, pieces are found from ARTIFACTS; steps: (pieces worn, what it gives), the
# last step is the full set's special effect.
SETS = [
    (VOWS, "Two rings made as a pair; they fill both ring places.", [(2, "Mana comes back twice as fast each day.")]),
    (QA, "A sword and its left-hand blade; they fill both hands.", [(2, "Your stacks strike back at every attack, not only the first each round.")]),
    (LENS, "A ring and a pendant: the lens gathers what the flame gives.", [(2, "A spell that destroys a stack returns half its mana.")]),
    (CHIMES, "One chime for each school. All four fill every trinket place, so the hero wears no scroll.", [(2, "+3 max mana"), (3, "+1 Power"), (4, "Every spell is cast as if the hero had one more rank of its school's mastery.")]),
    (REGALIA, "Five pieces of a lost king's regalia, from an uncommon banner up to the epic crown.", [(2, "+1 cohesion"), (3, "+1 Attack and +1 Defense"), (5, "The town the hero stands in may build twice a day.")]),
    (PENITENT, "Three strong rares, each with a price. Worn together the prices are lifted.", [(3, "The three prices no longer apply.")]),
    (CARTO, "A surveyor's cap, compass and boots: three commons.", [(2, "+1 scouting"), (3, "Sand, swamp, snow, rough ground and lava cost the army no more than grass.")]),
    (CAMP, "Four commons any army has lying about.", [(2, "+1 map movement"), (4, "After a day without a battle the hero starts the next day with +3 map movement.")]),
    (FERRY, "Two coins for the ferryman and a pair of sea boots.", [(2, "+75 gold a day"), (3, "Boarding and leaving a ship costs no movement.")]),
    (WATCH, "A watchman's coat, lantern and boots.", [(2, "+1 scouting"), (3, "All unused movement is kept for the next day.")]),
]
