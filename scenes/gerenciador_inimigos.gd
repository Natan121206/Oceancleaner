extends Node2D

signal inimigo_derrotado(total: int)
signal nivel_subiu(novo_nivel: int)
signal xp_changed(xp_atual: int, xp_necessario: int, nivel: int)
signal dificuldade_subiu(nivel: int)

@export var cena_inimigo: PackedScene
@export var tamanho_pool: int = 50
@export var tempo_spawn: float = 1.0

# ------------------------------
# Segundo tipo de inimigo (caixinha de suco, ataca de longe)
# ------------------------------
@export_category("Caixinha de suco")
@export var cena_inimigo_suco: PackedScene = preload("res://scenes/inimigo_suco.tscn")
@export var tamanho_pool_suco: int = 25
# Chance (0 a 1) de cada spawn ser uma caixinha em vez de uma lata
@export_range(0.0, 1.0) var chance_suco: float = 0.4

@export var jogador: Node2D

# ------------------------------
# Dificuldade progressiva
# ------------------------------
@export_category("Dificuldade")
# A cada quantos inimigos derrotados os inimigos novos ficam mais fortes
@export var abates_por_nivel_dificuldade: int = 100
# Vida: multiplicador composto por nível (1.25 = +25% sobre o nível anterior, acumulando)
@export var mult_vida_por_nivel: float = 1.25
# Dano: aumento LINEAR por nível (0.08 = +8% do dano original por nível), com teto
@export var bonus_dano_por_nivel: float = 0.08
@export var mult_dano_maximo: float = 2.5
# Velocidade: aumento LINEAR por nível (0.06 = +6% da velocidade original por nível), com teto
@export var bonus_velocidade_por_nivel: float = 0.06
@export var mult_velocidade_maximo: float = 2.0

# 0 = normal; sobe 1 a cada `abates_por_nivel_dificuldade` abates
var nivel_dificuldade: int = 0

# ------------------------------
# Área de spawn (dentro do mapa)
# ------------------------------
@export_category("Área de spawn")
# Distância mínima das paredes do mapa onde um inimigo pode nascer (pixels)
@export var margem_spawn: float = 120.0

# Área jogável do mapa. É calculada a partir das paredes ("LimitesMapa") no _ready;
# este valor só é usado se as paredes não forem encontradas.
var _area_mapa: Rect2 = Rect2(-69.0, -107.0, 2530.0, 1584.0)

# ------------------------------
# Progressão
# ------------------------------
@export_category("Progressão")
@export var xp_primeiro_nivel: int = 30
@export var multiplicador_xp: float = 1.3

# ------------------------------
# Depuração
# ------------------------------
@export_category("Depuração")
@export var debug_numeros_dano_ativos: bool = true

# ------------------------------
# Pool de inimigos
# ------------------------------
var pool_inimigos: Array[Inimigo] = []
var pool_suco: Array[Inimigo] = []
var timer_spawn: Timer

# ------------------------------
# Estatísticas da partida
# ------------------------------
var total_derrotados: int = 0
var xp_total: int = 0
var nivel_atual: int = 1
var xp_atual_nivel: int = 0
var xp_necessario: int = 50


func _ready() -> void:
	# Define o XP necessário para o primeiro nível.
	xp_necessario = xp_primeiro_nivel

	_calcular_area_do_mapa()
	_inicializar_pool()
	_configurar_timer()

	# Aplica o estado inicial da opção de depuração.
	_atualizar_visibilidade_numeros_dano()


func _inicializar_pool() -> void:
	if cena_inimigo == null:
		push_error("Arraste o arquivo inimigo.tscn para o Inspetor do Gerenciador!")
	else:
		_criar_pool(cena_inimigo, tamanho_pool, pool_inimigos)

	if cena_inimigo_suco != null:
		_criar_pool(cena_inimigo_suco, tamanho_pool_suco, pool_suco)


func _criar_pool(cena: PackedScene, tamanho: int, destino: Array[Inimigo]) -> void:
	for i in range(tamanho):
		var instancia = cena.instantiate()

		if instancia is Inimigo:
			var inimigo: Inimigo = instancia

			inimigo.hide()
			inimigo.set_physics_process(false)

			# Cada inimigo recebe a configuração atual da depuração.
			inimigo.mostrar_numeros_dano = debug_numeros_dano_ativos

			inimigo.died.connect(_on_inimigo_derrotado)

			add_child(inimigo)

			# O Godot liga o processamento sozinho ao entrar na cena, ignorando o
			# set_physics_process(false) feito antes. Sem isto, TODOS os inimigos do pool
			# ficavam ativos (escondidos, atacando e atirando) até serem usados.
			inimigo.set_physics_process(false)

			destino.append(inimigo)
		else:
			push_error(
				"O nó raiz da cena do inimigo precisa herdar de CharacterBody2D e ter 'class_name Inimigo'"
			)
			instancia.queue_free()


