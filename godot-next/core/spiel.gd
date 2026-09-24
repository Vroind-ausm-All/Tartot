extends Node

const RUN_SAVE := "user://tartot_run.json"

var katalog:Katalog
var meta:Meta
var run:Run=null

func _ready()->void:
	katalog=Katalog.new();meta=Meta.new();meta.load_file()
	load_run()

func new_run(deuter_id:String="wahrsagerin",veil:int=0,seed:int=0,daily:=false)->Run:
	run=Run.create(katalog,meta,deuter_id,veil,seed,daily);save_run();return run

func save_run()->void:
	if run==null:return
	if run.phase==Konst.Phase.GAME_OVER:
		clear_run();return
	var f:=FileAccess.open(RUN_SAVE,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(run.save()))

func load_run()->bool:
	if not FileAccess.file_exists(RUN_SAVE):return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE))
	if data is Dictionary:
		run=Run.load_from(data,katalog,meta);return true
	return false

func clear_run()->void:
	run=null
	if FileAccess.file_exists(RUN_SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE))

func finish_run()->Dictionary:
	if run==null:return {}
	var report:=meta.complete_run(run);clear_run();return report

func daily_seed()->int:
	var d:=Time.get_date_dict_from_system(true);return int(d.year)*10000+int(d.month)*100+int(d.day)
