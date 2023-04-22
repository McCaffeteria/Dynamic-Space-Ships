extends Node3D

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AdressEntry

const Player = preload("res://Scenes/Player.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

var grav_array
const G = 6.6743 * pow(10, -11)
const M = (7.3 * pow(10, 11)) / 27 #kilograms
const MPLAYER = 80 #kilograms

# Called when the node enters the scene tree for the first time.
func _ready():
	init_grav()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_host_button_pressed():
	main_menu.hide()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed():
	main_menu.hide()
	
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.position = $PlayerSpawnLocation.position
	player.name = str(peer_id)
	add_child(player)

func init_grav():
	grav_array = get_node("StaticBody3D/GravityArray").get_children()

func calc_grav(target):
	var grav = Vector3() #newtons
	var dist = Vector3() #meters
	for g in grav_array:
		dist = g.position - target.position
		grav = grav + dist.normalized()  *  (G * ((M*MPLAYER)/dist.length()))
	return grav
