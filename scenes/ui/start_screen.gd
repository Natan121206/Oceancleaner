extends Control
## Menu inicial: fundo do oceano com bolhas, título, seletor de personagem
## (setas para trocar) e botão de começar. Personagens bloqueados ficam escurecidos
## ("em breve") e o botão de começar fica cinza e sem clique.
## A interface é montada em código, então esta cena só precisa deste script e da música.

const CENA_JOGO := "res://scenes/maps/testmapa.tscn"
const TEX_FUNDO := "res://assets/ui/start_bg.png"
const TEX_TUBARAO := "res://assets/ui/shark_hero.png"

const COR_DESTAQUE := Color(0.10, 0.80, 0.80)
const COR_DESTAQUE_ESCURA := Color(0.05, 0.45, 0.47)
const COR_PAINEL := Color(0.04, 0.10, 0.15, 0.88)
const COR_BLOQUEADO := Color(0.42, 0.47, 0.52)

@onready var musica_menu: AudioStreamPlayer = $MusicaLobby

# Lista de personagens. Para adicionar um novo no futuro: "disponivel": true e a textura dele.
var personagens: Array[Dictionary] = [
	{
		"id": "tubarao", "nome": "Tubarão", "desc": "Guerreiro das profundezas",
		"disponivel": true, "textura": TEX_TUBARAO,
	},
	{
		"id": "futuro_1", "nome": "???", "desc": "Um novo herói está a caminho...",
		"disponivel": false, "textura": TEX_TUBARAO,
	},
	{
		"id": "futuro_2", "nome": "???", "desc": "Um novo herói está a caminho...",
		"disponivel": false, "textura": TEX_TUBARAO,
	},
]

var indice: int = 0

var _conteudo: Control
var _palco: Panel
var _personagem: TextureRect
var _interrogacao: Label
var _nome: Label
var _desc: Label
var _status: Label
var _botao_comecar: Button
var _pontos: Array[Panel] = []
var _bolhas: CPUParticles2D
var _troca_tween: Tween


# Seta desenhada em código (não depende de fonte/emoji)
class Seta extends Button:
	var direcao: int = 1

	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var cor := Color(1, 1, 1, 0.85)
		if is_hovered():
			cor = Color(0.55, 1.0, 1.0)
		if button_pressed:
			cor = Color(0.10, 0.80, 0.80)

		var c: Vector2 = size / 2.0
		var dx: float = 13.0 * direcao
		draw_polyline(
			PackedVector2Array([
				c + Vector2(-dx, -28), c + Vector2(dx, 0), c + Vector2(-dx, 28)
			]),
			cor, 9.0, true
		)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_montar_fundo()
	_montar_conteudo()
	_atualizar_personagem(0)

	MusicaFundo.stream_paused = true

	# A música do menu também precisa repetir (o MP3 não faz loop sozinho)
	if musica_menu.stream is AudioStreamMP3:
		musica_menu.stream.loop = true
	musica_menu.finished.connect(musica_menu.play)

	# Entrada suave
	_conteudo.modulate.a = 0.0
	create_tween().tween_property(_conteudo, "modulate:a", 1.0, 0.6)

	if _botao_comecar.disabled:
		_botao_comecar.focus_mode = Control.FOCUS_NONE
	else:
		_botao_comecar.grab_focus()


# ------------------------------
# Fundo: imagem escurecida, vinheta e bolhas subindo
# ------------------------------
func _montar_fundo() -> void:
	var fundo := TextureRect.new()
	fundo.texture = load(TEX_FUNDO) as Texture2D
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var tinta := ColorRect.new()
	tinta.color = Color(0.0, 0.10, 0.16, 0.55)
	tinta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tinta)

	var vinheta := TextureRect.new()
	vinheta.texture = _textura_radial(
		[0.0, 0.55, 1.0],
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.1), Color(0, 0.02, 0.05, 0.85)]
	)
	vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vinheta)

	_bolhas = CPUParticles2D.new()
	_bolhas.texture = _textura_radial(
		[0.0, 0.7, 1.0],
		[Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.0)]
	)
	_bolhas.amount = 45
	_bolhas.lifetime = 10.0
	_bolhas.preprocess = 10.0
	_bolhas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bolhas.direction = Vector2(0, -1)
	_bolhas.spread = 10.0
	_bolhas.gravity = Vector2.ZERO
	_bolhas.initial_velocity_min = 35.0
	_bolhas.initial_velocity_max = 90.0
	_bolhas.scale_amount_min = 0.15
	_bolhas.scale_amount_max = 0.7
	add_child(_bolhas)

	resized.connect(_posicionar_bolhas)
	_posicionar_bolhas()


func _posicionar_bolhas() -> void:
	_bolhas.emission_rect_extents = Vector2(size.x / 2.0, 10.0)
	_bolhas.position = Vector2(size.x / 2.0, size.y + 40.0)


func _textura_radial(offsets: Array, cores: Array) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(offsets)
	grad.colors = PackedColorArray(cores)

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5) # raio = metade da textura (centro até a borda)
	tex.width = 128
	tex.height = 128
	return tex