# ------------------------------
# Derrota de inimigos / XP
# ------------------------------
func _on_inimigo_derrotado(inimigo: Inimigo) -> void:
	total_derrotados += 1
	inimigo_derrotado.emit(total_derrotados)
	_verificar_dificuldade()

	_adicionar_xp(inimigo.xp_reward)


func _adicionar_xp(valor: int) -> void:
	if valor <= 0:
		return

	xp_total += valor
	xp_atual_nivel += valor

	_verificar_level_up()

	xp_changed.emit(
		xp_atual_nivel,
		xp_necessario,
		nivel_atual
	)


# ------------------------------
# Sistema de Level Up
# ------------------------------
func _verificar_level_up() -> void:
	while xp_atual_nivel >= xp_necessario:
		xp_atual_nivel -= xp_necessario
		nivel_atual += 1
		xp_necessario = _calcular_xp_necessario(nivel_atual)

		print("DEBUG: jogador alcançou o nível ", nivel_atual)

		nivel_subiu.emit(nivel_atual)


func _calcular_xp_necessario(nivel: int) -> int:
	# Nível 1: 30 XP; níveis seguintes crescem pelo multiplicador.
	var xp: float = xp_primeiro_nivel * pow(multiplicador_xp, nivel - 1)
	return int(ceil(xp))


# ------------------------------
# Spawn
# ------------------------------
func _configurar_timer() -> void:
	timer_spawn = Timer.new()
	timer_spawn.wait_time = tempo_spawn
	timer_spawn.autostart = true
	timer_spawn.timeout.connect(_gerar_inimigo)
	add_child(timer_spawn)


func _gerar_inimigo() -> void:
	if jogador == null:
		return

	# Sorteia se esta vaga será uma caixinha de suco ou uma lata
	var quer_suco: bool = not pool_suco.is_empty() and randf() < chance_suco

	if quer_suco and _renascer_do_pool(pool_suco):
		return

	# Sem caixinha livre (ou não sorteada): nasce uma lata
	_renascer_do_pool(pool_inimigos)


# Sobe a dificuldade a cada N abates (vale para os inimigos que nascerem daqui para frente)
func _verificar_dificuldade() -> void:
	if abates_por_nivel_dificuldade <= 0:
		return

	var novo_nivel: int = total_derrotados / abates_por_nivel_dificuldade
	if novo_nivel > nivel_dificuldade:
		nivel_dificuldade = novo_nivel
		print("DEBUG: dificuldade nível ", nivel_dificuldade,
			" (vida x%.2f, dano x%.2f, velocidade x%.2f)" % [
				_mult_vida(), _mult_dano(), _mult_velocidade()
			])
		dificuldade_subiu.emit(nivel_dificuldade)


func _mult_vida() -> float:
	return pow(mult_vida_por_nivel, nivel_dificuldade)


func _mult_dano() -> float:
	return minf(1.0 + bonus_dano_por_nivel * nivel_dificuldade, mult_dano_maximo)


func _mult_velocidade() -> float:
	return minf(1.0 + bonus_velocidade_por_nivel * nivel_dificuldade, mult_velocidade_maximo)


# Reaproveita o primeiro inimigo escondido do pool. Retorna false se não havia nenhum livre.
func _renascer_do_pool(pool: Array[Inimigo]) -> bool:
	for inimigo in pool:
		if not inimigo.visible:
			var pos = _obter_posicao_aleatoria_fora_da_tela()
			inimigo.aplicar_dificuldade(_mult_vida(), _mult_dano(), _mult_velocidade())
			inimigo.renascer(pos, jogador)
			return true

	return false


