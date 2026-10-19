class_name CareerSave
extends Resource
## A saved career: the whole world as it stands (every boxer in ranking
## order, the champions, the season's calendar and papers) and the player's
## career. Saved as a resource file in SAVE_DIR (see GameState.save_career).

const SAVE_DIR := "user://careers"

## Shown in the list of saved careers.
@export var title := ""
@export var saved_at := ""
@export var date := ""
@export var ranking_mode := 0
## Every ranked boxer, division by division (division_sizes says how many
## each), best first; then the retired ones.
@export var boxers: Array[BoxerData] = []
@export var division_sizes: Array[int] = []
@export var champions: Array[int] = []          ## Boxer id, or -1 if vacant.
@export var last_defences: Array[int] = []
@export var retired: Array[BoxerData] = []
@export var season: Dictionary = {}
@export var career: Dictionary = {}
