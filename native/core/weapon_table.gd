extends RefCounted
class_name NativeWeaponTable
## NativeWeaponTable - the purchasable weapon catalog.
##
## Ported 1:1 from script_set_weapons in game/scripts/part_5_8.gd
## (the original builds G.shoptype/shopfirepower/shopoverheat/
## shopfirerate/shopcost/upgradecost arrays here at hero select).
##
## Field notes (original semantics):
##   fp/oh/fr  - base firepower / overheat-per-shot / charge frames
##               needed (HIGHER fr = SLOWER weapon; charge builds
##               (1 + samus_firerate)/frame)
##   multi     - projectiles per trigger pull
##   rate      - G.shoprateudawacz, rotary-burst flag
##   add       - special flags: AUTO-TARGETING, EXPLOSIVE AMMO,
##               CREATE COINS, ONLY FORWARD SHOTS
##   cost      - base coin price before samus_overpriced markup
##   upcost    - coin cost per upgrade level
##   *_per     - stat gained/LOST per upgrade level
##               (fr_per SUBTRACTS from the fire delay)

const WEAPONS := [
	{"name": "SMALL BALL LAUNCHER", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 1.0, "fr": 40.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 0, "upcost": 100.0, "fp_per": 0.1, "oh_per": 0.1, "fr_per": 1.0, "desc": "THE WORST WEAPON EVER MADE. # WELL BUT WHATEVER IT HAVE NICE LOW PRICE - IT'S FREE.\""},
	{"name": "LIGHT MUSHROOM GUN", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 1.0, "fr": 20.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 10000, "upcost": 100.0, "fp_per": 0.1, "oh_per": 0.1, "fr_per": 1.0, "desc": "THIRD CLASS WEAPON, IT'S ECONOMICALLY WELL BALANCED EASY TO USE# BUT IT HAS LIMITED AND LACK FIREPOWER.GOOD CH"},
	{"name": "MEDIUM MUSHROOM GUN 2", "type": "SINGLE SHOT WEAPON", "fp": 3.0, "oh": 3.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 15000, "upcost": 125.0, "fp_per": 0.3, "oh_per": 0.7, "fr_per": 0.85, "desc": "THE SECOUND VERSION OF THIRD CLASS WEAPON, IT'S ECONOMICALLY WELL BALANCED EASY TO# USE BUT IT HAS LIMITED AND"},
	{"name": "ENCHANCED MUSHROOM GUN 3", "type": "SINGLE SHOT WEAPON", "fp": 4.0, "oh": 4.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 20000, "upcost": 150.0, "fp_per": 0.4, "oh_per": 0.9, "fr_per": 0.7, "desc": "THE THIRD AND THE LAST VERSION OF SINGLE SHOOTING MUSHROOM GUN# IT'S ECONOMICALLY WELL BALANCED EASY TO# USE B"},
	{"name": "TRIPLER", "type": "MULTI SHOT WEAPON", "fp": 2.0, "oh": 4.0, "fr": 40.0, "multi": 3, "rate": 0.0, "add": "N/A", "cost": 15000, "upcost": 150.0, "fp_per": 0.2, "oh_per": 0.3, "fr_per": 1.0, "desc": "THIS WEAPON SHOOTS BLUE BULLETS IN THREE WAY.# MOSTLY USED BY PILOTS WHICH LIKES WEAPONS WITH GREATER RANGE OF"},
	{"name": "MINI-MINI MINIGUN", "type": "SINGLE SHOT WEAPON", "fp": 0.4, "oh": 1.0, "fr": 8.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 15000, "upcost": 100.0, "fp_per": 0.1, "oh_per": 0.2, "fr_per": 0.2, "desc": "WELL, THIS IS A SMALLER VERSION OF A MINIGUN# ESPECIALLY WAS DESIGNED AND MINIATURIZED FOR SPACE HODDOG BARS# "},
	{"name": "LINEAR SHOTGUN", "type": "MULTI SHOT WEAPON", "fp": 1.0, "oh": 10.0, "fr": 40.0, "multi": 4, "rate": 0.0, "add": "N/A", "cost": 25000, "upcost": 100.0, "fp_per": 0.1, "oh_per": 1.2, "fr_per": 1.0, "desc": "LINEAR SHOTGUN IS AN ADVANCED VERSION OF STANDART MUSHROOM GUN.# IT SHOTS FIVE BULLETS AT ONCE: FOUR SMALL AND"},
	{"name": "FROZEN BALL GUN", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 0.0, "fr": 20.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 25000, "upcost": 250.0, "fp_per": 0.3, "oh_per": 0.0, "fr_per": 0.2, "desc": "CHEAP TOY GUN SHOOTS SMALL PLASMA BALLS MADE OF HYDROGEN FROZEN# TO ABSOLUTE ZERO. THE GUN DOESN'T CAUSE ANY C"},
	{"name": "FROZEN BALL GUN MK2", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 0.0, "fr": 25.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 54000, "upcost": 500.0, "fp_per": 0.6, "oh_per": 0.0, "fr_per": 0.5, "desc": "ADVANCED VERSION OF FROZEN BALL GUN. PLASMA BALLS MADE# OF HYDROGEN FROZEN TO ABSOLUTE ZERO. THIS GUN MAKES MU"},
	{"name": "AUTOTRACK AUTO-GUN", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 2.0, "fr": 15.0, "multi": 1, "rate": 0.0, "add": "INCLUDE AUTO-TARGETING", "cost": 10000, "upcost": 1500.0, "fp_per": 0.1, "oh_per": 0.1, "fr_per": 1.0, "desc": "IF YOU NEED WEAPON WHICH WILL AUTO-ATTACK YOUR ENEMIES YOU WILL NEED THIS.# IT'S EASY TO AIM BUT IT CAUSE LOW "},
	{"name": "MULTIGUN", "type": "MULTI SHOT WEAPON", "fp": 2.0, "oh": 2.0, "fr": 20.0, "multi": 2, "rate": 2.0, "add": "N/A", "cost": 30000, "upcost": 500.0, "fp_per": 0.3, "oh_per": 0.5, "fr_per": 1.0, "desc": "SOME MUSHROOM ENGINEERING COMPANY TRIED TO MAKE AUTOMATIC MUSHROOM GUN# THIS PROJECT WAS A QUITE HARD TO COMPL"},
	{"name": "CHAOTICUS", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 2.0, "fr": 20.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 15000, "upcost": 150.0, "fp_per": 0.5, "oh_per": 0.5, "fr_per": 1.5, "desc": "THIS WEAPON WAS MADE BY CRAZY SCIENTIST. IT PROBABLY DAMAGED LOCAL LABORATORY.\""},
	{"name": "SMALL BALL LAUNCHER MK2", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 4.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 40000, "upcost": 400.0, "fp_per": 1.0, "oh_per": 0.1, "fr_per": 0.0, "desc": "THE OLDER BROTHER OF BALL LAUNCHER. SOME TOAD SCIENCISTS# WERE WONDERING HOW TO IMPROVE THIS WEAPON, AND THEY "},
	{"name": "MOSQUITO KILLER", "type": "MULTI SHOT WEAPON", "fp": 1.0, "oh": 1.0, "fr": 10.0, "multi": 2, "rate": 0.0, "add": "ROTARY DOUBLE MINIGUN", "cost": 50000, "upcost": 1000.0, "fp_per": 0.2, "oh_per": 0.0, "fr_per": 0.4, "desc": "WELL, THIS IS VERY INTERESTING WEAPON, DESIGNED BY TOADS LIVING IN SWAMPS IN MUSCHROOM#KINGDOM. AS WE KNOW SWA"},
	{"name": "MOSQUITO KILLER MK 1000", "type": "MULTI SHOT WEAPON", "fp": 4.0, "oh": 10.0, "fr": 20.0, "multi": 4, "rate": 0.0, "add": "ROTARY DOUBLE MINIGUN", "cost": 100000, "upcost": 25000.0, "fp_per": 0.0, "oh_per": 1.0, "fr_per": 1.5, "desc": "I CAN'T EXPLAIN WHY THE AUTHOR OF THIS GAME PLACED THIS WEAPON SO EARLY #BECAUSE IT'S SO EXPENSIVE AT THIS LEV"},
	{"name": "PHOTON", "type": "SINGLE SHOT WEAPON", "fp": 20.0, "oh": 20.0, "fr": 60.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 55000, "upcost": 1000.0, "fp_per": 1.0, "oh_per": 1.2, "fr_per": 1.0, "desc": "BEST FROM MUSHROOM TECHNOLOGY, NOBODY EVER REACHED HIGHER FIREPOWER# IF IT'S ABOUT MUSHROOM TECHNOLOGY.#FIREPO"},
	{"name": "PHOTON CIRCLES", "type": "SINGLE SHOT WEAPON", "fp": 8.0, "oh": 1.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "ONLY FORWARD SHOTS", "cost": 50000, "upcost": 1100.0, "fp_per": 0.5, "oh_per": 0.2, "fr_per": 1.5, "desc": "CHEAP WEAPON WITH VERY NICE FIREPOWER.# ALL NEEDLESS SYSTEMS HAVE BEEN DISMOUNTED TO RECEIVE MINIMAL LEVEL OF "},
	{"name": "GOLD GUN", "type": "MISC WEAPON", "fp": 7.0, "oh": 2.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "CREATE COINS", "cost": 120000, "upcost": 1200.0, "fp_per": 1.2, "oh_per": 1.0, "fr_per": 1.0, "desc": "IT'S A OBVIOUS AS IN A TOAD SOCIETY CAN BE #FOUND AT LEAST ONE SCROOGE! YOU WON'T BELIVE HOW THEY INVESTING MO"},
	{"name": "LIGHT MINIGUN", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 4.0, "fr": 15.0, "multi": 1, "rate": 2.0, "add": "N/A", "cost": 90000, "upcost": 1000.0, "fp_per": 0.4, "oh_per": 0.5, "fr_per": 0.7, "desc": "FIRST VERSION OF MINIGUN FOR PLUMBERS. NOT LOW PRICE BUT WORTH OF SACRIFICE!\""},
	{"name": "MUSCHROOM SHOTGUN", "type": "SPREAD SHOT WEAPON", "fp": 3.0, "oh": 20.0, "fr": 60.0, "multi": 8, "rate": 0.0, "add": "N/A", "cost": 120000, "upcost": 1000.0, "fp_per": 0.35, "oh_per": 2.0, "fr_per": 2.5, "desc": "SOMEONE TOLD: 'I DON'T NEED TO AIM CAUSE I CAN SHOOT 8 BULLETS # AT ONCE AND PROBABLY ONE OF THIS BULLET WONT "},
	{"name": "STEEL MUSCHROOM SHOTGUN", "type": "SPREAD SHOT WEAPON", "fp": 1.0, "oh": 20.0, "fr": 100.0, "multi": 16, "rate": 0.0, "add": "N/A", "cost": 105000, "upcost": 1000.0, "fp_per": 0.3, "oh_per": 3.0, "fr_per": 2.0, "desc": "THIS IS SHOTGUN HAVE MORE LESS ACCURACY THAN STANDART# MUSCHROOM SHOTGUN BUT IT FIRING MUCH MORE BULLETS AT ON"},
	{"name": "SIDE GUN", "type": "SIDE SHOT WEAPON", "fp": 5.0, "oh": 3.0, "fr": 30.0, "multi": 2, "rate": 0.0, "add": "N/A", "cost": 75000, "upcost": 2000.0, "fp_per": 0.5, "oh_per": 0.5, "fr_per": 1.0, "desc": "FOR PILOTS WHO WANT TO DEFEND SHIP FROM INVADERS AT SIDE OF THE SPACESHIP.\""},
	{"name": "PHASE CANNON", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 20.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "ONLY FORWARD SHOTS", "cost": 150000, "upcost": 1500.0, "fp_per": 3.0, "oh_per": 4.0, "fr_per": 1.0, "desc": "THIS WEAPON HAS BEEN MADE FOR AN OBLITERATORY ORGANIZATION. # SEEMINGLY THEY DESTROYED THEMSELVES WHEN THEY TR"},
	{"name": "ISOMATIC CANNON", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 40.0, "fr": 60.0, "multi": 5, "rate": 0.0, "add": "EXPLOSIVE AMMO", "cost": 150000, "upcost": 4000.0, "fp_per": 1.0, "oh_per": 2.0, "fr_per": 1.0, "desc": "WEIRD WEAPON WHICH HAVE BEEN FOUND IN FARAWAY GALAXY IN A RUINS OF A HUGE ALIEN SHIP. # PROBABLY IT'S BETTER T"},
	{"name": "AUTO-TRACK LUIGI MINIGUN", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 4.0, "fr": 15.0, "multi": 1, "rate": 3.0, "add": "INCLUDE AUTO-TARGETING", "cost": 150000, "upcost": 2000.0, "fp_per": 0.3, "oh_per": 0.5, "fr_per": 1.0, "desc": "LUIGY THE BROTHER OF MARIO HAVE DESIGNED HIGHLY ACCURATLIVE MINIGUN WITH AUTO# TARGETING SYSTEM. AS WE KNOW LU"},
	{"name": "CONTRA S WEAPON", "type": "MULTISHOT SHOT WEAPON", "fp": 2.0, "oh": 20.0, "fr": 80.0, "multi": 5, "rate": 0.0, "add": "N/A", "cost": 210000, "upcost": 2500.0, "fp_per": 1.2, "oh_per": 2.0, "fr_per": 4.0, "desc": "WELL, HAVE YOU EVER WANTED TO USE BEST WEAPON FROM CONTRA GAME FROM KONAMI IN#OTHER GAME? NOW YOU HAVE CHANCE "},
	{"name": "SIDE GUN MK2", "type": "SIDE SHOT WEAPON", "fp": 5.0, "oh": 5.0, "fr": 30.0, "multi": 2, "rate": 0.0, "add": "N/A", "cost": 250000, "upcost": 3000.0, "fp_per": 1.0, "oh_per": 0.5, "fr_per": 1.5, "desc": "SECOUND VERSION OF SIDEGUN WITH ENCHANCED FIREPOWER AND FIRERATE.\""},
	{"name": "HEAVY MINIGUN", "type": "SINGLE SHOT WEAPON", "fp": 6.0, "oh": 6.0, "fr": 12.0, "multi": 1, "rate": 4.0, "add": "N/A", "cost": 250000, "upcost": 4000.0, "fp_per": 0.1, "oh_per": 0.5, "fr_per": 0.5, "desc": "NEXT VERSION OF HEAVY MINIGUN. ASK YOUR BUDDIES FOR HELP BECAUSE # IT'S TOO HEAVY TO PICK IT UP ALONE AND MOUN"},
	{"name": "ASSAULT LASER", "type": "SINGLE SHOT WEAPON", "fp": 30.0, "oh": 30.0, "fr": 40.0, "multi": 1, "rate": 1.0, "add": "N/A", "cost": 400000, "upcost": 4000.0, "fp_per": 2.5, "oh_per": 2.0, "fr_per": 0.5, "desc": "FROM MUSCHROOM LASER INDUSTRY. THEY DESIGNED A NEW FORM OF ENERGY#THE DESTRUCTIVE LASER LIGHT, CONDENSED ENERG"},
	{"name": "LASER TRACKER SYSTEM", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 5.0, "fr": 30.0, "multi": 1, "rate": 0.0, "add": "INCLUDE ABSOLUTE AUTO-TARGETING", "cost": 720000, "upcost": 10000.0, "fp_per": 3.0, "oh_per": 2.0, "fr_per": 0.0, "desc": "NEXT AUTOTRACK WEAPON. BUT NOW THERE IS A PHASE ENERGY INSTEAD OF PROJECTILES. # PHASE ENERGY WILL NEVER MISS!"},
	{"name": "SIDER-X", "type": "SIDE SHOT WEAPON", "fp": 2.0, "oh": 5.0, "fr": 15.0, "multi": 4, "rate": 0.0, "add": "N/A", "cost": 350000, "upcost": 5000.0, "fp_per": 1.4, "oh_per": 0.5, "fr_per": 0.3, "desc": "NEXT INTERESTING WEAPON FOR THAT WHO WANT TO DEFEND ON BOTH SIDES OF SHIP. # BUT NOW IT'S BETTER, BIGGER AND B"},
	{"name": "MUSCHROOM SHOTGUN MK1000", "type": "SPREAD SHOT WEAPON", "fp": 2.0, "oh": 15.0, "fr": 60.0, "multi": 8, "rate": 0.0, "add": "N/A", "cost": 700000, "upcost": 10000.0, "fp_per": 0.3, "oh_per": 0.5, "fr_per": 4.0, "desc": "THE MOST DANGEROUS SHOTGUN IN MUSCHROOM KINGDOM!\""},
	{"name": "RED RADIATOR BEAM", "type": "MULTISHOT WEAPON", "fp": 15.0, "oh": 10.0, "fr": 20.0, "multi": 2, "rate": 0.0, "add": "N/A", "cost": 1200000, "upcost": 10000.0, "fp_per": 0.0, "oh_per": 1.5, "fr_per": 0.4, "desc": "UPGRADED VERSION OF RADIATOR. IT SHOOTS TWO BULLETS OF RED PHASE WHICH PILOT # CAN CONTROL FOR A WHILE WHEN TH"},
	{"name": "MAGMA", "type": "SINGLE SHOT WEAPON", "fp": 60.0, "oh": 100.0, "fr": 80.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 850000, "upcost": 20000.0, "fp_per": 5.0, "oh_per": 10.0, "fr_per": 0.0, "desc": "SCIENTISTS FROM MUSHROOM KINGDOM NEVER DREAMED ABOUT SUCH RESULTS # OF HIGH FIREPOWER... AND PILOTS NEVER DREA"},
	{"name": "HEAVY LASER CANNON", "type": "SINGLE SHOT WEAPON", "fp": 60.0, "oh": 60.0, "fr": 45.0, "multi": 1, "rate": 1.0, "add": "N/A", "cost": 800000, "upcost": 10000.0, "fp_per": 4.0, "oh_per": 2.0, "fr_per": 0.5, "desc": "MUCH HEAVIER VERSION OF STANDART ASSAULT LASER. WITH HIGHLY INCREASED FIREPOWER!\""},
	{"name": "ORBITAL LASER CANNON", "type": "SINGLE SHOT WEAPON", "fp": 80.0, "oh": 120.0, "fr": 60.0, "multi": 1, "rate": 1.0, "add": "N/A", "cost": 1200000, "upcost": 20000.0, "fp_per": 12.0, "oh_per": 4.0, "fr_per": 0.5, "desc": "OH MY GOD! IT NEEDS TWO HAUNDRETS OF NUCLEAR PLANTS TO#USE THIS WEAPON! IT'S FIREPOWER INQUESTIONABLE!!!\""},
	{"name": "DOUBLE ASSAULT MACHINEGUN", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 10.0, "fr": 11.0, "multi": 1, "rate": 5.0, "add": "N/A", "cost": 1200000, "upcost": 20000.0, "fp_per": 0.5, "oh_per": 0.5, "fr_per": 0.5, "desc": "YOU CAN PUT TWO MINIGUNS INSTEAD OF ONE! # HOPE YOUR WINGS WILL HANDLE THAT CAUSE WEIGHT IS BIG, BUT PRICE IS "},
	{"name": "SIDE SPREADER", "type": "MULTI-SIDE SHOT WEAPON", "fp": 5.0, "oh": 15.0, "fr": 6.0, "multi": 20, "rate": 0.0, "add": "N/A", "cost": 1500000, "upcost": 25000.0, "fp_per": 1.0, "oh_per": 1.0, "fr_per": 0.0, "desc": "A SPRAY OF HIGH ENERGY BULLETS FROM A SIDE OF SHIP.\""},
	{"name": "MUSHROM ACCELERATOR", "type": "MULTISHOT SHOT WEAPON", "fp": 10.0, "oh": 65.0, "fr": 60.0, "multi": 2, "rate": 0.0, "add": "SMALL TARGETING ALLOWED", "cost": 2000000, "upcost": 30000.0, "fp_per": 10.0, "oh_per": 7.0, "fr_per": 1.0, "desc": "APPARENTLY BOWSER WAS WORKING AT THIS WEAPON BUT HE THREW OUT THIS # PROJECT FOR TECHNOLOGY OF SOUCE FOR PASTA"},
	{"name": "SUPER AUTOBEAM CANNON", "type": "SINGLE SHOT WEAPON", "fp": 10.0, "oh": 10.0, "fr": 10.0, "multi": 2, "rate": 0.0, "add": "N/A", "cost": 2500000, "upcost": 40000.0, "fp_per": 2.0, "oh_per": 5.0, "fr_per": 0.5, "desc": "POWERFUL WEAPON - POWERFUL PRICE!\""},
	{"name": "GIANT MINIGUN", "type": "SINGLE SHOT WEAPON", "fp": 1.0, "oh": 20.0, "fr": 20.0, "multi": 20, "rate": 12.0, "add": "N/A", "cost": 3500000, "upcost": 40000.0, "fp_per": 1.5, "oh_per": 2.0, "fr_per": 1.4, "desc": "AS WE CAN SEE SCIENTIST INSTEAD OF SLEEPING INVENT MORE AND MORE INTERESTING GUNS. # WELL FOR EXAMPLE THAT MIN"},
	{"name": "SPREADUS VON DE MEGA GUN", "type": "SINGLE SHOT WEAPON", "fp": 10.0, "oh": 5.0, "fr": 40.0, "multi": 10, "rate": 0.0, "add": "N/A", "cost": 4000000, "upcost": 40000.0, "fp_per": 1.0, "oh_per": 20.0, "fr_per": 1.0, "desc": "POWERFUL SPLASH WEAPON. # IT'S INVENTOR WAS PROBABLY BASING ON A GUN FROM CONTRA GAME BY KONAMJI.\""},
	{"name": "MARIO'S DEVASTATOR", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 150.0, "fr": 20.0, "multi": 5, "rate": 0.0, "add": "N/A", "cost": 10000000, "upcost": 40000.0, "fp_per": 1.0, "oh_per": 30.0, "fr_per": 1.0, "desc": "THIS IS THE REAL KILLER. NO ONE WILL JUMP AT YOU NOW! # ONLY MARIO BROS CAN JUMP SO HIGH."},
]

