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

# A cada quantos inimigos derrotados aparece a escolha de alcance
@export var kills_por_alcance: int = 30

# A cada quantos inimigos derrotados o jogador escolhe um novo ataque
@export var kills_por_ataque: int = 50

@export_category("Celular")
# Liga o modo celular mesmo no computador (para testar a interface)
@export var modo_celular_forcado: bool = false
@export var escala_hud_celular: float = 1.7
@export var escala_botoes_celular: float = 1.4
@export var zoom_camera_celular: float = 1.3

const JoystickScript := preload("res://scenes/ui/joystick_virtual.gd")
const PauseScript := preload("res://scenes/ui/pause_menu.gd")

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
		gerenciador.dificuldade_subiu.connect(_on_dificuldade_subiu)
		
	else:
		push_warning(
			"HUD: não encontrou o gerenciador em '%s' — o contador de derrotados e XP não vão atualizar."
			% [gerenciador_path]
		)

	_configurar_celular()

	print("HUD: escolha de novo ataque a cada %d abates, alcance a cada %d." % [kills_por_ataque, kills_por_alcance])


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

	# Vampirismo: recupera vida a cada inimigo derrotado
	if total > 0 and is_instance_valid(player):
		player.curar_por_abate()

	if total > 0 and kills_por_alcance > 0 and total % kills_por_alcance == 0:
		upgrade_panel.mostrar_upgrade_alcance()

	if total > 0 and kills_por_ataque > 0 and total % kills_por_ataque == 0:
		upgrade_panel.mostrar_escolha_ataque()


# Atalhos de teste: Ctrl+Shift+E = escolha de alcance, Ctrl+Shift+A ou Ctrl+Shift+K = tela de
# escolha de novo ataque (a mesma que aparece a cada 50 abates).
# Só funciona em execução pelo editor ou exportação com depuração.
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and event.ctrl_pressed and event.shift_pressed:
			upgrade_panel.mostrar_upgrade_alcance()
		elif (event.keycode == KEY_A or event.keycode == KEY_K) and event.ctrl_pressed and event.shift_pressed:
			# Mostra a tela de escolha de novo ataque (se todos já foram desbloqueados, não aparece nada)
			upgrade_panel.mostrar_escolha_ataque()


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

# Aviso rápido no topo quando os inimigos ficam mais fortes
func _on_dificuldade_subiu(nivel: int) -> void:
	var aviso := Label.new()
	aviso.text = "OS INIMIGOS FICARAM MAIS FORTES!  (Dificuldade %d)" % nivel
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tamanho: int = 30
	if _eh_celular():
		tamanho = int(tamanho * escala_hud_celular)
	aviso.add_theme_font_size_override("font_size", tamanho)
	aviso.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	aviso.add_theme_constant_override("outline_size", 8)

	add_child(aviso)
	# Largura total da tela com o texto centralizado (sempre fica no meio)
	var fator: float = escala_hud_celular if _eh_celular() else 1.0
	aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	aviso.offset_top = 200.0 * fator
	aviso.offset_bottom = 200.0 * fator + tamanho * 1.6

	var tw := aviso.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tw.tween_callback(aviso.queue_free)


func _on_nivel_subiu(novo_nivel: int) -> void:
	upgrade_panel.mostrar_upgrade(novo_nivel)


# ------------------------------
# Celular (joystick e interface maior)
# ------------------------------
func _eh_celular() -> bool:
	return (
		modo_celular_forcado
		or OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _configurar_celular() -> void:
	var celular: bool = _eh_celular()

	# Menu de pausa (tecla P): criado por último para ficar por cima de tudo
	var menu_pausa: Control = PauseScript.new()
	menu_pausa.upgrade_panel = upgrade_panel
	menu_pausa.escala = escala_botoes_celular if celular else 1.0
	menu_pausa.mostrar_botao_pausa = celular # botão na tela só no celular (no PC usa a tecla P)
	add_child(menu_pausa)

	# O joystick sempre existe: ele só reage a toques, então no computador fica invisível.
	var joystick: Control = JoystickScript.new()
	joystick.mostrar_dica = celular
	add_child(joystick)
	move_child(joystick, upgrade_panel.get_index()) # fica por baixo do painel de upgrade

	if not celular:
		return

	# Textos e barras maiores, para continuarem legíveis numa tela pequena
	for rotulo: Label in [
		health_label, timer_label, kills_label, level_label, xp_label,
		upgrade_panel.title_label, upgrade_panel.description_label
	]:
		var tamanho: int = rotulo.get_theme_font_size("font_size")
		rotulo.add_theme_font_size_override("font_size", int(tamanho * escala_hud_celular))

	for caminho in [
		"Margin/TopBar/VidaBox/SharkIcon",
		"Margin/TopBar/VidaBox/HealthBarContainer",
		"Margin/TopBar/KillsBox/CanIcon",
	]:
		var item := get_node_or_null(caminho) as Control
		if item:
			item.custom_minimum_size *= escala_hud_celular

	health_bar.custom_minimum_size *= escala_hud_celular
	xp_bar.custom_minimum_size *= escala_hud_celular

	var margem := get_node_or_null("Margin") as MarginContainer
	if margem:
		for lado in ["left", "top", "right", "bottom"]:
			var nome: String = "margin_" + lado
			margem.add_theme_constant_override(
				nome, int(margem.get_theme_constant(nome) * escala_hud_celular)
			)

	# Botões do painel de upgrade maiores, mais fáceis de tocar
	for botao: Button in upgrade_panel.botoes:
		botao.custom_minimum_size *= escala_botoes_celular
		var tamanho_botao: int = botao.get_theme_font_size("font_size")
		botao.add_theme_font_size_override("font_size", int(tamanho_botao * escala_botoes_celular))

	# Câmera mais próxima: tubarão e inimigos ficam maiores na tela pequena
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.zoom = Vector2.ONE * zoom_camera_celular