# ------------------------------
# Interface
# ------------------------------
func _montar_conteudo() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	_conteudo = centro

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(caixa)

	# Título
	var titulo := Label.new()
	titulo.text = "OCEAN CLEANERS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 88)
	titulo.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0))
	titulo.add_theme_color_override("font_outline_color", Color(0.02, 0.22, 0.28))
	titulo.add_theme_constant_override("outline_size", 14)
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0.8, 0.8, 0.35))
	titulo.add_theme_constant_override("shadow_offset_y", 6)
	caixa.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "LIMPE OS MARES  •  DERROTE A POLUIÇÃO"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 22)
	subtitulo.add_theme_color_override("font_color", Color(0.55, 0.92, 0.92))
	subtitulo.add_theme_constant_override("outline_size", 4)
	subtitulo.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.15))
	caixa.add_child(subtitulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 8)
	caixa.add_child(espaco)

	# Seletor: seta | cartão do personagem | seta
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 40)
	caixa.add_child(linha)

	var seta_esq := _criar_seta(-1)
	linha.add_child(seta_esq)
	linha.add_child(_criar_palco())
	var seta_dir := _criar_seta(1)
	linha.add_child(seta_dir)

	# Bolinhas indicando quantos personagens existem
	var pontos := HBoxContainer.new()
	pontos.alignment = BoxContainer.ALIGNMENT_CENTER
	pontos.add_theme_constant_override("separation", 12)
	caixa.add_child(pontos)
	for i in personagens.size():
		var ponto := Panel.new()
		ponto.custom_minimum_size = Vector2(14, 14)
		pontos.add_child(ponto)
		_pontos.append(ponto)

	# Botões
	_botao_comecar = _criar_botao_comecar()
	caixa.add_child(_botao_comecar)

	var botao_sair := Button.new()
	botao_sair.text = "Sair"
	botao_sair.flat = true
	botao_sair.custom_minimum_size = Vector2(200, 40)
	botao_sair.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botao_sair.add_theme_font_size_override("font_size", 20)
	botao_sair.add_theme_color_override("font_color", Color(0.75, 0.85, 0.88))
	botao_sair.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	botao_sair.pressed.connect(_on_quit_pressed)
	caixa.add_child(botao_sair)

	# Versão no canto
	var versao := Label.new()
	versao.text = "beta 0.6"
	versao.add_theme_font_size_override("font_size", 16)
	versao.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	versao.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	versao.position -= Vector2(90, 40)
	add_child(versao)


func _criar_seta(direcao: int) -> Button:
	var seta := Seta.new()
	seta.direcao = direcao
	seta.custom_minimum_size = Vector2(90, 120)
	seta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seta.flat = true
	seta.focus_mode = Control.FOCUS_NONE
	seta.pressed.connect(_trocar.bind(direcao))
	return seta


func _criar_palco() -> Panel:
	_palco = Panel.new()
	_palco.custom_minimum_size = Vector2(460, 470)

	# Sombra suave no chão, sob o personagem
	var sombra := TextureRect.new()
	sombra.texture = _textura_radial(
		[0.0, 1.0], [Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)]
	)
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.position = Vector2(110, 300)
	sombra.size = Vector2(240, 44)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(sombra)

	_personagem = TextureRect.new()
	_personagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_personagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_personagem.position = Vector2(80, 30)
	_personagem.size = Vector2(300, 300)
	_personagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(_personagem)

	# Personagem flutuando devagar
	var flutuar := _personagem.create_tween().set_loops()
	flutuar.tween_property(_personagem, "position:y", 18.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flutuar.tween_property(_personagem, "position:y", 38.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_interrogacao = Label.new()
	_interrogacao.text = "?"
	_interrogacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interrogacao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interrogacao.add_theme_font_size_override("font_size", 170)
	_interrogacao.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9, 0.85))
	_interrogacao.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.1))
	_interrogacao.add_theme_constant_override("outline_size", 10)
	_interrogacao.position = Vector2(80, 30)
	_interrogacao.size = Vector2(300, 300)
	_interrogacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(_interrogacao)

	_nome = _criar_rotulo_palco(352, 46, 40)
	_nome.add_theme_constant_override("outline_size", 8)
	_nome.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.1))

	_desc = _criar_rotulo_palco(398, 28, 20)
	_desc.add_theme_color_override("font_color", Color(0.75, 0.88, 0.9))

	_status = _criar_rotulo_palco(430, 28, 18)

	return _palco


