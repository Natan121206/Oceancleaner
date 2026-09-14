extends Node
## Habilidade "Mordida": ataque corpo-a-corpo automático no inimigo mais
## próximo, em intervalos regulares. Reaproveita a animação/AttackArea
## que já existem no player.

@export var cooldown: float = 1.1
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

	player.perform_bite_attack(alvo.global_position)