## Super-weapons — ids 1000..1009, the original's charge/rocket series.
## Same shop stat fields as WEAPONS plus "proj", the projectile behaviour
## ported from objects/bullets/bullet_rockets_*.gd (fired via
## script_laser_1000..1008). Weapon 1009 (BIG DA ROCKA) exists in the
## catalog but the original has NO script_laser_1009 — it cannot fire.
const SUPER_WEAPONS := {
	1000: {"name": "SMALL ROCKETS", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 2.0, "fr": 120.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 25000, "upcost": 500.0, "fp_per": 1.2, "oh_per": 0.5, "fr_per": 1.0, "proj": "HOMING", "desc": "SMALL ROCKETS## SMALL HOMMING MISSILES WITH SMALL FIREPOWER."},
	1001: {"name": "RODEO ROCKET", "type": "SINGLE SHOT WEAPON", "fp": 5.0, "oh": 2.0, "fr": 80.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 25000, "upcost": 500.0, "fp_per": 1.0, "oh_per": 0.5, "fr_per": 1.0, "proj": "RODEO", "desc": "RODEO ROCKET## DRUNK ROCKETS FOR SOBER PILOTS."},
	1002: {"name": "BALLISTIC ROCKET", "type": "SINGLE SHOT WEAPON", "fp": 12.0, "oh": 2.0, "fr": 120.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 35000, "upcost": 500.0, "fp_per": 1.2, "oh_per": 0.5, "fr_per": 1.0, "proj": "HOMING_SLOW", "desc": "BALLISTIC ROCKET## ROCKET WITH IMPLOZION CHARGE - BIG FIREPOWER BUT SMALL AGILITY."},
	1003: {"name": "ROCKET SWARMS", "type": "SINGLE SHOT WEAPON", "fp": 2.0, "oh": 2.0, "fr": 60.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 40000, "upcost": 500.0, "fp_per": 0.6, "oh_per": 0.5, "fr_per": 1.0, "proj": "SWARM", "desc": "ROCKET SWARMS## YOU HAVE THOUGHT ABOUT SHOOTING FROM AUTOMATIC ROCKET GUN? YOU CAN TRY!"},
	1004: {"name": "BOUNCING WAR BALL", "type": "SINGLE SHOT WEAPON", "fp": 20.0, "oh": 1.0, "fr": 60.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 50000, "upcost": 1000.0, "fp_per": 2.0, "oh_per": 1.0, "fr_per": 1.0, "proj": "GRAVITY", "desc": "BOUNCING WAR BALL##A QUITE NON-CONVENTIONAL WEAPON."},
	1005: {"name": "SPREAD ROCKETS", "type": "SINGLE SHOT WEAPON", "fp": 15.0, "oh": 1.0, "fr": 50.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 70000, "upcost": 1500.0, "fp_per": 2.0, "oh_per": 1.0, "fr_per": 1.0, "proj": "HOMING_SHRAPNEL", "desc": "SPREAD ROCKETS## ROCKET WHICH MAKES A LOT BOOM WHEN IT HITS THE TARGET."},
	1006: {"name": "SHOOTING BALL", "type": "SINGLE SHOT WEAPON", "fp": 20.0, "oh": 1.0, "fr": 40.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 100000, "upcost": 2000.0, "fp_per": 2.0, "oh_per": 1.0, "fr_per": 1.0, "proj": "GRAVITY_BOUNCE", "desc": "SHOOTING BALL## NON-CONVENTIONAL WEAPON WHICH SHOOTS YOUR ENEMY ITSELF!"},
	1007: {"name": "SENTINEL", "type": "SINGLE SHOT WEAPON", "fp": 20.0, "oh": 1.0, "fr": 40.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 500000, "upcost": 5000.0, "fp_per": 2.0, "oh_per": 1.0, "fr_per": 1.0, "proj": "SENTINEL", "desc": "SENTINEL## IF YOU NEED WEAPON WHICH WILL THINK INSTEAD OF YOU JUST BUY THAT."},
	1008: {"name": "GUARDIAN", "type": "SINGLE SHOT WEAPON", "fp": 10.0, "oh": 1.0, "fr": 250.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 750000, "upcost": 5000.0, "fp_per": 1.0, "oh_per": 0.0, "fr_per": 1.0, "proj": "GUARDIAN", "desc": "GUARDIAN## LIKE SENTINEL BUT IT'S BETTER."},
	1009: {"name": "BIG DA ROCKA", "type": "SINGLE SHOT WEAPON", "fp": 10.0, "oh": 1.0, "fr": 250.0, "multi": 1, "rate": 0.0, "add": "N/A", "cost": 1500000, "upcost": 100000.0, "fp_per": 1.0, "oh_per": 0.0, "fr_per": 1.0, "proj": "NONE", "desc": "BIG DA ROCKA## OHH MY GOD! THIS ROCKET IS SO BIG! # MOMMA HOW AM I SUPPOSED TO SHOT THIS THING WITH MY SHIP?"},
}

