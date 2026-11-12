extends Control
## Tela de Fim de Jogo: mostra o resultado da partida em cartões (tempo e abates),
## compara com os recordes salvos, e oferece "Tentar Novamente" e "Menu Principal".
## A interface é montada em código (mesmo estilo da tela inicial).

const CENA_JOGO := "res://scenes/maps/testmapa.tscn"
const CENA_MENU := "res://scenes/ui/start_screen.tscn"
const TEX_FUNDO := "res://assets/ui/game_over_bg.png"
const TEX_LATA := "res://assets/ui/can_villain.png"
const ARQUIVO_RECORDES := "user://recordes.cfg"

const COR_DESTAQUE := Color(0.10, 0.80, 0.80)
const COR_DESTAQUE_ESCURA := Color(0.05, 0.45, 0.47)
const COR_PERIGO := Color(0.90, 0.36, 0.33)
const COR_PAINEL := Color(0.06, 0.07, 0.11, 0.88)

var _conteudo: Control
var _bolhas: CPUParticles2D
var _botao_retry: Button
var _valor_tempo: Label
var _valor_kills: Label
var _sub_tempo: Label
var _sub_kills: Label
var _mensagem: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_montar_fundo()
	_montar_conteudo()

	MusicaFundo.stream_paused = true

	_botao_retry.grab_focus()
	_mostrar_resultados()

	# Entrada suave
	_conteudo.modulate.a = 0.0
	create_tween().tween_property(_conteudo, "modulate:a", 1.0, 0.6)


# ------------------------------
# Resultados e recordes
# ------------------------------
func _mostrar_resultados() -> void:
	var kills: int = get_tree().get_meta("inimigos_derrotados", 0)
	var tempo: float = get_tree().get_meta("tempo_sobrevivido", 0.0)

	# Recordes anteriores (arquivo no computador/navegador do jogador)
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO_RECORDES) # se o arquivo não existir, fica tudo vazio
	var melhor_tempo: float = cfg.get_value("recordes", "melhor_tempo", 0.0)
	var melhor_kills: int = cfg.get_value("recordes", "melhor_kills", 0)

	var recorde_tempo: bool = tempo > melhor_tempo and tempo >= 1.0
	var recorde_kills: bool = kills > melhor_kills and kills >= 1

	if recorde_tempo or recorde_kills:
		cfg.set_value("recordes", "melhor_tempo", maxf(tempo, melhor_tempo))
		cfg.set_value("recordes", "melhor_kills", maxi(kills, melhor_kills))
		cfg.save(ARQUIVO_RECORDES)

	# Números contando de zero até o valor final
	var t := create_tween().set_parallel(true)
	t.tween_method(
		func(v: float) -> void: _valor_tempo.text = _formatar_tempo(v),
		0.0, tempo, 1.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.4)
	t.tween_method(
		func(v: float) -> void: _valor_kills.text = str(int(round(v))),
		0.0, float(kills), 1.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.4)

	_configurar_sub(_sub_tempo, recorde_tempo, "Recorde: %s" % _formatar_tempo(melhor_tempo), melhor_tempo > 0.0)
	_configurar_sub(_sub_kills, recorde_kills, "Recorde: %d" % melhor_kills, melhor_kills > 0)

	_mensagem.text = _frase_final(tempo)


func _configurar_sub(rotulo: Label, novo_recorde: bool, texto_recorde: String, tem_recorde: bool) -> void:
	if novo_recorde:
		rotulo.text = "NOVO RECORDE!"
		rotulo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	elif tem_recorde:
		rotulo.text = texto_recorde
		rotulo.add_theme_color_override("font_color", Color(0.62, 0.70, 0.75))
	else:
		rotulo.text = ""


func _frase_final(tempo: float) -> String:
	if tempo < 60.0:
		return "O oceano ainda precisa de você. Tente de novo!"
	if tempo < 180.0:
		return "Boa luta! A poluição sentiu o golpe."
	return "Que limpeza! Os mares agradecem, herói."


