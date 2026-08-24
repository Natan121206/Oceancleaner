extends CharacterBody2D
class_name Inimigo

signal died

# ==============================
#  INIMIGO - Máquina de Estados
# ==============================
# Estados possíveis do inimigo
enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

# ------------------------------
# Propriedades configuráveis (Stats)
# ------------------------------
@export_category("Stats")
@export var max_health: int = 30
@export var speed: float = 90.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0 # tempo entre ataques

@export_category("IA")
@export var detection_range: float = 800.0 # distância pra começar a perseguir
@export var attack_range: float = 75.0     # distância pra parar e atacar (> soma dos raios de colisão do player+inimigo, senão a física nunca deixa eles chegarem perto o suficiente)

# ------------------------------
# Variáveis de controle
# ------------------------------
var health: int
var state: State = State.IDLE
var player: Node2D = null
var can_attack: bool = true    # se já passou o cooldown do golpe anterior
var is_attacking: bool = false # se está NO MEIO da animação de ataque agora

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var som_morte: AudioStreamPlayer2D = $SomMorte


func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	# Procura o player pela group "player" (o player.gd já se registra nela)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	animation_player.play("idle")


func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return

	if player == null or not is_instance_valid(player):
		_stop_and_idle()
		return

	var distance: float = global_position.distance_to(player.global_position)

	# Enquanto o golpe está de fato acontecendo, só fica parado encarando o player
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_face_target(player.global_position)
		return

	if distance <= attack_range:
		# Perto o suficiente: para e ataca (se não estiver em cooldown)
		velocity = Vector2.ZERO
		move_and_slide()
		_face_target(player.global_position)
		state = State.IDLE
		if animation_player.current_animation != "idle":
			animation_player.play("idle")
		if can_attack:
			_enter_attack()
	elif distance <= detection_range:
		state = State.CHASE
		_chase_player()
	else:
		_stop_and_idle()


# ------------------------------
# Movimento
# ------------------------------
func _chase_player() -> void:
	var direction: Vector2 = global_position.direction_to(player.global_position)
	velocity = direction * speed
	move_and_slide()
	_face_target(player.global_position)

	if animation_player.current_animation != "walk":
		animation_player.play("walk")


func _stop_and_idle() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	move_and_slide()
	if animation_player.current_animation != "idle":
		animation_player.play("idle")


func _face_target(target_position: Vector2) -> void:
	sprite.flip_h = target_position.x < global_position.x


# ------------------------------
# Ataque
# ------------------------------
func _enter_attack() -> void:
	# Trava de reentrância: nunca inicia um novo golpe se já tem um rolando
	if is_attacking:
		return

	is_attacking = true
	can_attack = false
	state = State.ATTACK
	animation_player.play("attack")

	# Momento de "impacto" do golpe (meio da animação de ataque)
	await get_tree().create_timer(0.25).timeout
	if state == State.DEAD:
		return
	_try_deal_damage()

	# Resto da animação antes de poder agir de novo
	await get_tree().create_timer(0.35).timeout
	is_attacking = false
	if state != State.DEAD:
		state = State.IDLE

	# Cooldown antes do próximo ataque
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _try_deal_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance <= attack_range + 10.0 and player.has_method("take_damage"):
		player.take_damage(damage)


# ------------------------------
# Receber dano / Morrer
# ------------------------------
func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health -= amount
	if health <= 0:
		health = 0
		_die()
	else:
		_flash_hit()


func _flash_hit() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(0.12).timeout
	if state != State.DEAD:
		modulate = Color(1, 1, 1)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	set_physics_process(false)

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	modulate = Color(1, 1, 1)
	died.emit()
	som_morte.play()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "scale", scale * 0.7, 0.5)
	# Não usamos queue_free() aqui: o inimigo faz parte de um pool reaproveitável
	# pelo GerenciadorInimigos, então só o escondemos para depois "renascer()".
	tween.finished.connect(hide)


# ------------------------------
# Renascer (chamado pelo Gerenciador de pool)
# ------------------------------
func renascer(posicao_spawn: Vector2, alvo: Node2D) -> void:
	global_position = posicao_spawn
	player = alvo

	health = max_health
	state = State.IDLE
	can_attack = true
	is_attacking = false
	velocity = Vector2.ZERO
	modulate = Color(1, 1, 1)
	scale = Vector2.ONE

	show()
	set_physics_process(true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	if animation_player:
		animation_player.play("idle")
