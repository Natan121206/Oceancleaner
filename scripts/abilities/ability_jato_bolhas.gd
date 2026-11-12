extends Node
## Habilidade "Jato de Bolhas": dispara um projétil em direção ao inimigo
## mais próximo, em intervalos regulares.

const BOLHA_SCENE := preload("res://scenes/abilities/bolha.tscn")

@export var cooldown: float = 1.6
@export var dano_proprio: int = 10
@export var projectile_speed: float = 420.0
@export var player_path: NodePath

# Aumentada pelo upgrade de alcance: projétil maior e que percorre mais distância
var escala_projetil: float = 1.0

@onready var player: Player = get_node(player_path) as Player
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

	# Só dispara depois de o jogador desbloquear este ataque
	if player.has_method("tem_ataque") and not player.tem_ataque("bolha"):
		return

	var alvo: Node2D = player.find_nearest_enemy()
	if alvo == null:
		return

	_disparar(alvo.global_position)


func _disparar(alvo_posicao: Vector2) -> void:
	if not is_instance_valid(player):
		return

	var bolha := BOLHA_SCENE.instantiate()

	bolha.scale = Vector2.ONE * escala_projetil
	bolha.lifetime *= escala_projetil

	get_tree().current_scene.add_child(bolha)

	bolha.global_position = player.global_position

	# Soma o dano base do Player ao dano próprio desta habilidade
	bolha.damage = player.attack_damage + dano_proprio

	# Define a direção e a velocidade do projétil
	bolha.velocity = (
		player.global_position.direction_to(alvo_posicao)
		* projectile_speed
	)
