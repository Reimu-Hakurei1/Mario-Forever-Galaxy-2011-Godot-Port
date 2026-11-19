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


## Post-fight speeches — the o_boss_*_end_talk objects that play as
## the boss dies, before g_end_level fires. Only bosses 5-8 (and the
## boss_55 bonus fight) authored end lines; earlier tiers go silent.
const END_TALK := {
	4: ["NO! NO! NO!", "ARGHHHHH!#I WILL BACK!"],                    # boss_5_end_talk
	5: ["I DON'T HAVE#TIME TO TALK#WITH YOU!", "SEE YOU SOON#IN MAP 7!"],  # boss_6_end_talk
	6: ["YOU THINK#IS THIS AN#END?", "TIME TO REAL#BATTLE!"],        # boss_7_end_talk
	7: ["OHHHH NOOOOO!", "NOOOOO!!!!", "ARGHHHHH!!"],                # boss_8_end_talk_2
}

const END_TALK_55 := [   # boss_55_end_talk — the bonus rematch boss
	"WHAT THE HELL?!",
	"AGAIN?!",
	"I'VE BEEN#DEFEATED#FOR THE FIVTH#TIME!!!#ARGHHH!",
	"#WE SHALL MEET#AGAIN ON THE#NEXT MAP AND#MY ARMY WILL#CRUSH YOU#LIKE A BUG",
	"SEE YOU SOON#",
]


## Defeat lines for a boss — empty for tiers without authored end talk.
static func for_end(tier: int, variant: String) -> Array:
	if variant == "flame_cans" and tier >= 5:
		return END_TALK_55
	return END_TALK.get(tier, [])


## Lines for a boss fight — variant speech wins, else the tier's
## clown dialogue. Missing tiers reuse the closest authored script.
static func for_boss(tier: int, variant: String, hero_name: String) -> Array:
	var lines: Array = BY_VARIANT.get(variant, [])
	if lines.is_empty():
		match tier:
			0: lines = CLOWN_1
			1, 2: lines = CLOWN_UPGRADED
			4: lines = CLOWN_5
			5: lines = CLOWN_6
			7: lines = CASTLE_LORD
			_: lines = CLOWN_1
	var out: Array = []
	for line in lines:
		out.append(str(line) % hero_name if "%s" in str(line) else str(line))
	return out
