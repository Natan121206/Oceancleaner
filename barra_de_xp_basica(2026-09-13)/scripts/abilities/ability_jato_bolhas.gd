extends Node
## Habilidade "Jato de Bolhas": dispara um projétil em direção ao inimigo
## mais próximo, em intervalos regulares.

const BOLHA_SCENE := preload("res://scenes/abilities/bolha.tscn")

@export var cooldown: float = 1.6
@export var damage: int = 10
@export var projectile_speed: float = 420.0
@export var player_path: NodePath

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

	var alvo: Node2D = player.find_nearest_enemy()
	if alvo == null:
		return

	_disparar(alvo.global_position)


func _disparar(alvo_posicao: Vector2) -> void:
	var bolha := BOLHA_SCENE.instantiate()
	get_tree().current_scene.add_child(bolha)
	bolha.global_position = player.global_position
	bolha.damage = damage
	bolha.velocity = player.global_position.direction_to(alvo_posicao) * projectile_speed
