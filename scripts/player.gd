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
@export var attack_damage: int = 0 # Dano base compartilhado entre os ataques

@export_category("Defesa")
# Depois de levar dano, o tubarão fica este tempo (segundos) sem poder ser ferido de novo.
# Sem isso, vários inimigos colados batiam todos no mesmo instante e davam "hitkill".
@export var tempo_invulneravel: float = 0.5

@export_category("Espadada (cone)")
@export_range(30.0, 360.0) var cone_angulo: float = 150.0 # abertura do golpe, em graus (120 a 180 é o ideal)
@export var cone_raio: float = 140.0 # até onde a espadada alcança, em pixels

# 3. Variáveis de Controle
var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var health: int
var attack_speed_multiplier: float = 1.0 # 1.0 = cadência normal
var attack_duration_base: float = 0.6
# Golpes sucessivos extras do ataque principal (espadada). 0 = um golpe só; cada upgrade soma 1.
var golpes_extras: int = 0
const GOLPES_EXTRAS_MAXIMO: int = 4
const INTERVALO_GOLPE_EXTRA: float = 0.16 # segundos entre os golpes (diminui com a cadência)
var _invulneravel_ate_ms: int = 0 # momento (ms) até o qual não leva dano

# Vampirismo: fração da vida máxima recuperada a cada inimigo derrotado (0.03 = 3%)
var vampirismo: float = 0.0
const VAMPIRISMO_MAXIMO: float = 0.30

# Ataques desbloqueados. O tubarão começa só com o corte de água ("mordida").
# A cada N inimigos derrotados o jogador escolhe um novo ataque para desbloquear.
var ataques_desbloqueados: Dictionary = {
	"mordida": true,
	"bolha": false,
	"pulso": false,
	"ourico": false,
}
const CAMINHO_ATAQUE: Dictionary = {
	"bolha": "Habilidades/JatoBolhas",
	"pulso": "Habilidades/Redemoinho",
}
const OURICOS_INICIAIS: int = 2

# Ouriços orbitais: quantidade de ouriços girando em volta do tubarão
var ouricos: int = 0
const OURICOS_MAXIMO: int = 6

# Multiplicador de alcance de cada ataque (1.0 = normal, 1.2 = +20%)
var alcance: Dictionary = {"mordida": 1.0, "pulso": 1.0, "bolha": 1.0, "ourico": 1.0}

# 4. Referência Direta ao AnimationPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var som_ataque: AudioStreamPlayer2D = $SomAtaque
@onready var som_dano: AudioStreamPlayer2D = $SomDano
@onready var som_game_over: AudioStreamPlayer2D = $SomGameOver


func _ready() -> void:
	health = max_health
	attack_duration_base = attack_duration
	add_to_group("player")

	# Ataques ainda não desbloqueados ficam desligados (o Timer deles para junto)
	for ataque in CAMINHO_ATAQUE:
		_ligar_ataque(ataque, false)

	print("Player: começa só com o corte. Bolha, pulso e ouriço bloqueados até a escolha dos 50 abates.")
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


# 7. Lógica de Movimentação (WASD / Direcionais e joystick virtual do celular)
func movement_loop() -> void:
	# Lendo os comandos de movimento do teclado
	# get_vector respeita a intensidade: teclado dá 1.0 (igual antes) e o joystick
	# do celular dá valores entre 0 e 1 (quanto mais longe do centro, mais rápido)
	move_direction = Input.get_vector("left", "right", "up", "down")

	var motion: Vector2 = move_direction * speed
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
# dano_proprio permite que cada habilidade adicione seu próprio dano ao dano base do Player
func perform_bite_attack(
	target_position: Vector2,
	dano_proprio: int = 0
) -> void:
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

	# Momento de impacto do golpe: aplica dano em quem estiver dentro da AttackArea
	get_tree().create_timer(
		attack_duration * 0.4
	).timeout.connect(_deal_attack_damage.bind(dano_proprio, attack_direction))

	# Corte de água aparece no momento do impacto
	get_tree().create_timer(
		attack_duration * 0.4
	).timeout.connect(_spawn_corte.bind(attack_direction))

	# Golpes sucessivos extras (upgrade do ataque principal): cada um repete dano + corte
	for i in golpes_extras:
		var atraso: float = attack_duration * 0.4 + INTERVALO_GOLPE_EXTRA * (i + 1) / attack_speed_multiplier
		get_tree().create_timer(atraso).timeout.connect(
			_golpe_extra.bind(dano_proprio, attack_direction)
		)

	# Cronômetro de 0.6 segundos para encerrar o ataque e liberar o personagem
	get_tree().create_timer(attack_duration).timeout.connect(_on_attack_animation_finished)


