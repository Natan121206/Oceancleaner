extends Node2D
## Habilidade "Redemoinho": pulso de dano em área ao redor do tubarão,
## em intervalos regulares. Atinge todos os inimigos dentro do raio.

@export var cooldown: float = 2.6
@export var radius: float = 130.0
@export var damage: int = 12
@export var player_path: NodePath

const RING_TEXTURE := preload("res://assets/ui/ring_pulse.png")

@onready var player: CharacterBody2D = get_node(player_path)
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = cooldown
	timer.one_shot = false
	timer.timeout.connect(_on_timeout)
	timer.start()


func _on_timeout() -> void:
	if not is_instance_valid(player):
		return
	if player.is_dead():
		return

	_deal_damage()
	_spawn_visual()


func _deal_damage() -> void:
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not inimigo.visible:
			continue
		if global_position.distance_to(inimigo.global_position) <= radius:
			if inimigo.has_method("take_damage"):
				inimigo.take_damage(damage)


func _spawn_visual() -> void:
	var ring := Sprite2D.new()
	ring.texture = RING_TEXTURE
	ring.modulate = Color(0.35, 0.9, 0.9, 0.8)
	ring.global_position = global_position
	ring.z_index = 5
	ring.scale = Vector2(0.08, 0.08)
	get_tree().current_scene.add_child(ring)

	var target_scale: float = (radius * 2.0) / RING_TEXTURE.get_width()
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * target_scale, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)
