extends Panel

signal upgrade_escolhido

@export var player_path: NodePath

# Chance (peso) de cada upgrade aparecer. Não precisa somar 100:
# a chance real é peso / soma dos pesos que ainda estão no sorteio.
@export_category("Chances (%)")
@export var peso_vida: float = 30.0
@export var peso_dano: float = 30.0
@export var peso_velocidade: float = 25.0
@export var peso_cadencia: float = 15.0
@export var peso_vampirismo: float = 15.0
@export var peso_ourico: float = 15.0

# Chance de cada ataque aparecer na escolha de NOVO ataque (a cada 50 abates)
@export_category("Chances - novo ataque (%)")
@export var peso_ataque_bolha: float = 35.0
@export var peso_ataque_pulso: float = 35.0
@export var peso_ataque_ourico: float = 30.0
# Quantas opções aparecem na escolha de novo ataque (use 3 para sempre mostrar todas as bloqueadas)
@export_range(1, 3) var opcoes_por_escolha_ataque: int = 2

# Chance de cada ataque aparecer na escolha de ALCANCE (a cada 30 abates)
@export_category("Chances - alcance (%)")
@export var peso_alcance_bolha: float = 25.0
@export var peso_alcance_pulso: float = 25.0
@export var peso_alcance_corte: float = 30.0
@export var peso_alcance_ourico: float = 20.0

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

# Os 3 botões que já existem na cena viram "slots": o conteúdo é definido por sorteio
@onready var vida_button: Button = %VidaButton
@onready var dano_button: Button = %DanoButton
@onready var velocidade_button: Button = %VelocidadeButton

var botoes: Array[Button] = []
var upgrades: Array[Dictionary] = []
var opcoes_atuais: Array[Dictionary] = []

var player: Player
var nivel_pendente: int = 0
var aguardando_escolha: bool = false


# Fonte com emojis COLORIDOS (a versão web não tem fontes do sistema, então sem isto os emojis viram quadrados)
const FONTE_EMOJI := "res://assets/fonts/NotoColorEmoji.ttf"


func _ativar_fonte_emoji() -> void:
	if not ResourceLoader.exists(FONTE_EMOJI):
		push_warning("Fonte de emojis não encontrada em %s" % FONTE_EMOJI)
		return

	var emoji := load(FONTE_EMOJI) as Font
	var base: Font = ThemeDB.fallback_font

	# Adiciona a fonte de emojis como reserva da fonte padrão do jogo
	if emoji != null and base != null and not base.fallbacks.has(emoji):
		base.fallbacks = [emoji]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ativar_fonte_emoji()

	hide()

	botoes = [vida_button, dano_button, velocidade_button]
	for i in botoes.size():
		botoes[i].pressed.connect(_on_botao_pressed.bind(i))

	_montar_lista_de_upgrades()

	if player_path != NodePath():
		player = get_node_or_null(player_path) as Player

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player


func _montar_lista_de_upgrades() -> void:
	upgrades = [
		{
			"texto": "❤️ VIDA\n\n+20 Vida Máxima",
			"peso": peso_vida,
			"aplicar": func(p: Player) -> void: p.aumentar_vida_maxima(20),
		},
		{
			"texto": "⚔️ DANO\n\n+5 Dano",
			"peso": peso_dano,
			"aplicar": func(p: Player) -> void: p.aumentar_dano(5),
		},
		{
			"texto": "🏃 VELOCIDADE\n\n+20 Velocidade",
			"peso": peso_velocidade,
			"aplicar": func(p: Player) -> void: p.aumentar_velocidade(20),
		},
		{
			"texto": "⚡ CADÊNCIA\n\n+15% Vel. de Ataque",
			"peso": peso_cadencia,
			"aplicar": func(p: Player) -> void: p.aumentar_cadencia(0.15),
		},
		{
			"texto": "🧛 ROUBA VIDA\n\n+3% da vida por abate",
			"peso": peso_vampirismo,
			"aplicar": func(p: Player) -> void: p.aumentar_vampirismo(0.03),
		},
		{
			"texto": "🦔 OURIÇO\n\n+1 ouriço orbital",
			"peso": peso_ourico,
			"aplicar": func(p: Player) -> void: p.aumentar_ouricos(1),
			# Só aparece depois de desbloquear o ouriço, e some quando chega ao máximo
			"disponivel": func(p: Player) -> bool:
				return p.tem_ataque("ourico") and p.ouricos < Player.OURICOS_MAXIMO,
		},
	]


# Sorteia `quantidade` upgrades de level up, respeitando o peso e a disponibilidade de cada um
func _sortear_opcoes(quantidade: int) -> Array[Dictionary]:
	var candidatas: Array[Dictionary] = []
	for u in upgrades:
		if u.has("disponivel") and is_instance_valid(player):
			var checar: Callable = u["disponivel"]
			if not checar.call(player):
				continue
		candidatas.append(u)

	return _sortear_por_peso(candidatas, quantidade)


# Roleta ponderada sem repetição: cada candidata precisa ter a chave "peso"
func _sortear_por_peso(candidatas: Array[Dictionary], quantidade: int) -> Array[Dictionary]:
	var disponiveis: Array[Dictionary] = candidatas.duplicate()
	var sorteados: Array[Dictionary] = []

	while sorteados.size() < quantidade and not disponiveis.is_empty():
		var total: float = 0.0
		for c in disponiveis:
			total += c["peso"]

		var roleta: float = randf() * total
		var escolhido: int = disponiveis.size() - 1

		for i in disponiveis.size():
			roleta -= disponiveis[i]["peso"]
			if roleta <= 0.0:
				escolhido = i
				break

		sorteados.append(disponiveis[escolhido])
		disponiveis.remove_at(escolhido)

	return sorteados