# 8.0 Efeito visual do corte de água (sprite em arco que aparece e some rápido)
const CORTE_TEXTURA := "res://assets/ui/waterCut.png"
# Ajustes do desenho do corte (tamanho e distância em pixels, rotação em graus)
const CORTE_LARGURA: float = 230.0
const CORTE_DESLOCAMENTO: float = 75.0
# Se o arco aparecer virado para o lado errado, mude este valor (90, 180 ou -90)
const CORTE_ROTACAO_EXTRA_GRAUS: float = 0.0
# Corpo do tubarão (centro) e do inimigo, usados na checagem do cone
const CENTRO_CORPO: Vector2 = Vector2(0, -35)
const RAIO_INIMIGO: float = 30.0
const RAIO_CORPO_A_CORPO: float = 45.0 # muito perto: acerta mesmo fora do cone

func _spawn_corte(direcao: Vector2) -> void:
	if state == State.DEAD or not ResourceLoader.exists(CORTE_TEXTURA):
		return

	var textura := load(CORTE_TEXTURA) as Texture2D
	var mult: float = alcance["mordida"] # cresce junto com o upgrade de alcance da espadada

	var corte := Sprite2D.new()
	corte.texture = textura
	corte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corte.z_index = 5

	# O arco da imagem aponta "para cima": gira para apontar na direção do ataque
	corte.rotation = direcao.angle() + PI / 2.0 + deg_to_rad(CORTE_ROTACAO_EXTRA_GRAUS)

	# O arco ocupa ~90% da largura da imagem
	var escala_final: float = (CORTE_LARGURA * mult) / (textura.get_width() * 0.9)
	corte.scale = Vector2.ONE * escala_final * 0.7

	# Aparece à frente do tubarão, na direção do golpe (não em cima do corpo)
	corte.global_position = global_position + CENTRO_CORPO + direcao * CORTE_DESLOCAMENTO * mult

	get_tree().current_scene.add_child(corte)

	var tween := corte.create_tween()
	tween.set_parallel(true)
	tween.tween_property(corte, "scale", Vector2.ONE * escala_final * 1.1, 0.22)
	tween.tween_property(corte, "modulate:a", 0.0, 0.22)
	tween.set_parallel(false)
	tween.tween_callback(corte.queue_free)


# Golpe extra da sequência: mira de novo no inimigo mais próximo (se houver perto)
func _golpe_extra(dano_proprio: int, direcao_original: Vector2) -> void:
	if state == State.DEAD:
		return

	var direcao: Vector2 = direcao_original
	var alvo: Node2D = find_nearest_enemy()
	if alvo != null and global_position.distance_to(alvo.global_position) <= cone_raio * alcance["mordida"] * 1.5:
		direcao = global_position.direction_to(alvo.global_position)

	som_ataque.play()
	_deal_attack_damage(dano_proprio, direcao)
	_spawn_corte(direcao)


# Upgrade do ataque principal: +1 golpe sucessivo
func aumentar_golpes_extras(quantidade: int = 1) -> void:
	golpes_extras = mini(golpes_extras + quantidade, GOLPES_EXTRAS_MAXIMO)


# 8.1 Dano em cone: atinge os inimigos NA FRENTE do golpe (cone_angulo graus), até cone_raio.
# Soma o dano base do Player ao dano próprio da habilidade.
func _deal_attack_damage(dano_proprio: int = 0, direcao: Vector2 = Vector2.RIGHT) -> void:
	if state == State.DEAD:
		return

	var dano_final: int = attack_damage + dano_proprio
	var origem: Vector2 = global_position + CENTRO_CORPO
	var raio: float = cone_raio * alcance["mordida"] # cresce com o upgrade de alcance
	var meio_cone: float = deg_to_rad(cone_angulo) / 2.0

	for inimigo in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(inimigo) or not inimigo.visible:
			continue

		if not inimigo.has_method("take_damage"):
			continue

		# Usa o centro do corpo do inimigo (a posição dele fica nos pés)
		var para_inimigo: Vector2 = (inimigo.global_position + Vector2(0, -30)) - origem
		var dist: float = para_inimigo.length()

		if dist > raio + RAIO_INIMIGO:
			continue

		# Fora do cone não acerta (exceto colado no tubarão)
		if dist > RAIO_CORPO_A_CORPO and absf(direcao.angle_to(para_inimigo)) > meio_cone:
			continue

		inimigo.take_damage(dano_final)


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

	# Período de invulnerabilidade logo após levar dano
	var agora: int = Time.get_ticks_msec()
	if agora < _invulneravel_ate_ms:
		return
	_invulneravel_ate_ms = agora + int(tempo_invulneravel * 1000.0)

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

	if state == State.DEAD:
		return

	# Fica um pouco transparente enquanto está invulnerável
	modulate = Color(1, 1, 1, 0.7)
	await get_tree().create_timer(maxf(tempo_invulneravel - 0.12, 0.0)).timeout

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


# ------------------------------
# Sistema de upgrades
# ------------------------------

func aumentar_vida_maxima(valor: int) -> void:
	max_health += valor
	health += valor
	health = min(health, max_health)

	health_changed.emit(health, max_health)


func aumentar_dano(valor: int) -> void:
	attack_damage += valor


func aumentar_velocidade(valor: float) -> void:
	speed += valor


