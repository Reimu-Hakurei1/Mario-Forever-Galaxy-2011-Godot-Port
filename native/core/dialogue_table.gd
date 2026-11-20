class_name NativeDialogueTable
## NativeDialogueTable — boss intro speeches, transcribed from the
## original's o_boss_*_talk objects (g_dialogue arrays; '#' marks a
## manual line break in the typewriter text).
##
## Keyed by world tier; boss variants override with their own speech.
## "%s" is replaced with the hero name like the original's
## R.concat("YO ", playernames...).

const CLOWN_1 := [
	"YO %s",
	"YOU KNOW THAT#YOU'RE STUPID#TO COME HERE!",
	"YOUR DEATH WILL#BE SLOW #AND PAINFUL.",
	"SAY HELLO TO MY#LITTLE SERVANT#WHO WILL GLADLY#TAKE CARE OF YOU.",
	"HAHAHAHA!#I'M SURE YOU'LL #HAVE GREAT FUN #TOGETHER.",
	"ENJOY IT! #BYE",
]

const CLOWN_UPGRADED := [   # boss_55_talk — mid-campaign gloat
	"THIS TIME I'VE#UPGRADED MY CLOWN#TO SUPER-ULTIMATE#WEAPON!",
	"I'M A GENIUS!!#AND THIS TIME#IT'S MY TURN!!!",
	"PREPARE OR NOT#I'M READY TO#CRUSH YOU!",
]

const CLOWN_5 := [          # boss_5_talk
	"AGAIN %s",
	"THIS IS#MEANINGLESS!#YOU KNOW THAT!",
	"HAHAHA!#YOU CAN'T WIN!",
	"I'VE UPGRADED#MY EVIL CLOWN#THIS TIME I'LL#CRUSH YOU!",
	"AND NO ONE!#NO ONE WILL#STOP ME!",
	"HAHAHA!#DIE",
]

const CLOWN_6 := [          # boss_6_talk
	"I THOUGHT#YOU WERE#EATEN BY#PIRANHAS#IN THIS WORLD!",
	"I SUPPOSE#I WAS WRONG!",
	"WELL...#IT'S TIME#TO FIX IT UP!",
]

const BOSS_2_TALK := [      # boss_2.gd — the mechanical clown
	"GRRRR# HOW DARE YOU!!!",
	"AGAIN YOU#DISTURBING#MY EVIL PLAN#TO CONQUER#THE MUSCHROOM#LAND!",
	"WELL, YOU'VE#DEFEATED MY#SERVANT LAST#TIME",
	"BUT NOW#I'LL DEAL WITH#YOU BY MYSELF!",
	"MY MECHANIQUE#FLYING CLOWN#IS MUCH BETTER#THEN YOUR#FUNNY SHIP!",
	"IT'S WELL ARMORED#AND PREPARED#TO CRUSH YOU!",
	"HAHAHA! SHOW ME#WHAT YOU'VE GOT!",
]

const BOSS_3_TALK := [      # boss_3.gd — after the vessel is destroyed
	"ARRRRRGGHH!!!",
	"YOU'VE DESTROYED#MY VESSEL!#YOU WILL PAY#FOR THAT!",
	"NOW I'M LEAVING#WATCH YOUR BACK!#NEXT TIME I'LL#CRUSH YOU!",
	"BEWARE OF ME AND#MY MINIONS!",
]

const CLOWN_4 := [          # boss_4_talk — the rematch taunt
	"WHAT THE HECK?!#YOU'RE STILL #ALIVE? #IT CAN'T BE.",
	"YOU SHOULD BE#DEAD AFTER# LAST BATTLE#WITH MY MINIONS!",
	"AGAIN, I MUST# DEAL WITH YOU# MYSELF!",
	"THIS TIME I'VE#PREPARED A SUPER#ULTRA ULTIMATE# HIPER WEAPON!",
	"MUAHAHAHAH!#HAHAHAHAH!",
	"HMMM?! WHAT HAVE#I JUST SAID?#",
	"HMMM THINK...# HMM NEVER MIND# FIGHT AND DIE!",
]

