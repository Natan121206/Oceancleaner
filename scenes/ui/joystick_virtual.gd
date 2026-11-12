extends Control
## Joystick virtual flutuante para celular.
## O joystick aparece onde o dedo tocar (metade esquerda da tela) e alimenta as
## ações "left", "right", "up" e "down" — o Player lê essas ações e nem precisa
## saber se o comando veio do teclado ou do toque.

@export var raio_base: float = 150.0
@export var raio_knob: float = 65.0
@export_range(0.0, 0.5) var zona_morta: float = 0.1
@export var apenas_metade_esquerda: bool = true
# Mostra um círculo discreto no canto como dica de onde tocar (ligado em celulares)
@export var mostrar_dica: bool = false

const COR_BASE := Color(1, 1, 1, 0.14)
const COR_BORDA := Color(1, 1, 1, 0.40)
const COR_KNOB := Color(1, 1, 1, 0.45)

var _toque: int = -1
var _centro: Vector2 = Vector2.ZERO
var _pos: Vector2 = Vector2.ZERO
var _direcao: Vector2 = Vector2.ZERO


func _ready() -> void:
	# ALWAYS: assim ele também recebe eventos com o jogo pausado e consegue se soltar
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	_soltar()


func _input(event: InputEvent) -> void:
	# Se o jogo pausou (painel de upgrade) com o dedo na tela, solta o joystick
	if get_tree().paused:
		if _toque != -1:
			_soltar()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _toque == -1 and _area_valida(event.position):
				_toque = event.index
				_centro = event.position
				_atualizar(event.position)
		elif event.index == _toque:
			_soltar()

	elif event is InputEventScreenDrag:
		if event.index == _toque:
			_atualizar(event.position)


func _area_valida(posicao: Vector2) -> bool:
	if not apenas_metade_esquerda:
		return true

	return posicao.x < get_viewport_rect().size.x * 0.5


func _atualizar(posicao: Vector2) -> void:
	var delta: Vector2 = posicao - _centro
	var forca: float = clampf(delta.length() / raio_base, 0.0, 1.0)

	_pos = _centro + delta.limit_length(raio_base)

	if forca < zona_morta:
		_direcao = Vector2.ZERO
	else:
		_direcao = delta.normalized() * forca

	_aplicar_acoes()
	queue_redraw()


func _soltar() -> void:
	_toque = -1
	_direcao = Vector2.ZERO
	_aplicar_acoes()
	queue_redraw()


func _aplicar_acoes() -> void:
	_definir_acao("right", maxf(_direcao.x, 0.0))
	_definir_acao("left", maxf(-_direcao.x, 0.0))
	_definir_acao("down", maxf(_direcao.y, 0.0))
	_definir_acao("up", maxf(-_direcao.y, 0.0))


func _definir_acao(acao: String, forca: float) -> void:
	if forca > 0.0:
		Input.action_press(acao, forca)
	else:
		Input.action_release(acao)


func _draw() -> void:
	if _toque != -1:
		draw_circle(_centro, raio_base, COR_BASE)
		draw_arc(_centro, raio_base, 0.0, TAU, 64, COR_BORDA, 4.0, true)
		draw_circle(_pos, raio_knob, COR_KNOB)
	elif mostrar_dica:
		var dica := Vector2(raio_base + 90.0, size.y - raio_base - 70.0)
		draw_circle(dica, raio_base, Color(1, 1, 1, 0.07))
		draw_arc(dica, raio_base, 0.0, TAU, 64, Color(1, 1, 1, 0.20), 4.0, true)
		draw_circle(dica, raio_knob, Color(1, 1, 1, 0.16))
