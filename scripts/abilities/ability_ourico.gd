extends Node2D
## Habilidade "Ouriço Orbital": ouriços giram em volta do tubarão e ferem
## os inimigos que encostam neles. Cada upgrade adiciona mais um ouriço.
## Esse nó é criado pelo Player (aumentar_ouricos) na primeira vez que o upgrade é escolhido.

const TEXTURA := "res://assets/ui/Ourico.png"

@export var raio_orbita: float = 130.0
@export var velocidade_giro: float = 2.6      # radianos por segundo
@export var dano_proprio: int = 8
@export var intervalo_dano: float = 0.5       # segundos até o mesmo inimigo poder ser ferido de novo
@export var tamanho_visual: float = 72.0      # largura do ouriço na tela, em pixels
@export var raio_colisao: float = 30.0

# Multiplicador de tamanho (upgrade de alcance do ouriço): 1.0 = normal, 1.2 = +20%
var escala_tamanho: float = 1.0

var player: Node = null # o Player (sem tipo fixo para evitar referência circular)

var _ouricos: Array[Area2D] = []
var _angulo: float = 0.0
var _proximo_dano: Dictionary = {} # id do inimigo -> momento (ms) em que pode ser ferido de novo
var _textura: Texture2D = null


func _ready() -> void:
	if ResourceLoader.exists(TEXTURA):
		_textura = load(TEXTURA) as Texture2D


# Recria os ouriços para a quantidade informada, espalhados igualmente na órbita
func definir_quantidade(quantidade: int) -> void:
	for o in _ouricos:
		o.queue_free()
	_ouricos.clear()

	for i in quantidade:
		var ourico := _criar_ourico()
		add_child(ourico)
		_ouricos.append(ourico)


# Aumenta o tamanho dos ouriços (visual e área de dano juntos)
func definir_escala(multiplicador: float) -> void:
	escala_tamanho = multiplicador
	for o in _ouricos:
		o.scale = Vector2.ONE * escala_tamanho


func _criar_ourico() -> Area2D:
	var area := Area2D.new()
	area.monitorable = false
	area.scale = Vector2.ONE * escala_tamanho

	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = raio_colisao
	forma.shape = circulo
	area.add_child(forma)

	if _textura:
		var sprite := Sprite2D.new()
		sprite.texture = _textura
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# A arte tem margem transparente: o ouriço ocupa ~73% da largura da imagem
		var escala: float = tamanho_visual / (_textura.get_width() * 0.73)
		sprite.scale = Vector2.ONE * escala
		area.add_child(sprite)
	else:
		# Sem a imagem no projeto, desenha uma bola roxa no lugar
		var bola := Polygon2D.new()
		var pontos := PackedVector2Array()
		for k in 24:
			pontos.append(Vector2.RIGHT.rotated(TAU * k / 24.0) * tamanho_visual * 0.4)
		bola.polygon = pontos
		bola.color = Color(0.45, 0.2, 0.7)
		area.add_child(bola)

	area.z_index = 4
	return area


func _physics_process(delta: float) -> void:
	if _ouricos.is_empty() or not is_instance_valid(player):
		return

	if player.is_dead():
		return

	# Cadência de ataque também acelera o giro dos ouriços
	var cadencia: float = player.attack_speed_multiplier
	_angulo += velocidade_giro * cadencia * delta

	var total: int = _ouricos.size()
	for i in total:
		var ourico: Area2D = _ouricos[i]
		ourico.position = Vector2.RIGHT.rotated(_angulo + TAU * i / total) * raio_orbita
		ourico.rotation += 5.0 * delta # giro do próprio ouriço

		for corpo in ourico.get_overlapping_bodies():
			_tentar_ferir(corpo, cadencia)


func _tentar_ferir(corpo: Node, cadencia: float) -> void:
	if not corpo.is_in_group("enemies") or not corpo.visible:
		return

	if not corpo.has_method("take_damage"):
		return

	var agora: int = Time.get_ticks_msec()
	var id: int = corpo.get_instance_id()

	if _proximo_dano.get(id, 0) > agora:
		return

	_proximo_dano[id] = agora + int(intervalo_dano / cadencia * 1000.0)
	corpo.take_damage(player.attack_damage + dano_proprio)