const CASTLE_LORD := [      # boss_8_end_talk — the final villain
	"WELCOME TO#MY BEAURIFUL#CASTE!",
	"SO,YOU'VE MANAGED#TO COME HERE.#YOU'RE A LUCKY#ONE BUT#THINKING IS#NOT YOUR#STRONG SIDE IF#YOU'VE COME HERE",
	"YOUR PRINCESS#IS HERE, BUT#YOU WON'T SAVE#HERE. SHE WILL#STAY HERE#F-O-R-E-V-E-R!",
	"HAHAHA!# YOU KNOW WELL#THAT THIS IS#OUR LAST MEETING#YOUR BELOVED#WILL SEE YOUR#DEATH!",
	"NO MATTER WHAT#KIND OF EQUIPMENT#YOU HAVE BOUGHT#IN SHOP NOR#HOW LUCKY YOU#ARE YOU CAN'T#WIN!",
	"I'VE PREPARED#MY CLOWN SO#THAT HE IS#EVEN STRONGER!",
	"ITS WEAPONS#ARE CAPABLE#OF DESTROYING#THE WHOLE WORLD# WITH YOU BEING#ITS FIRST VICTIM",
	"HERE IS YOUR#GRAVE SO DIE!#FIGHT YOU JUNK!!",
	"HAHAHAHA!!",
]

const FATBOY_SENT := [      # boss_map_4_talk — the castle summoner
	"I DIDN'T EVEN#MANAGE TO FINISH#THE CASTLE BEFORE#YOUR ARRIVAL.",
	"BUT THAT'S#NOTHING. I HAVE#NO TIME TO#BEAT YOU KNOW.",
	"I'LL LET MY#FAITHFUL SERVANT#WHO YOU MET#BEFORE# DO IT.",
	"THE FATBOY!#COME AND GET#RID OF THIS#VAGABOND!",
	"HAHAHA!#GOOD LUCK#SUCKERRRRRR!",
]

const BY_VARIANT := {
	"ufo_mega": ["YOU DARE FACE#THE MIGHTY#UFO MEGA?#THINK AGAIN!"],
	"fat_boy": FATBOY_SENT,
	"flame_cans": ["CAN YOU HANDLE#MY FLAMES?#YOU'LL#BURN!"],
}


