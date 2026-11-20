extends SceneTree
func _init():
	NativeAssets._ensure_loaded()
	var m: Dictionary = NativeAssets._manifest
	var spr: Dictionary = m.get("sprites", {})
	var ids := spr.keys()
	var bad := 0
	for i in mini(10, ids.size()):
		var frames: Array = spr[ids[i]].get("frames", [])
		if frames.is_empty(): continue
		if ResourceLoader.exists(frames[0]) == false:
			print("MISSING sprite ", ids[i], " ", frames[0]); bad += 1
	var snd: Dictionary = m.get("sounds", {})
	var sids := snd.keys()
	for i in mini(10, sids.size()):
		var p: String = snd[sids[i]]
		if p != "" and ResourceLoader.exists(p) == false:
			print("MISSING sound ", sids[i], " ", p); bad += 1
	print("music exists: ", ResourceLoader.exists("res://music/mixed_battle.ogg"))
	print("cutscene exists: ", ResourceLoader.exists("res://gfx/cutscene/anim_metroid_0.png"))
	print("bg exists: ", ResourceLoader.exists("res://gfx/backgrounds/background0.0.jpg"))
	print("map exists: ", ResourceLoader.exists("res://gfx/map/background000.jpg"))
	print("title exists: ", ResourceLoader.exists("res://gfx/title/gfx_1.jpg"))
	print("logo exists: ", ResourceLoader.exists("res://gfx/logo/anim_logo.png"))
	print("sfx exists: ", ResourceLoader.exists("res://sfx/boomerang1.ogg"))
	print("ASSET_CHECK bad=", bad)
	quit()