## Max upgrade level per slot � the original shop caps at 10.
const MAX_LEVEL := 10

## Projectile sprite per weapon id — the first draw_sprite_ext sprite of
## the object each script_laser_<id> spawns (laserflash muzzle objects
## excluded). -1 = no dedicated sprite (default bolt art).
const WEAPON_SPRITES := {
	0: 407, 1: 12, 2: 12, 3: 12, 4: 12, 5: 12, 6: 12,
	7: 408, 8: 408, 9: 12, 10: 12, 11: 12, 12: 407,
	13: 409, 14: 409, 15: 75, 16: 55, 17: 438, 18: 207,
	19: 75, 20: 75, 21: 205, 22: 76, 23: 121, 24: 409,
	25: 407, 26: 410, 27: 207, 28: 411, 29: 205, 30: 205,
	31: 75, 32: 211, 33: 211, 34: 411, 35: 411, 36: 213,
	37: 75, 38: 75, 39: 211, 40: 215, 41: 211, 42: 216,
}


## Per-weapon projectile quirks, keyed by catalog id and taken from the
## projectile object each script_laser_<id> spawns (objects/bullets/):
##   wobble   — frozen_ball/frozen_ball_2 heading weave (deg/frame)
##   grow     — laser_u88/888/8888 scale growth per frame (default is
##              the shared 0.005 bolt stretch)
##   charge   — frames the bolt rides the muzzle before launch
##              (bullet_200/201/202/203, laser_u6/6plus/15/16/19)
##   homing   — LASER TRACKER's "absolute auto-targeting" phase beam
##   life     — frozen balls self-destruct after ~300 frames
const WEAPON_BEHAVIORS := {
	4: {"grow": 0.03},                          # TRIPLER -> laser_u88
	7: {"wobble": 0.5, "life": 300},            # FROZEN BALL GUN
	8: {"wobble": 0.5, "life": 300},            # FROZEN BALL GUN MK2
	13: {"grow": 0.05},                         # CHAOTICUS -> laser_u888
	14: {"grow": 0.05},                         # MOSQUITO KILLER -> u8888
	18: {"charge": 18},                         # LIGHT MINIGUN -> b_200
	21: {"charge": 12},                         # SIDE GUN -> laser_u6 x2
	26: {"charge": 12},                         # SIDE GUN MK2 -> u6plus
	27: {"charge": 18},                         # HEAVY MINIGUN -> b_201
	29: {"homing": 2.0},                        # LASER TRACKER SYSTEM
	36: {"charge": 18},                         # DOUBLE ASSAULT -> b_202
	39: {"charge": 15},                         # SUPER AUTOBEAM -> u19
	40: {"charge": 18},                         # GIANT MINIGUN -> b_203
	41: {"charge": 15},                         # SPREADUS -> laser_u15
	42: {"charge": 15},                         # MARIO'S DEVASTATOR -> u16
}


