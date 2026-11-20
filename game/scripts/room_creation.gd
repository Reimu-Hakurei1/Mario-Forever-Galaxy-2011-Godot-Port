extends RefCounted

## Auto-generated room creation functions from levels/*.json creation_code
## Regenerated to fix missing room_create entries in registry

static func room_2(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	R.instance_create(S, 1024, 600, 3)  # o_hud
	R.instance_create(S, 0, 0, 532)  # o_przeciwnikor
	R.instance_create(S, -1000, -1000, 365)  # o_bonusho
	R.instance_create(S, 400, 300, 136)  # o_gameoverus
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_5(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_12(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap2.jpg',0,...
	# TODO: background_replace(background0,'gfx/map/newmap2.jp...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_18(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/s_map_back.jpg'...
	# TODO: background_replace(background0,'gfx/map/background...
	# TODO: background_replace(background48,'gfx/map/s_map_bac...
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_21(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap4.jpg',0,...
	# TODO: background_replace(background48,'gfx/map/newmap4.j...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_25(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap5.jpg',0,...
	# TODO: background_replace(background48,'gfx/map/newmap5.j...
	# TODO: background_replace(background52,'gfx/map/flooder.j...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_29(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap6.jpg',0,...
	# TODO: background_replace(background48,'gfx/map/newmap6.j...
	# TODO: background_replace(background52,'gfx/map/flooder.j...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_34(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap7.jpg',0,...
	# TODO: background_replace(background48,'gfx/map/newmap7.j...
	# TODO: background_replace(background52,'gfx/map/flooder.j...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_41(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	G.map_1_assigned = 0
	G.aktualny_lev = 0
	# TODO: sprite_replace(s_map_back,'gfx/map/newmap8.jpg',0,...
	# TODO: background_replace(background48,'gfx/map/newmap8.j...
	# TODO: background_replace(background52,'gfx/map/flooder.j...
	G.particle_map_goodies = part_system_create()
	G.particle_map_goodies2 = part_system_create()
	G.particle_map_trail = part_type_create()
	G.particle_map_trail2 = part_type_create()
	G.map_level_numering = 0
	level_waves.end_event(R)
	return 0

static func room_46(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	level_waves.end_event(R)
	return 0

static func room_0(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	level_waves.end_event(R)
	return 0

static func room_51(S, A: Array) -> Variant:
	level_waves.begin_event(S)
	R.instance_create(S, 160, 330, 123)  # o_titler1
	R.instance_create(S, 160, 352, 137)  # o_titler2
	R.instance_create(S, 160, 400, 138)  # o_titler3
	R.instance_create(S, 0, 283, 52)  # o_blur_1
	R.instance_create(S, 0, 560, 53)  # o_blur_2
	R.instance_create(S, 800, 500, 54)  # o_blur_3
	R.instance_create(S, 0, 0, 55)  # o_title_screen
	level_waves.end_event(R)
	return 0
