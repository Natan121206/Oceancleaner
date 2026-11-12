extends Control
## Menu de pausa: tecla P pausa/continua o jogo. Tem "Continuar" e "Sair" (volta ao menu).
## É criado pelo HUD em código — não precisa de cena.

const CENA_MENU := "res://scenes/ui/start_screen.tscn"
const ESTILOS := {
	"normal": "res://padraoUpgrade.tres",
	"hover": "res://upgradeHover.tres",
	"pressed": "res://upgradePressed.tres",
}

# Painel de upgrade do HUD: se ele estiver aberto, a tecla P é ignorada
var upgrade_panel: Control = null
# Tamanho dos botões/textos (o HUD aumenta no celular)
var escala: float = 1.0
# Mostra o botão de pausa na tela (o HUD liga só no celular)
var mostrar_botao_pausa: bool = false

var _botao_continuar: Button
var _botao_pausa: Button

# Distância do topo da tela até o botão de pausa (aumente para descer)
const POSICAO_Y_BOTAO: float = 80.0


# Botão de pausa (dois traços), desenhado em código
class BotaoPausa extends Button:
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var cor := Color(1, 1, 1, 0.9)
		if button_pressed:
			cor = Color(0.10, 0.80, 0.80)
		elif is_hovered():
			cor = Color(0.55, 1.0, 1.0)

		var c: Vector2 = size / 2.0
		var alt: float = size.y * 0.30
		var larg: float = size.x * 0.09
		var folga: float = size.x * 0.12
		draw_rect(Rect2(c.x - folga - larg, c.y - alt, larg * 1.6, alt * 2.0), cor)
		draw_rect(Rect2(c.x + folga - larg * 0.6, c.y - alt, larg * 1.6, alt * 2.0), cor)


func _ready() -> void:
	# ALWAYS: precisa continuar recebendo teclas com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.65)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", int(16 * escala))
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "PAUSADO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", int(44 * escala))
	caixa.add_child(titulo)

	_botao_continuar = _criar_botao("Continuar")
	_botao_continuar.pressed.connect(_continuar)
	caixa.add_child(_botao_continuar)

	var botao_sair := _criar_botao("Sair")
	botao_sair.pressed.connect(_sair)
	caixa.add_child(botao_sair)

	# O botão de pausa precisa ficar fora deste menu (que começa escondido)
	_criar_botao_pausa.call_deferred()


# Botão de pausa no centro do topo da tela (para celular e também no computador)
func _criar_botao_pausa() -> void:
	var pai := get_parent()
	if pai == null or not mostrar_botao_pausa:
		return

	var lado: float = 84.0 * escala
	var margem: float = 24.0 * escala

	_botao_pausa = BotaoPausa.new()
	_botao_pausa.focus_mode = Control.FOCUS_NONE
	# Centralizado no topo, logo abaixo do cronômetro (o cronômetro ocupa o meio da barra de cima)
	_botao_pausa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_botao_pausa.offset_left = -lado / 2.0
	_botao_pausa.offset_right = lado / 2.0
	_botao_pausa.offset_top = POSICAO_Y_BOTAO * escala
	_botao_pausa.offset_bottom = POSICAO_Y_BOTAO * escala + lado

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.10, 0.15, 0.6)
	estilo.border_color = Color(1, 1, 1, 0.35)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(int(lado / 2.0))
	for nome in ["normal", "hover", "pressed", "focus"]:
		_botao_pausa.add_theme_stylebox_override(nome, estilo)

	_botao_pausa.pressed.connect(_on_botao_pausa)
	pai.add_child(_botao_pausa)
	pai.move_child(_botao_pausa, get_index()) # fica logo abaixo do menu de pausa


func _on_botao_pausa() -> void:
	if visible:
		_continuar()
	elif _pode_pausar():
		_pausar()


func _criar_botao(texto: String) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(280, 70) * escala
	botao.add_theme_font_size_override("font_size", int(26 * escala))

	# Usa o mesmo visual dos botões do painel de upgrade, se os arquivos existirem
	for estado in ESTILOS:
		if ResourceLoader.exists(ESTILOS[estado]):
			botao.add_theme_stylebox_override(estado, load(ESTILOS[estado]) as StyleBox)

	return botao


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode != KEY_P:
		return

	if visible:
		_continuar()
	elif _pode_pausar():
		_pausar()

	get_viewport().set_input_as_handled()


func _pode_pausar() -> bool:
	# Não pausa se outra coisa já pausou o jogo (painel de upgrade) ou se o jogador morreu
	if get_tree().paused:
		return false

	if is_instance_valid(upgrade_panel) and upgrade_panel.visible:
		return false

	var jogador := get_tree().get_first_node_in_group("player")
	if jogador and jogador.has_method("is_dead") and jogador.is_dead():
		return false

	return true


func _pausar() -> void:
	if _botao_pausa:
		_botao_pausa.hide()
	show()
	get_tree().paused = true
	_botao_continuar.grab_focus()


func _continuar() -> void:
	if _botao_pausa:
		_botao_pausa.show()
	hide()
	get_tree().paused = false


func _sair() -> void:
	# Despausa antes de trocar de cena, senão o menu inicial abriria congelado
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_MENU)
