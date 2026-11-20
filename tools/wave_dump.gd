extends SceneTree
var R = load("res://engine/r.gd")
var frames := 0
var dumped := false
func _initialize() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var G = load("res://game/globals.gd")
		R.aset(G.map_number, 0, 0)
		G.aktualny_lev = 2
		R.aset(G.map_zmien_etap, 0, 0)
		R.pending_room = 2
	if frames == 40 and not dumped:
		dumped = true
		var G = load("res://game/globals.gd")
		var sp = null
		for inst in R.instances:
			if inst.alive and inst.g_object_index == 532:
				sp = inst
		print("GLOBALS map_number=%s aktualny_lev=%s zmien_etap=%s pauza=%s" % [
			str(R.aget(G.map_number,0)), str(G.aktualny_lev), str(R.aget(G.map_zmien_etap,0)), str(G.pauza)])
		if sp != null:
			var sched := []
			for i in range(0, 120):
				var v = R.aget2(sp.g_perioder, 0, i)
				if v != null and int(v) != 0:
					sched.append("%d:%d" % [i, int(v)])
			print("SCHEDULE etap0 nonzero(idx:type) = %s" % str(sched))
			print("PERIODTIME=%s booster=%s" % [str(R.inst_get(sp.g_id,"periodtime")), str(R.inst_get(sp.g_id,"periodbooster"))])
	if frames >= 60:
		quit(); return true
	return false