## Inter-map briefings - objects/ui/next_map_obj.gd ev_0_0_N
## (room 44): the hero/toad banter flown during the
## inter-map warp. Keyed by destination world (1-7); each
## line is "SPEAKER|text" - 0 = hero (top box), 1 = toad
## (bottom-left box) per g_ktogada. %s = hero name.
const NEXT_MAP := {
	1: [
		"0|HELLO %s",
		"0|BUT OUR PRINCESS#IS IN ANOTHER#CASTLE!",
		"1|SHIT!#AGAIN BOWSER#MADE A MISTAKE!#I'LL CATCH HIM!",
		"0|I BELIVE YOU#BUT YOU SHOULD BE#CAREFUL!",
		"0|HE IS PREPARING#NEW EVIL SLAVES#TO STOP YOU!",
		"0|AND HE'S#UPGRADING#HIS CLOWN!",
		"1|WHAT A MORON!#HE IS THINKING#TO MUCH!#BUT WE SHOULD'T#BE CARELESS. # HE IS MAD #AS ALWAYS!",
		"1|OK FELLA.#I'M PREAPRING#TO TAKE OFF#TO NEXT TIME!",
		"0|FAREWELL#%s#LET THE POWER#OF MUSCHROOM#WILL BE WITH#YOU!",
	],
	2: [
		"0|%s YOU'VE#MENAGED HOW#TO BEAT BOWSER!# COOL!",
		"0|AS YOU KNOW#OUR PRINCESS#IS IN ANOTHER#CASTLE!",
		"1|YEA! I KNOW!#BUT THIS TIME#IT WASN'T#EASY!",
		"1|THIS BASTARD#PLACED GHOST#MANSION ON#MY WAY.",
		"1|AND HIS CLOWN!#THAT THING KEEPS#GETTING STRONGER!",
		"0|BUT %s#YOU ARE BRAVE#AND COURAGEOUS!",
		"0|ALTHOUGH YOU#MIGHT HAVE#PROBLEMS WITH#FINISHING THIRD#MAP.",
		"0|THERE IS A KEY#OPENING GATE!#REMEMBER YOU#MUST FIND#A KEY!",
		"0|GOOD LUCK#AND MAY THE#SHROOMS-POWER#BE WITH YOU!",
	],
	3: [
		"0|\"OOU\"%s#YOU ARE STILL#ALIVE! COOL!",
		"0|AS YOU KNOW#OUR PRINCESS#IS IN ANOTHER#CASTLE!",
		"1|YES! I KNOW!",
		"1|SO, WHAT#WILL I FIND#ON THE NEXT MAP?",
		"0|LOTS OF MURDEROUS#PLACES!",
		"0|ONE OF THEM IS#BERSERKERS ABODE!",
		"0|KOOPA TROOPA'S#ACROBATIONS#AND MORE!",
		"0|BE CAREFUL DUDE.#GOOD LUCK!",
		"1|GOOD LUCK#YOU TOO!",
	],
	4: [
		"0|AS YOU ALREADY#KNOW PRINCESS#IS IN ANOTHER#CASTLE.",
		"1|WHAT THE,#ARE YOU JOKING?",
		"0|NO %s\"#THAT'S THE TRUTH.\"",
		"1|HMMMM...#ARE YOU JOKING?",
		"0|NO, HOW COULD I!",
		"1|HMMMM...#ARE YOU KIDDING?",
		"0|DAMN IT#%s#THIS IS NOT#TIME FOR JOKES!",
		"0|LOOK %s#WHO WILL CARE#FOR NUMEROUS#CHILDREN#WHICH MARIO#MADE IN#MARIO FOREVER 1?",
		"1|OH, YOU'RE RIGHT.#I'M SERIOUS#ALREADY.",
		"0|WELL, GOOD#LUCK ON NEXT#MAP!",
	],
	5: [
		"0|%s...",
		"1|YES, YES, I KNOW.# THE PRINCESS IS#IN THE ANOTHER#CASTLE...",
		"0|NOPE. SHE#IS HERE.",
		"1|WHAT?!#SHE IS HERE!#WHERE?!?",
		"1|SHOW ME#SHOW ME#SHOW ME!!!!",
		"0|I WAS JUST#JOKING XD",
		"1|...",
		"0|OK, PREPARE#TO THE SIXTH MAP#AS THERE ARE#LOTS OF#DIFFICULT#MOMMENTS.",
		"0|WATCH OUT#FOR THE CANNONS#PLACED IN#DIFFERENT#PLACES!",
		"0|ALSO WATCH#OUT FOR GREEN#EVIL STARS.",
		"0|THEY ARE REALLY#DIFFICULT ENEMIES#CREATED BY#BOWSER.",
		"0|GOOD LUCK,#AND FINISH#HIM OFF!",
	],
	6: [
		"0|SO YOU DID#IT ONCE AGAIN#%s.",
		"1|DID WHAT?#THE PRINCESS IS#NOT HERE,#ISN'T#SHE?",
		"1|BOWSER TOOK#HER AGAIN#AND ONLY GOD KNOWS#WHAT HE DID#TO HER!",
		"0|OH, DON'T#EXAGGERATE,#EVERYTHING WILL#BE FINE!",
		"0|IF YOU HAVE#MANAGED TO#GET THIS FAR#YOU'LL GET TO#THE END.",
		"0|AND NOW A#LITTLE BRIEFING:",
		"1|BRING IT ON!",
		"0|ON THE SEVENTH#MAP THERE ARE#GODDAMNLY#STRONG#FATBOYS!",
		"1|YEAH I HATE#THEM, THEY#ARE FU***NG#STRONG!",
		"0|YES, THEY#DIFFICULT TO BEAT#SO WATCH OUT!",
		"0|ALSO LOOK#OUT FOR KARBONS#STRONG FLYING#STARS.",
		"0|WHICH DESTROY#EVERYTHING#THEY HIT!",
		"0|BUT NOW, GOOD# LUCK AND SEE#YOU SOON!",
	],
	7: [
		"0|%s\"BOWSER#TOOK PRINCESS#TO HIS BIGGEST#AND LAST CASTLE!\"",
		"0|TIME TO GET RID#OF HIM FOR GOOD!",
		"1|YES, I KNOW#THE TIME HAS#COME FOR HIM#TO MEET HIS#MARKER.",
		"0|WATCH OUT, EIGHTH#MAP IS REALLY#DIFFICULT!#LOTS OF HARD#BATTLES AWAIT YOU",
		"0|BUY THE BEST#EQUIPMENT YOU#CAN IN THE#INTERGALACTIC#SHOP.",
		"0|DON'T SAVE MONEY#BUY THE ARMOR#AND DON'T FORGET#ABOUT#OTHER BOOSTERS!",
		"0|BE CAREFUL#AND WATCH OUT#FOR SKY EYES -#MECHANIC#MONSTERS#SHOOTING LASER!",
		"0|THEY GO TROUGHT#EVERY METAL#AS EASLY AS#IF IT HAS#HOT BUTTER!",
		"0|AND BEFORE#THE FINAL BATTLE#BE REALLY#PREPARED!#HARD BATTLE#AWAITS YOU!",
		"1|OK, THANKS GUY#I'LL BE CAREFUL#AND I WILL#SURELY WIN.",
		"0|I'LL GIVE YOU#TWO MILLIONS#COINS TO HELP#YOU ON YOUR#WAY TO BOWSER.",
		"0|SO BE CAREFUL#AND SAVE THE#PRINCESS!",
		"0|MAY THE#SHROOM-POWER#BE WITH YOU!",
	],
}