## Sprite id for a weapon's projectile, or -1 for the default bolt.
static func projectile_sprite(weapon_id: int) -> int:
	return WEAPON_SPRITES.get(weapon_id, -1)


## Projectile behavior flags for a catalog weapon id (empty = standard).
static func projectile_behavior(weapon_id: int) -> Dictionary:
	return WEAPON_BEHAVIORS.get(weapon_id, {})


static func at(id: int) -> Dictionary:
	if id >= 1000:
		return SUPER_WEAPONS.get(id, {})
	if id < 0 or id >= WEAPONS.size():
		return {}
	return WEAPONS[id]


## Every purchasable weapon id — standard catalog then the 1000-series,
## matching the original shop's armory page order.
static func catalog_ids() -> Array[int]:
	var ids: Array[int] = []
	for i in WEAPONS.size():
		ids.append(i)
	for id in SUPER_WEAPONS:
		ids.append(id)
	return ids


## Effective stats for a slot: base weapon stats scaled by the
## slot's upgrade level (G.levelup[slot]).
static func slot_stats(slot_level: int, weapon_id: int) -> Dictionary:
	var w := at(weapon_id)
	if w.is_empty():
		return {}
	var lv := float(slot_level)
	return {
		"id": weapon_id,
		"proj": w.get("proj", ""),
		"damage": w["fp"] + lv * w["fp_per"],
		"overheat": w["oh"] + lv * w["oh_per"],
		"delay": maxf(1.0, w["fr"] - lv * w["fr_per"]),
		"multi": w["multi"],
		"type": w["type"],
		"add": w["add"],
		"rate": w["rate"],
	}
