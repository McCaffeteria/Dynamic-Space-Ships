extends Node3D

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AdressEntry

const Player = preload("res://Scenes/Player.tscn")
const PlayerStupid = preload("res://Scenes/PlayerStupid.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

@export var grav_array : Array
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
	
	#upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	
	if address_entry.text == "":
		enet_peer.create_client("localhost", PORT)
	else:
		enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player
	player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

func init_grav():
	grav_array = get_node("StaticBody3D/GravityArray").get_children()

func calc_grav(target):
	var grav = Vector3() #newtons
	var dist = Vector3() #meters
	for g in grav_array:
		dist = g.global_position - target.global_position
		if dist.length() != 0:
			grav = grav + dist.normalized()  *  (G * ((M*MPLAYER)/dist.length()))
	return grav

#func upnp_setup(): #Use NAT Hole Punching instead, I guess.
#	var upnp = UPNP.new()
#	
#	var discover_result = upnp.discover()
#	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
#		"UPNP Discover Failed! Error %s" % discover_result)
#	
#	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
#		"UPNP Invalid Gateway!")
#	
#	var map_result = upnp.add_port_mapping(PORT)
#	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
#		"UPNP Port Mapping Failed! Error %s" % map_result)
#	
#	print("Success! Join Address: %s" % upnp.query_external_adress())
