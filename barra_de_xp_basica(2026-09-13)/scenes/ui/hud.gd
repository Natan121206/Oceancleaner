extends CanvasLayer

@export var player_path: NodePath
@export var gerenciador_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var timer_label: Label = %TimerLabel
@onready var kills_label: Label = %KillsLabel
@onready var upgrade_panel: Panel = %UpgradePanel

# Elementos da barra de XP
@onready var xp_bar: ProgressBar = %XPBar
@onready var xp_label: Label = %XPLabel
@onready var level_label: Label = %LevelLabel

var player: Player
var gerenciador: Node2D

var elapsed_time: float = 0.0

# Tween responsável pela animação da barra de vida
var health_tween: Tween

# Tween responsável pela animação da barra de XP
var xp_tween: Tween


func _ready() -> void:
	# Tenta encontrar o jogador através do caminho configurado no Inspector
	if player_path != NodePath():
		player = get_node_or_null(player_path) as Player

	# Caso o caminho não esteja configurado ou não encontre o jogador,
	# procura automaticamente pelo grupo "player"
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	if is_instance_valid(player):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
	else:
		push_warning("HUD: não encontrou o jogador.")

	# Procura o gerenciador através do caminho configurado no Inspector
	if gerenciador_path != NodePath():
		gerenciador = get_node_or_null(gerenciador_path) as Node2D

	if is_instance_valid(gerenciador):
		# Conecta o contador de inimigos derrotados
		gerenciador.inimigo_derrotado.connect(_on_inimigo_derrotado)
		_on_inimigo_derrotado(gerenciador.total_derrotados)

		# Conecta o sistema de XP
		gerenciador.xp_changed.connect(_on_xp_changed)

		# Inicializa a barra de XP com os valores atuais
		_on_xp_changed(
			gerenciador.xp_atual_nivel,
			gerenciador.xp_necessario,
			gerenciador.nivel_atual
		)
		gerenciador.nivel_subiu.connect(_on_nivel_subiu)
		
	else:
		push_warning(
			"HUD: não encontrou o gerenciador em '%s' — o contador de derrotados e XP não vão atualizar."
			% [gerenciador_path]
		)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# Sincroniza a barra de vida direto do jogador a cada frame — não depende
	# só do sinal, então nunca fica "presa" num valor antigo.
	_sync_health()

	if not player.is_dead():
		elapsed_time += delta
		_update_timer_label()
	else:
		# Guarda os resultados da partida antes da troca para a tela de morte.
		_save_match_results()


func _sync_health() -> void:
	# O valor da barra é alterado pelo Tween durante a animação.
	# Por isso, não devemos comparar health_bar.value com player.health aqui,
	# pois isso interromperia a animação a cada frame.
	if health_bar.max_value != player.max_health:
		_on_health_changed(player.health, player.max_health)


func _on_health_changed(current: int, max_amount: int) -> void:
	health_bar.max_value = max_amount
	health_label.text = "%d / %d" % [current, max_amount]

	# Interrompe uma animação anterior caso o jogador receba dano
	# novamente antes da animação terminar.
	if health_tween and health_tween.is_valid():
		health_tween.kill()

	# Anima suavemente a barra até o novo valor de vida.
	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_QUAD)
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.tween_property(health_bar, "value", current, 0.4)

	# Fica vermelha quando a vida está baixa
	var pct: float = float(current) / float(max(max_amount, 1))

	if pct <= 0.25:
		health_bar.modulate = Color(1.0, 0.35, 0.35)
	elif pct <= 0.5:
		health_bar.modulate = Color(1.0, 0.8, 0.35)
	else:
		health_bar.modulate = Color(1, 1, 1)


# ------------------------------
# Sistema de XP
# ------------------------------
func _on_xp_changed(
	current_xp: int,
	required_xp: int,
	level: int
) -> void:

	# Define o máximo da barra de acordo com o XP
	# necessário para o próximo nível.
	xp_bar.max_value = required_xp

	# Atualiza o texto do XP.
	xp_label.text = "%d / %d" % [current_xp, required_xp]

	# Atualiza o nível.
	level_label.text = "Nível %d" % level

	# Interrompe uma animação anterior caso o jogador
	# ganhe XP novamente antes da animação terminar.
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()

	# Anima suavemente a barra até o novo valor.
	xp_tween = create_tween()
	xp_tween.set_trans(Tween.TRANS_QUAD)
	xp_tween.set_ease(Tween.EASE_OUT)

	xp_tween.tween_property(
		xp_bar,
		"value",
		current_xp,
		0.4
	)


# ------------------------------
# Contador de inimigos derrotados
# ------------------------------
func _on_inimigo_derrotado(total: int) -> void:
	kills_label.text = "%d" % total


# ------------------------------
# Resultados da partida
# ------------------------------
func _save_match_results() -> void:
	var total_kills: int = 0

	if is_instance_valid(gerenciador):
		total_kills = gerenciador.total_derrotados

	# Guarda temporariamente os resultados no SceneTree.
	get_tree().set_meta("inimigos_derrotados", total_kills)
	get_tree().set_meta("tempo_sobrevivido", elapsed_time)


# ------------------------------
# Cronômetro
# ------------------------------
func _update_timer_label() -> void:
	var total_seconds: int = int(elapsed_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_nivel_subiu(novo_nivel: int) -> void:
	upgrade_panel.mostrar_upgrade(novo_nivel)