func _obter_posicao_aleatoria_fora_da_tela() -> Vector2:
	var area: Rect2 = _area_mapa.grow(-margem_spawn)
	var candidata: Vector2 = jogador.global_position

	# 1) Tenta nascer fora da tela, em volta do jogador, mas SEMPRE dentro do mapa
	for tentativa in 12:
		var raio: float = randf_range(500.0, 700.0)
		var angulo: float = randf() * TAU
		candidata = jogador.global_position + Vector2(cos(angulo), sin(angulo)) * raio

		if area.has_point(candidata):
			return candidata

	# 2) Jogador perto de uma borda/canto: sorteia um ponto qualquer do mapa, longe dele
	for tentativa in 12:
		var ponto := Vector2(
			randf_range(area.position.x, area.end.x),
			randf_range(area.position.y, area.end.y)
		)
		if ponto.distance_to(jogador.global_position) >= 350.0:
			return ponto

	# 3) Último recurso: empurra a última candidata para dentro do mapa
	return Vector2(
		clampf(candidata.x, area.position.x, area.end.x),
		clampf(candidata.y, area.position.y, area.end.y)
	)


# Lê as paredes do mapa ("LimitesMapa") e descobre a área jogável por dentro delas
func _calcular_area_do_mapa() -> void:
	var limites := get_parent().find_child("LimitesMapa", true, false)
	if limites == null:
		push_warning("Gerenciador: 'LimitesMapa' não encontrado, usando a área padrão do mapa.")
		return

	var esquerda: float = -INF
	var direita: float = INF
	var topo: float = -INF
	var baixo: float = INF
	var achou: int = 0

	# Centro do mapa = média dos centros das paredes
	var paredes: Array[CollisionShape2D] = []
	var centro := Vector2.ZERO
	for filho in limites.get_children():
		if filho is CollisionShape2D and filho.shape is RectangleShape2D:
			paredes.append(filho)
			centro += filho.global_position
	if paredes.is_empty():
		return
	centro /= paredes.size()

	for parede in paredes:
		var metade: Vector2 = (parede.shape as RectangleShape2D).size * parede.global_transform.get_scale().abs() / 2.0
		var pos: Vector2 = parede.global_position

		if metade.x > metade.y:
			# Parede horizontal (cima ou baixo): a borda de dentro é a que olha para o centro
			if pos.y < centro.y:
				topo = pos.y + metade.y
			else:
				baixo = pos.y - metade.y
		else:
			# Parede vertical (esquerda ou direita)
			if pos.x < centro.x:
				esquerda = pos.x + metade.x
			else:
				direita = pos.x - metade.x
		achou += 1

	if achou >= 4 and esquerda < direita and topo < baixo:
		_area_mapa = Rect2(esquerda, topo, direita - esquerda, baixo - topo)


# ------------------------------
# Ferramentas de depuração
# ------------------------------

# Concede XP suficiente para subir exatamente um nível.
func debug_subir_nivel() -> void:
	if get_tree().paused:
		print("DEBUG: o jogo já está pausado.")
		return

	if xp_necessario <= 0:
		push_warning("DEBUG: o XP necessário para subir de nível é inválido.")
		return

	var xp_faltante: int = xp_necessario - xp_atual_nivel

	if xp_faltante <= 0:
		xp_faltante = 1

	print("DEBUG: concedendo ", xp_faltante, " XP para subir de nível.")
	_adicionar_xp(xp_faltante)


# Sobe a dificuldade um nível na hora (teste). Vale para os inimigos que nascerem daqui para frente.
func debug_subir_dificuldade() -> void:
	nivel_dificuldade += 1
	print("DEBUG: dificuldade nível ", nivel_dificuldade,
		" (vida x%.2f, dano x%.2f, velocidade x%.2f)" % [
			_mult_vida(), _mult_dano(), _mult_velocidade()
		])
	dificuldade_subiu.emit(nivel_dificuldade)


# Atualiza todos os inimigos existentes no pool.
func _atualizar_visibilidade_numeros_dano() -> void:
	for inimigo in pool_inimigos + pool_suco:
		if is_instance_valid(inimigo):
			inimigo.mostrar_numeros_dano = debug_numeros_dano_ativos


func _input(event: InputEvent) -> void:
	# Disponível somente em uma execução de depuração.
	if not OS.has_feature("debug"):
		return

	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo:
		return

	# Ctrl + Shift + L: subir um nível instantaneamente.
	if (
		event.ctrl_pressed
		and event.shift_pressed
		and event.keycode == KEY_L
	):
		print("DEBUG: comando de subir de nível acionado.")
		debug_subir_nivel()
		get_viewport().set_input_as_handled()

	# Ctrl + Shift + Z: subir a dificuldade um nível instantaneamente.
	elif (
		event.ctrl_pressed
		and event.shift_pressed
		and event.keycode == KEY_Z
	):
		debug_subir_dificuldade()
		get_viewport().set_input_as_handled()
