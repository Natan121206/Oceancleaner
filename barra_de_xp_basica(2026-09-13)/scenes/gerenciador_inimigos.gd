extends Node2D

signal inimigo_derrotado(total: int)
signal nivel_subiu(novo_nivel: int)
signal xp_changed(xp_atual: int, xp_necessario: int, nivel: int)

@export var cena_inimigo: PackedScene
@export var tamanho_pool: int = 50
@export var tempo_spawn: float = 1.0

@export var jogador: Node2D

# ------------------------------
# Progressão
# ------------------------------
@export_category("Progressão")
@export var xp_primeiro_nivel: int = 30
@export var multiplicador_xp: float = 1.3

# ------------------------------
# Pool de inimigos
# ------------------------------
var pool_inimigos: Array[Inimigo] = []
var timer_spawn: Timer

# ------------------------------
# Estatísticas da partida
# ------------------------------
var total_derrotados: int = 0

# XP acumulado dentro da partida
var xp_total: int = 0

# Nível atual do jogador
var nivel_atual: int = 1

# XP acumulado dentro do nível atual
var xp_atual_nivel: int = 0

# XP necessário para passar para o próximo nível
var xp_necessario: int = 50


func _ready() -> void:
	# Define o XP necessário para o primeiro nível.
	xp_necessario = xp_primeiro_nivel

	_inicializar_pool()
	_configurar_timer()


func _inicializar_pool() -> void:
	if cena_inimigo == null:
		push_error("Arraste o arquivo inimigo.tscn para o Inspetor do Gerenciador!")
		return

	for i in range(tamanho_pool):
		var instancia = cena_inimigo.instantiate()

		# Converte para o tipo da sua classe Inimigo
		if instancia is Inimigo:
			var inimigo: Inimigo = instancia

			inimigo.hide()
			inimigo.set_physics_process(false)

			inimigo.died.connect(_on_inimigo_derrotado)

			add_child(inimigo)
			pool_inimigos.append(inimigo)
		else:
			push_error(
				"O nó raiz da cena do inimigo precisa herdar de CharacterBody2D e ter 'class_name Inimigo'"
			)


# ------------------------------
# Derrota de inimigos / XP
# ------------------------------
func _on_inimigo_derrotado(inimigo: Inimigo) -> void:
	# Incrementa o número total de inimigos derrotados.
	total_derrotados += 1

	# Atualiza o contador de inimigos derrotados.
	inimigo_derrotado.emit(total_derrotados)

	# Adiciona a recompensa de XP do inimigo.
	_adicionar_xp(inimigo.xp_reward)


func _adicionar_xp(valor: int) -> void:
	if valor <= 0:
		return

	# Adiciona o XP ao total geral.
	xp_total += valor

	# Adiciona o XP ao nível atual.
	xp_atual_nivel += valor

	# Verifica se o jogador pode subir de nível.
	_verificar_level_up()

	# Atualiza o HUD.
	xp_changed.emit(
		xp_atual_nivel,
		xp_necessario,
		nivel_atual
	)


# ------------------------------
# Sistema de Level Up
# ------------------------------
func _verificar_level_up() -> void:
	# Enquanto houver XP suficiente para subir de nível,
	# continua realizando a progressão.
	while xp_atual_nivel >= xp_necessario:

		# Remove o XP utilizado para alcançar o próximo nível.
		xp_atual_nivel -= xp_necessario

		# Aumenta o nível.
		nivel_atual += 1

		# Calcula o novo XP necessário.
		xp_necessario = _calcular_xp_necessario(nivel_atual)
		
		nivel_subiu.emit(nivel_atual)


func _calcular_xp_necessario(nivel: int) -> int:
	# Fórmula:
	# Nível 1 = 50 XP
	# Nível 2 = 75 XP
	# Nível 3 = 112 XP
	# Nível 4 = 168 XP
	# etc.
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

	for inimigo in pool_inimigos:
		if not inimigo.visible:
			var pos = _obter_posicao_aleatoria_fora_da_tela()

			inimigo.renascer(pos, jogador)
			return


func _obter_posicao_aleatoria_fora_da_tela() -> Vector2:
	var raio = randf_range(500, 700)
	var angulo = randf() * TAU

	return jogador.global_position + Vector2(
		cos(angulo),
		sin(angulo)
	) * raio