# Fila de escolhas pendentes (level up e alcance), mostradas uma de cada vez
var fila: Array[Dictionary] = []

const BONUS_ALCANCE: float = 0.20


func mostrar_upgrade(nivel: int) -> void:
	nivel_pendente = nivel
	fila.append({"tipo": "nivel", "nivel": nivel})
	_mostrar_proximo()


func mostrar_upgrade_alcance() -> void:
	fila.append({"tipo": "alcance"})
	_mostrar_proximo()


func mostrar_escolha_ataque() -> void:
	fila.append({"tipo": "ataque"})
	_mostrar_proximo()


func _mostrar_proximo() -> void:
	if aguardando_escolha:
		return

	while not fila.is_empty():
		var pedido: Dictionary = fila.pop_front()
		var opcoes: Array[Dictionary] = []

		match pedido["tipo"]:
			"alcance":
				title_label.text = "🌊 Alcance Ampliado 🌊"
				description_label.text = "Escolha um ataque para ampliar"
				opcoes = _sortear_por_peso(_opcoes_alcance(), botoes.size())
			"ataque":
				title_label.text = "⚔️ Novo Ataque ⚔️"
				description_label.text = "Desbloqueie um ataque ou melhore o principal"
				# Reserva um botão para o upgrade do ataque principal (sempre a última opção)
				opcoes = _sortear_por_peso(_opcoes_ataque(), mini(opcoes_por_escolha_ataque, botoes.size() - 1))
				opcoes.append_array(_opcao_ataque_principal())
			_:
				title_label.text = "⭐ Nível %d ⭐" % pedido["nivel"]
				description_label.text = "Escolha uma melhoria"
				opcoes = _sortear_opcoes(botoes.size())

		# Nada para escolher (ex.: todos os ataques já desbloqueados): pula este pedido
		if opcoes.is_empty():
			continue

		opcoes_atuais = opcoes
		aguardando_escolha = true

		# Mostra só os botões que têm opção
		for i in botoes.size():
			botoes[i].visible = i < opcoes_atuais.size()
			if botoes[i].visible:
				botoes[i].text = opcoes_atuais[i]["texto"]

		show()
		get_tree().paused = true
		return


# Candidatas de novo ataque: os que ainda estão bloqueados (a roleta escolhe quais aparecem)
func _opcoes_ataque() -> Array[Dictionary]:
	var itens: Array = [
		["bolha", "💧 BOLHA\n\nDispara bolhas no inimigo mais próximo", peso_ataque_bolha],
		["pulso", "🌀 PULSO\n\nOnda de dano em área ao seu redor", peso_ataque_pulso],
		["ourico", "🦔 OURIÇO\n\n%d ouriços girando ao seu redor" % Player.OURICOS_INICIAIS, peso_ataque_ourico],
	]

	var opcoes: Array[Dictionary] = []
	for item in itens:
		var ataque: String = item[0]
		if is_instance_valid(player) and player.tem_ataque(ataque):
			continue

		opcoes.append({
			"texto": item[1],
			"peso": item[2],
			"aplicar": func(p: Player) -> void: p.desbloquear_ataque(ataque),
		})

	return opcoes


# Upgrade do ataque principal do personagem. Hoje só existe o tubarão (espadada):
# cada escolha soma 1 golpe sucessivo. Some da lista quando chega no máximo.
func _opcao_ataque_principal() -> Array[Dictionary]:
	var opcoes: Array[Dictionary] = []
	if not is_instance_valid(player) or player.golpes_extras >= Player.GOLPES_EXTRAS_MAXIMO:
		return opcoes

	var golpes_atuais: int = 1 + player.golpes_extras
	opcoes.append({
		"texto": "⚔️ ESPADADA\n\n+1 golpe sucessivo\n(agora: %d → %d)" % [golpes_atuais, golpes_atuais + 1],
		"peso": 1.0,
		"aplicar": func(p: Player) -> void: p.aumentar_golpes_extras(1),
	})
	return opcoes


# Candidatas de alcance: só dos ataques que o jogador já tem (a roleta escolhe até 3)
func _opcoes_alcance() -> Array[Dictionary]:
	var itens: Array = [
		["bolha", "💧 BOLHA", "Alcance da bolha", peso_alcance_bolha],
		["pulso", "🌀 PULSO", "Raio do pulso", peso_alcance_pulso],
		["mordida", "🌊 CORTE", "Área do corte", peso_alcance_corte],
		["ourico", "🦔 OURIÇO", "Tamanho do ouriço", peso_alcance_ourico],
	]

	var opcoes: Array[Dictionary] = []
	for item in itens:
		var ataque: String = item[0]
		var atual: int = 0
		if is_instance_valid(player):
			if not player.tem_ataque(ataque):
				continue
			atual = player.alcance_extra_percentual(ataque)

		opcoes.append({
			"texto": "%s\n\n%s +%d%%\n(atual: +%d%%)" % [item[1], item[2], int(BONUS_ALCANCE * 100), atual],
			"peso": item[3],
			"aplicar": func(p: Player) -> void: p.aumentar_alcance(ataque, BONUS_ALCANCE),
		})

	return opcoes


func _escolher_upgrade() -> void:
	aguardando_escolha = false
	hide()

	get_tree().paused = false

	upgrade_escolhido.emit()

	# Se houver outra escolha na fila (ex.: level up junto com alcance), mostra em seguida
	_mostrar_proximo()


func _on_botao_pressed(indice: int) -> void:
	if not is_instance_valid(player) or indice >= opcoes_atuais.size():
		return

	var aplicar: Callable = opcoes_atuais[indice]["aplicar"]
	aplicar.call(player)

	_escolher_upgrade()
