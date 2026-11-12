extends Inimigo
class_name InimigoSuco
## Caixinha de suco: inimigo de longa distância.
## Herda tudo do Inimigo (vida, dano recebido, morte, pool, XP) e troca só o
## comportamento: em vez de correr até o tubarão, mantém distância e cospe suco.

const PROJETIL_SCENE := preload("res://scenes/suco_projetil.tscn")

@export_category("Longa distância")
@export var distancia_ideal: float = 320.0   # tenta ficar por aqui
@export var distancia_minima: float = 230.0  # se o tubarão chegar mais perto, ela recua
@export var alcance_tiro: float = 520.0      # só atira se o tubarão estiver dentro deste raio
@export var cooldown_tiro: float = 2.2
@export var dano_tiro: int = 8
@export var velocidade_projetil: float = 320.0

var _tempo_tiro: float = 0.0
var _dano_tiro_base: int = 0


func _ready() -> void:
	super()
	_dano_tiro_base = dano_tiro
	_tempo_tiro = randf_range(0.5, cooldown_tiro)


# Além de vida/velocidade/dano, o dano do tiro também sobe com a dificuldade
func aplicar_dificuldade(mult_vida: float, mult_dano: float, mult_velocidade: float) -> void:
	super(mult_vida, mult_dano, mult_velocidade)
	dano_tiro = maxi(1, roundi(_dano_tiro_base * mult_dano))


func renascer(posicao_spawn: Vector2, alvo: Node2D) -> void:
	super(posicao_spawn, alvo)
	_tempo_tiro = randf_range(0.5, cooldown_tiro)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Escondido = guardado no pool: não pode agir nem atirar
	if not visible:
		set_physics_process(false)
		return

	_garantir_visivel()

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player.has_method("is_dead") and player.is_dead():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var para_player: Vector2 = player.global_position - global_position
	var dist: float = para_player.length()
	var direcao: Vector2 = para_player.normalized()

	# Aproxima, recua ou fica parada, conforme a distância
	if dist > detection_range:
		velocity = Vector2.ZERO
	elif dist > distancia_ideal:
		velocity = direcao * speed
	elif dist < distancia_minima:
		velocity = -direcao * speed * 0.8
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_face_target(player.global_position)

	# Atira quando o tubarão está ao alcance E a caixinha está visível na tela
	# (sem isso ela atirava de fora da tela, principalmente no celular, onde a câmera é mais próxima)
	_tempo_tiro -= delta
	if _tempo_tiro <= 0.0 and dist <= alcance_tiro and _esta_na_tela():
		_tempo_tiro = cooldown_tiro
		_atirar()


func _esta_na_tela() -> bool:
	var pos_na_tela: Vector2 = get_global_transform_with_canvas().origin
	return get_viewport_rect().grow(-30.0).has_point(pos_na_tela)


func _atirar() -> void:
	var origem: Vector2 = global_position + Vector2(0, -60) # altura do canudo/boca
	var alvo: Vector2 = player.global_position + Vector2(0, -35) # centro do corpo do tubarão

	var tiro := PROJETIL_SCENE.instantiate()
	tiro.damage = dano_tiro
	tiro.velocity = origem.direction_to(alvo) * velocidade_projetil

	get_tree().current_scene.add_child(tiro)
	tiro.global_position = origem
