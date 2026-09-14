extends Panel

signal upgrade_escolhido

@export var player_path: NodePath

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

@onready var vida_button: Button = %VidaButton
@onready var dano_button: Button = %DanoButton
@onready var velocidade_button: Button = %VelocidadeButton

var player: Player
var nivel_pendente: int = 0
var aguardando_escolha: bool = false


func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()

	vida_button.pressed.connect(_on_vida_pressed)
	dano_button.pressed.connect(_on_dano_pressed)
	velocidade_button.pressed.connect(_on_velocidade_pressed)

	if player_path != NodePath():
		player = get_node_or_null(player_path) as Player

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


func mostrar_upgrade(nivel: int) -> void:
	nivel_pendente = nivel

	if aguardando_escolha:
		return

	aguardando_escolha = true

	title_label.text = "✦ Nível %d ✦" % nivel
	description_label.text = "Escolha uma melhoria"

	show()

	get_tree().paused = true


func _escolher_upgrade() -> void:
	aguardando_escolha = false
	hide()

	get_tree().paused = false

	upgrade_escolhido.emit()


func _on_vida_pressed() -> void:
	if not is_instance_valid(player):
		return

	player.aumentar_vida_maxima(20)

	_escolher_upgrade()


func _on_dano_pressed() -> void:
	if not is_instance_valid(player):
		return

	player.aumentar_dano(5)

	_escolher_upgrade()


func _on_velocidade_pressed() -> void:
	if not is_instance_valid(player):
		return

	player.aumentar_velocidade(20)

	_escolher_upgrade()
