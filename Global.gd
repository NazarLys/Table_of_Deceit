extends Node

var game_mode: String = "liar"  # or "devil", set in main_menu.gd
var character_selections: Dictionary = {}  # peer_id -> character_id chosen in lobby
var peer_to_seat: Dictionary = {}         # peer_id -> seat index in game (0-3)
var max_players: int = 4