func _formatar_tempo(segundos: float) -> String:
	var total: int = int(segundos)
	return "%02d:%02d" % [total / 60, total % 60]


# ------------------------------
# Fundo: imagem escura, vinheta vermelha e bolhas
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
	tinta.color = Color(0.10, 0.02, 0.04, 0.60)
	tinta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tinta)

	var vinheta := TextureRect.new()
	vinheta.texture = _textura_radial(
		[0.0, 0.55, 1.0],
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.1), Color(0.03, 0, 0.02, 0.88)]
	)
	vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vinheta)

	_bolhas = CPUParticles2D.new()
	_bolhas.texture = _textura_radial(
		[0.0, 0.7, 1.0],
		[Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.20), Color(1, 1, 1, 0.0)]
	)
	_bolhas.amount = 25
	_bolhas.lifetime = 11.0
	_bolhas.preprocess = 11.0
	_bolhas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bolhas.direction = Vector2(0, -1)
	_bolhas.spread = 10.0
	_bolhas.gravity = Vector2.ZERO
	_bolhas.initial_velocity_min = 25.0
	_bolhas.initial_velocity_max = 70.0
	_bolhas.scale_amount_min = 0.15
	_bolhas.scale_amount_max = 0.6
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
	tex.fill_to = Vector2(1.0, 0.5)
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

	# Vilã: lata com brilho vermelho atrás e balançando devagar
	var palco := Control.new()
	palco.custom_minimum_size = Vector2(260, 220)
	palco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(palco)

	var brilho := TextureRect.new()
	brilho.texture = _textura_radial(
		[0.0, 1.0], [Color(0.9, 0.15, 0.12, 0.45), Color(0.9, 0.15, 0.12, 0.0)]
	)
	brilho.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brilho.stretch_mode = TextureRect.STRETCH_SCALE
	brilho.size = Vector2(260, 220)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(brilho)

	var lata := TextureRect.new()
	lata.texture = load(TEX_LATA) as Texture2D
	lata.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lata.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lata.size = Vector2(200, 200)
	lata.position = Vector2(30, 10)
	lata.pivot_offset = Vector2(100, 100)
	lata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(lata)

	var balanco := lata.create_tween().set_loops()
	balanco.tween_property(lata, "rotation_degrees", 4.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	balanco.tween_property(lata, "rotation_degrees", -4.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sobrancelha := Label.new()
	sobrancelha.text = "A POLUIÇÃO VENCEU ESTA BATALHA"
	sobrancelha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sobrancelha.add_theme_font_size_override("font_size", 22)
	sobrancelha.add_theme_color_override("font_color", COR_PERIGO)
	sobrancelha.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sobrancelha.add_theme_constant_override("outline_size", 5)
	caixa.add_child(sobrancelha)

	var titulo := Label.new()
	titulo.text = "FIM DE JOGO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 88)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.97, 0.97))
	titulo.add_theme_color_override("font_outline_color", Color(0.28, 0.03, 0.06))
	titulo.add_theme_constant_override("outline_size", 14)
	titulo.add_theme_color_override("font_shadow_color", Color(0.9, 0.2, 0.2, 0.35))
	titulo.add_theme_constant_override("shadow_offset_y", 6)
	caixa.add_child(titulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 6)
	caixa.add_child(espaco)

	# Cartões de resultado
	var cartoes := HBoxContainer.new()
	cartoes.alignment = BoxContainer.ALIGNMENT_CENTER
	cartoes.add_theme_constant_override("separation", 36)
	caixa.add_child(cartoes)

	var tempo_card := _criar_cartao("TEMPO SOBREVIVIDO")
	cartoes.add_child(tempo_card["painel"])
	_valor_tempo = tempo_card["valor"]
	_sub_tempo = tempo_card["sub"]

	var kills_card := _criar_cartao("INIMIGOS DERROTADOS")
	cartoes.add_child(kills_card["painel"])
	_valor_kills = kills_card["valor"]
	_sub_kills = kills_card["sub"]

	_mensagem = Label.new()
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensagem.add_theme_font_size_override("font_size", 22)
	_mensagem.add_theme_color_override("font_color", Color(0.80, 0.88, 0.90))
	_mensagem.add_theme_constant_override("outline_size", 4)
	_mensagem.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caixa.add_child(_mensagem)

	# Botões
	_botao_retry = _criar_botao_principal("TENTAR NOVAMENTE")
	_botao_retry.pressed.connect(_on_retry_pressed)
	caixa.add_child(_botao_retry)

	var botao_menu := Button.new()
	botao_menu.text = "Menu Principal"
	botao_menu.flat = true
	botao_menu.custom_minimum_size = Vector2(240, 40)
	botao_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botao_menu.add_theme_font_size_override("font_size", 20)
	botao_menu.add_theme_color_override("font_color", Color(0.75, 0.85, 0.88))
	botao_menu.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	botao_menu.pressed.connect(_on_menu_pressed)
	caixa.add_child(botao_menu)


func _criar_cartao(titulo: String) -> Dictionary:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(380, 190)

	var estilo := _estilo(COR_PAINEL, Color(0.35, 0.18, 0.22), 24, 3)
	estilo.set_border_width_all(3)
	estilo.shadow_color = Color(0, 0, 0, 0.45)
	estilo.shadow_size = 22
	painel.add_theme_stylebox_override("panel", estilo)

	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 4)
	painel.add_child(coluna)

	var nome := Label.new()
	nome.text = titulo
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 20)
	nome.add_theme_color_override("font_color", Color(0.65, 0.78, 0.82))
	coluna.add_child(nome)

	var valor := Label.new()
	valor.text = "0"
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	valor.add_theme_font_size_override("font_size", 82)
	valor.add_theme_color_override("font_color", Color(1, 1, 1))
	valor.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.12))
	valor.add_theme_constant_override("outline_size", 8)
	coluna.add_child(valor)

	var sub := Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.custom_minimum_size = Vector2(0, 28)
	coluna.add_child(sub)

	return {"painel": painel, "valor": valor, "sub": sub}


