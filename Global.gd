extends Node

var game_mode: String = "liar"  # "liar" or "devil"
var character_selections := {}  # peer_id -> character_id
var peer_to_seat := {}  # peer_id -> seat_index
var max_players := 4

