
extends CharacterBody2D
class_name Inimigo

signal died(inimigo: Inimigo)

# ==============================
# INIMIGO - Máquina de Estados
# ==============================
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
@export var attack_cooldown: float = 1.0

@export_category("Recompensas")
@export var xp_reward: int = 5

@export_category("IA")
# Distância máxima em que o inimigo enxerga o jogador. Muito alta = persegue de qualquer lugar do mapa.
@export var detection_range: float = 100000.0
@export var attack_range: float = 75.0

# ------------------------------
# Depuração
# ------------------------------
# Controlado pelo GerenciadorInimigos durante os testes.
var mostrar_numeros_dano: bool = false

# ------------------------------
# Variáveis de controle
# ------------------------------
var health: int
var state: State = State.IDLE
var player: Node2D = null
var can_attack: bool = true
var is_attacking: bool = false
# Stats originais (da cena), para a dificuldade sempre multiplicar a partir deles
var _vida_base: int = 0
var _velocidade_base: float = 0.0
var _dano_base: int = 0
var _tween_morte: Tween = null # animação de sumiço ao morrer (precisa ser cancelada ao renascer)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var som_morte: AudioStreamPlayer2D = $SomMorte


func _ready() -> void:
	_vida_base = max_health
	_dano_base = damage
	_velocidade_base = speed
	health = max_health
	add_to_group("enemies")

	# Procura o player pela group "player".
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	animation_player.play("idle")

	# Inimigo guardado no pool (escondido) não pode ser atingido nem bloquear ninguém
	if not visible:
		set_physics_process(false) # o Godot religa isso sozinho ao entrar na cena; desliga de novo
		if collision_shape:
			collision_shape.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return

	# Escondido = guardado no pool: não pode agir (se chegou aqui, o Godot tinha religado o processamento)
	if not visible:
		set_physics_process(false)
		return

	_garantir_visivel()

	if player == null or not is_instance_valid(player):
		_stop_and_idle()
		return

	var distance: float = global_position.distance_to(player.global_position)

	# Enquanto o golpe está acontecendo, fica parado encarando o player.
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_face_target(player.global_position)
		return

	if distance <= attack_range:
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


# Rede de segurança: um inimigo vivo e ativo nunca pode ficar transparente ou com escala errada.
# Se isso acontecer por algum motivo, corrige na hora e avisa na aba Saída (para investigar).
func _garantir_visivel() -> void:
	if modulate.a < 0.99:
		modulate.a = 1.0
		print("DEBUG: inimigo vivo estava TRANSPARENTE e foi corrigido: ", name)

	if not scale.is_equal_approx(Vector2.ONE):
		scale = Vector2.ONE
		print("DEBUG: inimigo vivo estava com ESCALA errada e foi corrigido: ", name)


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
	if is_attacking:
		return

	is_attacking = true
	can_attack = false
	state = State.ATTACK
	animation_player.play("attack")

	# Momento do impacto do golpe.
	await get_tree().create_timer(0.25).timeout

	if state == State.DEAD:
		return

	_try_deal_damage()

	# Resto da animação antes de poder agir novamente.
	await get_tree().create_timer(0.35).timeout
	is_attacking = false

	if state != State.DEAD:
		state = State.IDLE

	# Cooldown antes do próximo ataque.
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _try_deal_damage() -> void:
	if player == null or not is_instance_valid(player):
		return

	var distance: float = global_position.distance_to(player.global_position)

	if distance <= attack_range + 10.0 and player.has_method("take_damage"):
		player.take_damage(damage)


# ------------------------------
# Receber dano / Números flutuantes
# ------------------------------
func take_damage(amount: int) -> void:
	# Escondido = está guardado no pool, não pode levar dano nem "morrer" de novo
	if state == State.DEAD or amount <= 0 or not visible:
		return

	# Calcula quanto de vida o inimigo realmente perderá.
	var dano_aplicado: int = min(amount, health)

	if dano_aplicado <= 0:
		return

	health -= dano_aplicado

	# Exibe o valor real de vida removida, se a depuração estiver ativa.
	if mostrar_numeros_dano:
		_mostrar_numero_dano(dano_aplicado)

	if health <= 0:
		health = 0
		_die()
	else:
		_flash_hit()


func _mostrar_numero_dano(valor: int) -> void:
	var numero := Label.new()

	numero.text = str(valor)
	numero.add_theme_font_size_override("font_size", 20)
	numero.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	numero.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1.0))
	numero.add_theme_constant_override("outline_size", 4)
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numero.z_index = 100
	numero.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Define uma área para centralizar o texto no ponto de origem.
	numero.size = Vector2(80, 32)

	# Adiciona à cena principal para não acompanhar o movimento do inimigo.
	var cena_atual := get_tree().current_scene
	if cena_atual == null:
		numero.queue_free()
		return

	cena_atual.add_child(numero)

	numero.global_position = (
		global_position
		+ Vector2(randf_range(-15.0, 15.0), -25.0)
		- Vector2(40.0, 16.0)
	)

	# Animação: sobe e desaparece.
	var posicao_final: Vector2 = numero.global_position + Vector2(
		randf_range(-10.0, 10.0),
		-40.0
	)

	var tween := numero.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		numero,
		"global_position",
		posicao_final,
		0.65
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		numero,
		"modulate:a",
		0.0,
		0.65
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.set_parallel(false)
	tween.tween_callback(numero.queue_free)


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

	# Informa ao Gerenciador qual inimigo morreu.
	died.emit(self)

	som_morte.play()

	var tween := create_tween()
	_tween_morte = tween
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "scale", scale * 0.7, 0.5)

	# O inimigo pertence ao pool e será reaproveitado.
	tween.finished.connect(hide)


# ------------------------------
# Dificuldade progressiva (chamado pelo Gerenciador antes de renascer)
# ------------------------------
# Multiplicadores em relação aos stats originais da cena: 1.0 = normal, 1.5 = +50%.
func aplicar_dificuldade(mult_vida: float, mult_dano: float, mult_velocidade: float) -> void:
	max_health = maxi(1, roundi(_vida_base * mult_vida))
	damage = maxi(1, roundi(_dano_base * mult_dano))
	speed = _velocidade_base * mult_velocidade


# ------------------------------
# Renascer (chamado pelo Gerenciador de pool)
# ------------------------------
func renascer(posicao_spawn: Vector2, alvo: Node2D) -> void:
	# Cancela a animação de morte anterior: senão ela terminava DEPOIS de renascer,
	# deixando o inimigo transparente/escondido (invisível, mas ainda agindo).
	if _tween_morte and _tween_morte.is_valid():
		_tween_morte.kill()
	_tween_morte = null

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
