class_name GMParticleLayer extends Node2D

## Draws one GameMaker particle system (or the built-in effect pool when sys_id is -1).
## Types with part_type_blend(...,1) go to a child canvas item using additive blending.

var sys_id: int = -1
var add_layer: Node2D = null


func _ready() -> void:
	if sys_id == -1:
		return
	add_layer = Node2D.new()
	add_layer.material = R.additive_material()
	add_layer.draw.connect(func() -> void: R.draw_particles(add_layer, sys_id, true))
	add_child(add_layer)


func redraw() -> void:
	queue_redraw()
	if add_layer != null:
		add_layer.queue_redraw()


func _draw() -> void:
	if sys_id == -1:
		R.draw_effects(self)
	else:
		R.draw_particles(self, sys_id, false)