## Post-fight speeches — the o_boss_*_end_talk objects each
## boss_N_fight.gd spawns on its death frame (boss_4→o_boss_5_endtalk,
## boss_5→o_boss_55_endtalk, boss_6→o_boss_6_endtalk,
## boss_7→o_boss_7_endtalk, boss_8→o_boss_8_endtalk2). Fight N maps to
## native tier N-1; bosses 1-3 authored no end talk. The fatboy /
## ufo / flame-cans variant bosses spawn crush effects instead — no talk.
const END_TALK := {
	3: ["NO! NO! NO!", "ARGHHHHH!#I WILL BACK!"],                    # boss_5_end_talk
	5: ["I DON'T HAVE#TIME TO TALK#WITH YOU!", "SEE YOU SOON#IN MAP 7!"],  # boss_6_end_talk
	6: ["YOU THINK#IS THIS AN#END?", "TIME TO REAL#BATTLE!"],        # boss_7_end_talk
	7: ["OHHHH NOOOOO!", "NOOOOO!!!!", "ARGHHHHH!!"],                # boss_8_end_talk_2
}

const END_TALK_55 := [   # boss_55_end_talk — boss_5_fight's taunt
	"WHAT THE HELL?!",
	"AGAIN?!",
	"I'VE BEEN#DEFEATED#FOR THE FIVTH#TIME!!!#ARGHHH!",
	"%s#WE SHALL MEET#AGAIN ON THE#NEXT MAP AND#MY ARMY WILL#CRUSH YOU#LIKE A BUG",
	"SEE YOU SOON#%s",
]


## Defeat lines for a boss — empty for tiers/variants without authored
## end talk. `%s` is replaced with the hero name like the original's
## R.concat(playernames...).
static func for_end(tier: int, variant: String, hero_name: String = "") -> Array:
	if variant != "":
		return []
	var lines: Array = END_TALK_55 if tier == 4 else END_TALK.get(tier, [])
	var out: Array = []
	for line in lines:
		out.append(str(line) % hero_name if "%s" in str(line) else str(line))
	return out


## Lines for a boss fight — variant speech wins, else the tier's
## clown dialogue. Missing tiers reuse the closest authored script.
static func for_boss(tier: int, variant: String, hero_name: String) -> Array:
	var lines: Array = BY_VARIANT.get(variant, [])
	if lines.is_empty():
		match tier:
			0: lines = CLOWN_1
			1: lines = BOSS_2_TALK
			2: lines = BOSS_3_TALK
			4: lines = CLOWN_5
			5: lines = CLOWN_6
			3: lines = CLOWN_4
			7: lines = CASTLE_LORD
			_: lines = CLOWN_1
	var out: Array = []
	for line in lines:
		out.append(str(line) % hero_name if "%s" in str(line) else str(line))
	return out
