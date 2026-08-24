class_name Player
extends CharacterBody2D # (ou Node2D, dependendo do seu nó raiz)

signal health_changed(current: int, max_amount: int)

# 1. Definição dos Estados
enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

# 2. Propriedades Configuráveis (Stats)
@export_category("Stats")
@export var speed: int = 200
@export var attack_duration: float = 0.6 # Duração de 0.6 segundos do ataque
@export var max_health: int = 100
@export var attack_damage: int = 15

# 3. Variáveis de Controle
var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var health: int

# 4. Referência Direta ao AnimationPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var som_ataque: AudioStreamPlayer2D = $SomAtaque
@onready var som_dano: AudioStreamPlayer2D = $SomDano
@onready var som_game_over: AudioStreamPlayer2D = $SomGameOver



func _ready() -> void:
	health = max_health
	add_to_group("player")
	health_changed.emit(health, max_health)

	# Mantém a AnimationTree desligada para usar o controle direto e seguro do AnimationPlayer
	if has_node("AnimationTree"):
		$AnimationTree.active = false


# 5. Loop de Física Principal
func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return

	# O personagem pode andar mesmo enquanto estiver atacando
	movement_loop()


# 6. Encontra o inimigo vivo mais próximo (usado pelas habilidades automáticas)
func find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not inimigo.visible:
			continue
		var dist: float = global_position.distance_to(inimigo.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = inimigo
	return nearest


# 6.1 Usado pelas habilidades automáticas para saber se ainda podem agir
func is_dead() -> bool:
	return state == State.DEAD


# 7. Lógica de Movimentação (Controlada apenas por WASD / Direcionais)
func movement_loop() -> void:
	# Lendo os comandos de movimento do teclado
	move_direction.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direction.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	
	var motion: Vector2 = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()

	# Altera a direção horizontal do sprite baseado em para onde ele está ANDANDO
	if move_direction.x < 0:
		$Sprite2D.flip_h = true
	elif move_direction.x > 0:
		$Sprite2D.flip_h = false

	# Durante o ataque, mantém o estado ATTACK e a animação de ataque
	if state == State.ATTACK:
		return

	# Troca de animações de movimento
	if motion != Vector2.ZERO:
		state = State.RUN
		animation_player.play("correr") 
	else:
		state = State.IDLE
		animation_player.play("idle")


# 8. Ativa o ataque de Mordida mirando numa posição-alvo (chamado pela habilidade automática)
func perform_bite_attack(target_position: Vector2) -> void:
	if state == State.ATTACK or state == State.DEAD:
		return
	state = State.ATTACK
	som_ataque.play()

	var attack_direction: Vector2 = global_position.direction_to(target_position).normalized()

	# Vira o sprite para o lado do ataque
	if attack_direction.x < 0:
		$Sprite2D.flip_h = true
	else:
		$Sprite2D.flip_h = false
		
	# Escolhe a animação de ataque (Cima, Baixo ou Lado)
	if abs(attack_direction.y) >= abs(attack_direction.x):
		if attack_direction.y < 0:
			animation_player.play("attack_up")
		else:
			animation_player.play("attack_down")
	else:
		animation_player.play("attack_right")
	
	# Momento de impacto do golpe: aplica dano em quem estiver na AttackArea
	get_tree().create_timer(attack_duration * 0.4).timeout.connect(_deal_attack_damage)

	# Cronômetro de 0.6 segundos para encerrar o ataque e liberar o personagem
	get_tree().create_timer(attack_duration).timeout.connect(_on_attack_animation_finished)


# 9.1 Aplica dano a quem estiver dentro da AttackArea no momento do impacto
func _deal_attack_damage() -> void:
	if state == State.DEAD:
		return
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)


# 9. Destrava o personagem após o ataque terminar
func _on_attack_animation_finished() -> void:
	if state != State.ATTACK:
		return
		
	state = State.IDLE
	
	# Checa se o jogador já está segurando alguma tecla para voltar correndo imediatamente
	var input_dir = Vector2(
		int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left")),
		int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	)
	
	if input_dir != Vector2.ZERO:
		state = State.RUN
		animation_player.play("correr")
	else:
		animation_player.play("idle")


# 10. Recebe dano de um inimigo
func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health -= amount
	som_dano.play()
	if health <= 0:
		health = 0
		health_changed.emit(health, max_health)
		_die()
	else:
		health_changed.emit(health, max_health)
		_flash_hit()


func _flash_hit() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(0.12).timeout
	if state != State.DEAD:
		modulate = Color(1, 1, 1)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	move_and_slide()

	# Trava os controles e mostra visualmente que o jogador morreu
	set_physics_process(false)
	som_game_over.play()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	
	if som_game_over.playing:
		await som_game_over.finished

	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