# Cadência de ataque: percentual = 0.15 significa +15% de ataques por segundo.
# Reduz a duração do golpe da Mordida e o intervalo (Timer) de todas as habilidades.
func aumentar_cadencia(percentual: float) -> void:
	attack_speed_multiplier += percentual
	attack_duration = max(0.2, attack_duration_base / attack_speed_multiplier)
	_atualizar_timers_habilidades()


func _atualizar_timers_habilidades() -> void:
	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return

	for habilidade in habilidades.get_children():
		var timer := habilidade.get_node_or_null("Timer") as Timer
		if timer == null:
			continue

		# Guarda o intervalo original na primeira vez, para sempre calcular a partir dele
		if not habilidade.has_meta("cooldown_base"):
			habilidade.set_meta("cooldown_base", timer.wait_time)

		var base: float = habilidade.get_meta("cooldown_base")
		timer.wait_time = max(0.15, base / attack_speed_multiplier)


# Amplia o alcance de um ataque: "mordida" (corte), "pulso" (redemoinho), "bolha" ou "ourico" (tamanho).
# percentual = 0.2 significa +20% (soma ao que já tinha).
func aumentar_alcance(ataque: String, percentual: float) -> void:
	if not alcance.has(ataque):
		return

	alcance[ataque] += percentual
	var mult: float = alcance[ataque]

	match ataque:
		"mordida":
			var forma := get_node_or_null("AttackArea/CollisionShape2D") as CollisionShape2D
			if forma:
				forma.scale = Vector2.ONE * mult
		"pulso":
			var pulso := get_node_or_null("Habilidades/Redemoinho")
			if pulso:
				if not pulso.has_meta("radius_base"):
					pulso.set_meta("radius_base", pulso.radius)
				pulso.radius = float(pulso.get_meta("radius_base")) * mult
		"bolha":
			var jato := get_node_or_null("Habilidades/JatoBolhas")
			if jato:
				jato.escala_projetil = mult
		"ourico":
			var ourico := get_node_or_null("Habilidades/Ourico")
			if ourico:
				ourico.definir_escala(mult)


# Quanto de alcance extra o ataque já tem, em % (para mostrar no painel)
func alcance_extra_percentual(ataque: String) -> int:
	return roundi((float(alcance.get(ataque, 1.0)) - 1.0) * 100.0)


# Vampirismo: percentual = 0.03 significa +3% da vida máxima por inimigo derrotado.
func aumentar_vampirismo(percentual: float) -> void:
	vampirismo = minf(vampirismo + percentual, VAMPIRISMO_MAXIMO)


# Chamado pelo HUD toda vez que um inimigo é derrotado
func curar_por_abate() -> void:
	if vampirismo <= 0.0 or state == State.DEAD or health >= max_health:
		return

	var cura: int = maxi(1, roundi(max_health * vampirismo))
	health = mini(health + cura, max_health)
	health_changed.emit(health, max_health)

	# Brilho verde rápido para o jogador perceber que curou
	modulate = Color(0.55, 1.0, 0.65)
	await get_tree().create_timer(0.12).timeout

	if state != State.DEAD:
		modulate = Color(1, 1, 1)


# Ouriço orbital: cada escolha adiciona mais um ouriço girando em volta do tubarão.
func aumentar_ouricos(quantidade: int = 1) -> void:
	ouricos = mini(ouricos + quantidade, OURICOS_MAXIMO)

	var habilidades := get_node_or_null("Habilidades")
	if habilidades == null:
		return

	var ourico := habilidades.get_node_or_null("Ourico")
	if ourico == null:
		ourico = load("res://scripts/abilities/ability_ourico.gd").new()
		ourico.name = "Ourico"
		ourico.player = self
		ourico.position = Vector2(0, -36) # gira em volta do corpo, não dos pés
		habilidades.add_child(ourico)

	ourico.escala_tamanho = alcance["ourico"]
	ourico.definir_quantidade(ouricos)


# ------------------------------
# Desbloqueio de ataques
# ------------------------------

func tem_ataque(ataque: String) -> bool:
	return ataques_desbloqueados.get(ataque, false)


func desbloquear_ataque(ataque: String) -> void:
	if not ataques_desbloqueados.has(ataque) or tem_ataque(ataque):
		return

	ataques_desbloqueados[ataque] = true

	if ataque == "ourico":
		aumentar_ouricos(OURICOS_INICIAIS)
	else:
		_ligar_ataque(ataque, true)


# Atalho de teste (Ctrl+Shift+K no HUD): libera todos os ataques de uma vez
func desbloquear_todos_ataques() -> void:
	for ataque in ["bolha", "pulso", "ourico"]:
		desbloquear_ataque(ataque)


# Liga/desliga uma habilidade automática: desligada, o Timer dela não conta
func _ligar_ataque(ataque: String, ligado: bool) -> void:
	var habilidade := get_node_or_null(CAMINHO_ATAQUE.get(ataque, "")) as Node
	if habilidade == null:
		return

	habilidade.process_mode = (
		Node.PROCESS_MODE_INHERIT if ligado else Node.PROCESS_MODE_DISABLED
	)