func _criar_rotulo_palco(y: float, altura: float, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.position = Vector2(0, y)
	rotulo.size = Vector2(460, altura)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(rotulo)
	return rotulo


func _criar_botao_comecar() -> Button:
	var botao := Button.new()
	botao.text = "COMEÇAR"
	botao.custom_minimum_size = Vector2(380, 76)
	botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botao.add_theme_font_size_override("font_size", 32)
	botao.add_theme_color_override("font_color", Color(1, 1, 1))
	botao.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	botao.add_theme_color_override("font_disabled_color", Color(0.6, 0.64, 0.68))
	botao.add_theme_stylebox_override("normal", _estilo(COR_DESTAQUE_ESCURA, COR_DESTAQUE, 22, 6))
	botao.add_theme_stylebox_override("hover", _estilo(Color(0.07, 0.58, 0.60), Color(0.5, 1.0, 1.0), 22, 6))
	botao.add_theme_stylebox_override("pressed", _estilo(Color(0.04, 0.38, 0.40), COR_DESTAQUE, 22, 2))
	botao.add_theme_stylebox_override("focus", _estilo(Color(0.07, 0.58, 0.60), Color(0.5, 1.0, 1.0), 22, 6))
	botao.add_theme_stylebox_override("disabled", _estilo(Color(0.20, 0.23, 0.26), Color(0.30, 0.34, 0.38), 22, 6))
	botao.pressed.connect(_on_start_pressed)

	# Cresce um pouquinho ao passar o mouse
	botao.resized.connect(func() -> void: botao.pivot_offset = botao.size / 2.0)
	botao.mouse_entered.connect(func() -> void:
		if not botao.disabled:
			create_tween().tween_property(botao, "scale", Vector2(1.05, 1.05), 0.12)
	)
	botao.mouse_exited.connect(func() -> void:
		create_tween().tween_property(botao, "scale", Vector2.ONE, 0.12)
	)
	return botao


func _estilo(cor: Color, borda: Color, raio: int, borda_baixo: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(2)
	s.border_width_bottom = borda_baixo
	s.set_corner_radius_all(raio)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s


# ------------------------------
# Troca de personagem
# ------------------------------
func _trocar(direcao: int) -> void:
	indice = wrapi(indice + direcao, 0, personagens.size())
	_atualizar_personagem(direcao)


func _atualizar_personagem(direcao: int) -> void:
	var p: Dictionary = personagens[indice]
	var disponivel: bool = p["disponivel"]

	_personagem.texture = load(p["textura"]) as Texture2D
	# Bloqueado: vira uma silhueta escura
	_personagem.modulate = Color(1, 1, 1, 1) if disponivel else Color(0.0, 0.03, 0.06, 0.55)
	_interrogacao.visible = not disponivel

	_nome.text = p["nome"]
	_nome.add_theme_color_override("font_color", Color(1, 1, 1) if disponivel else COR_BLOQUEADO)
	_desc.text = p["desc"]

	if disponivel:
		_status.text = "DISPONÍVEL"
		_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
	else:
		_status.text = "EM BREVE"
		_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))

	# Cartão: brilho verde-água se disponível, cinza se bloqueado
	var borda: Color = COR_DESTAQUE if disponivel else Color(0.30, 0.35, 0.40)
	var estilo := _estilo(COR_PAINEL, borda, 28, 2)
	estilo.set_border_width_all(3)
	estilo.shadow_color = Color(COR_DESTAQUE, 0.35) if disponivel else Color(0, 0, 0, 0.4)
	estilo.shadow_size = 28
	_palco.add_theme_stylebox_override("panel", estilo)

	# Botão de começar: só funciona com personagem disponível
	_botao_comecar.disabled = not disponivel
	_botao_comecar.text = "COMEÇAR" if disponivel else "EM BREVE"
	_botao_comecar.scale = Vector2.ONE
	if disponivel:
		_botao_comecar.focus_mode = Control.FOCUS_ALL
		if is_inside_tree():
			_botao_comecar.grab_focus()
	else:
		_botao_comecar.release_focus()
		_botao_comecar.focus_mode = Control.FOCUS_NONE

	# Bolinhas indicadoras
	for i in _pontos.size():
		var ativo: bool = i == indice
		var ponto := StyleBoxFlat.new()
		ponto.bg_color = COR_DESTAQUE if ativo else Color(1, 1, 1, 0.25)
		ponto.set_corner_radius_all(7)
		_pontos[i].add_theme_stylebox_override("panel", ponto)
		_pontos[i].custom_minimum_size = Vector2(34, 14) if ativo else Vector2(14, 14)

	# Animação: o personagem desliza para o lugar
	if direcao != 0:
		if _troca_tween and _troca_tween.is_valid():
			_troca_tween.kill()
		var alvo_a: float = _personagem.modulate.a
		_personagem.position.x = 80.0 + 70.0 * direcao
		_personagem.modulate.a = 0.0
		_troca_tween = create_tween().set_parallel(true)
		_troca_tween.tween_property(_personagem, "position:x", 80.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_troca_tween.tween_property(_personagem, "modulate:a", alvo_a, 0.25)


func _input(event: InputEvent) -> void:
	# Setas do teclado (ou A/D) também trocam o personagem
	if event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		_trocar(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		_trocar(1)
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	var p: Dictionary = personagens[indice]
	if not p["disponivel"]:
		return

	# Guarda o personagem escolhido para o jogo ler depois (por enquanto só o tubarão)
	get_tree().set_meta("personagem_escolhido", p["id"])

	musica_menu.stop()
	MusicaFundo.reiniciar()
	get_tree().change_scene_to_file(CENA_JOGO)


func _on_quit_pressed() -> void:
	get_tree().quit()
