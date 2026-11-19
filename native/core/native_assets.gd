extends RefCounted
class_name NativeAssets
## NativeAssets — asset manifest access for the native game.
##
## Wraps data/assets.json (the original GameMaker sprite/sound table) behind
## typed static functions so entities never deal with file naming. The
## manifest is parsed lazily on first use and textures/streams are cached.
##
## Equivalent of the loader inside engine/r.gd, minus the GM compatibility
## baggage.

const MANIFEST_PATH := "res://data/assets.json"

static var _manifest: Dictionary = {}
static var _loaded := false
static var _texture_cache: Dictionary = {}
static var _stream_cache: Dictionary = {}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("NativeAssets: cannot open " + MANIFEST_PATH)
		return
	_manifest = JSON.parse_string(f.get_as_text())
	if _manifest.is_empty():
		push_error("NativeAssets: failed to parse " + MANIFEST_PATH)


# ---------------------------------------------------------------------------
# Sprites
# ---------------------------------------------------------------------------

## Info record for a sprite index: {name, origin:Vector2, frame_count:int}.
static func sprite_info(sprite_id: int) -> Dictionary:
	_ensure_loaded()
	var s: Variant = _manifest.get("sprites", {}).get(str(sprite_id))
	if s == null:
		return {}
	var origin: Array = s.get("origin", [0, 0])
	return {
		"name": s.get("name", ""),
		"origin": Vector2(origin[0], origin[1]),
		"frame_count": (s.get("frames", []) as Array).size(),
	}


## Texture for one frame of a sprite. Cached — the same frames are requested
## every time an entity animates.
static func sprite_frame(sprite_id: int, frame: int) -> Texture2D:
	_ensure_loaded()
	var key := "%d:%d" % [sprite_id, frame]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var frames: Array = _manifest.get("sprites", {}).get(str(sprite_id), {}).get("frames", [])
	if frame < 0 or frame >= frames.size():
		return null
	var tex: Texture2D = load(frames[frame])
	_texture_cache[key] = tex
	return tex


## All frames of a sprite — used to build AnimatedSprite2D SpriteFrames.
static func sprite_frames(sprite_id: int) -> Array[Texture2D]:
	var info := sprite_info(sprite_id)
	var out: Array[Texture2D] = []
	for i in info.get("frame_count", 0):
		var t := sprite_frame(sprite_id, i)
		if t != null:
			out.append(t)
	return out


## Sprite origin (pivot). GameMaker draws sprites relative to this point,
## so native sprites must use the same offset to keep positions identical.
static func sprite_origin(sprite_id: int) -> Vector2:
	return sprite_info(sprite_id).get("origin", Vector2.ZERO)


# ---------------------------------------------------------------------------
# Backgrounds
# ---------------------------------------------------------------------------

static func background(background_id: int, frame: int = 0) -> Texture2D:
	_ensure_loaded()
	var frames: Array = _manifest.get("backgrounds", {}).get(str(background_id), {}).get("frames", [])
	if frame < 0 or frame >= frames.size():
		return null
	return load(frames[frame])


# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

## Sound effect by numeric id (ids used throughout the original scripts).
static func sound(sound_id: int) -> AudioStream:
	_ensure_loaded()
	# Some manifest entries are null placeholders — treat them as missing.
	var path_v: Variant = _manifest.get("sounds", {}).get(str(sound_id))
	if path_v == null:
		return null
	var path: String = path_v
	if path == "":
		return null
	if not _stream_cache.has(path):
		_stream_cache[path] = load(path)
	return _stream_cache[path]


## Music tracks live in res://data/m/<name>.ogg, referenced by name.
static func music(track_name: String) -> AudioStream:
	var path := "res://data/m/%s.ogg" % track_name
	if not _stream_cache.has(path):
		_stream_cache[path] = load(path)
	return _stream_cache[path]