func _criar_botao_principal(texto: String) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(420, 76)
	botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botao.add_theme_font_size_override("font_size", 32)
	botao.add_theme_color_override("font_color", Color(1, 1, 1))
	botao.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	botao.add_theme_stylebox_override("normal", _estilo(COR_DESTAQUE_ESCURA, COR_DESTAQUE, 22, 6))
	botao.add_theme_stylebox_override("hover", _estilo(Color(0.07, 0.58, 0.60), Color(0.5, 1.0, 1.0), 22, 6))
	botao.add_theme_stylebox_override("pressed", _estilo(Color(0.04, 0.38, 0.40), COR_DESTAQUE, 22, 2))
	botao.add_theme_stylebox_override("focus", _estilo(Color(0.07, 0.58, 0.60), Color(0.5, 1.0, 1.0), 22, 6))

	botao.resized.connect(func() -> void: botao.pivot_offset = botao.size / 2.0)
	botao.mouse_entered.connect(func() -> void:
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
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


# ------------------------------
# Botões
# ------------------------------
func _limpar_resultados() -> void:
	if get_tree().has_meta("inimigos_derrotados"):
		get_tree().remove_meta("inimigos_derrotados")
	if get_tree().has_meta("tempo_sobrevivido"):
		get_tree().remove_meta("tempo_sobrevivido")


func _on_retry_pressed() -> void:
	_limpar_resultados()
	MusicaFundo.reiniciar()
	get_tree().change_scene_to_file(CENA_JOGO)


func _on_menu_pressed() -> void:
	_limpar_resultados()
	get_tree().change_scene_to_file(CENA_MENU)
