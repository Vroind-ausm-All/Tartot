extends RefCounted
class_name Meta

const SAVE_PATH := "user://tartot_meta.json"

var runs := 0
var wins := 0
var deaths := 0
var veil := 0
var highest_veil := -1
var best_spiral := 0
var best_fights := 0
var best_fate := 0
var completed: Array[String] = []
var story_flags: Array[String] = []
var seen_cards: Array[String] = []
var lifetime: Dictionary = {}
var best: Dictionary = {}
var arcana: Dictionary = {}
var interpretations: Dictionary = {}
var death_cards: Array = []

func load_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text:=FileAccess.get_file_as_string(SAVE_PATH)
	var data=JSON.parse_string(text)
	if data is Dictionary:
		from_dict(data)

func save_file() -> void:
	var f:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(to_dict(),"	"))

func to_dict()->Dictionary:
	return {"runs":runs,"wins":wins,"deaths":deaths,"veil":veil,"highest_veil":highest_veil,"best_spiral":best_spiral,"best_fights":best_fights,"best_fate":best_fate,"completed":completed,"story_flags":story_flags,"seen_cards":seen_cards,"lifetime":lifetime,"best":best,"arcana":arcana,"interpretations":interpretations,"death_cards":death_cards}

func from_dict(d:Dictionary)->void:
	runs=int(d.get("runs",0));wins=int(d.get("wins",0));deaths=int(d.get("deaths",0));veil=int(d.get("veil",0));highest_veil=int(d.get("highest_veil",-1));best_spiral=int(d.get("best_spiral",0));best_fights=int(d.get("best_fights",0));best_fate=int(d.get("best_fate",0))
	completed=[];for x in d.get("completed",[]):completed.append(String(x))
	story_flags=[];for x in d.get("story_flags",[]):story_flags.append(String(x))
	seen_cards=[];for x in d.get("seen_cards",[]):seen_cards.append(String(x))
	lifetime=d.get("lifetime",{}).duplicate();best=d.get("best",{}).duplicate();arcana=d.get("arcana",{}).duplicate();interpretations=d.get("interpretations",{}).duplicate();death_cards=d.get("death_cards",[]).duplicate()

func is_deuter_unlocked(katalog:Katalog,id:String)->bool:
	var d:=katalog.deuter_def(id);var unlock:=String(d.get("unlock",""))
	return unlock=="" or completed.has(unlock)

func encounter_arcana(card_id:String)->String:
	var n=int(arcana.get(card_id,0))+1;arcana[card_id]=n
	var thresholds=[1,5,12];var names=["Erste Lesart","Transformation","Verkehrte Lesart"]
	var idx=thresholds.find(n)
	if idx<0:return ""
	if not interpretations.has(card_id):interpretations[card_id]=[]
	if not interpretations[card_id].has(names[idx]):interpretations[card_id].append(names[idx]);return names[idx]
	return ""

func complete_run(run:Run)->Dictionary:
	runs+=1
	if run.won:wins+=1;highest_veil=maxi(highest_veil,run.veil);veil=mini(Konst.MAX_VEIL,maxi(veil,run.veil+1))
	else:deaths+=1
	best_fights=maxi(best_fights,run.fight_index);best_fate=maxi(best_fate,int(run.stats.get("fate_total",0)));best_spiral=maxi(best_spiral,Konst.spiral_depth(run.fight_index))
	for k in run.stats:
		lifetime[k]=int(lifetime.get(k,0))+int(run.stats[k]);best[k]=maxi(int(best.get(k,0)),int(run.stats[k]))
	for card in run.deck:
		if not seen_cards.has(card.id()):seen_cards.append(card.id())
		if card.is_major():encounter_arcana(card.id())
	for flag in run.story_flags:
		if not story_flags.has(flag):story_flags.append(flag)
	if not run.won and not run.deck.is_empty():
		var cards:=run.deck.duplicate();cards.sort_custom(func(a,b):return a.strength()>b.strength())
		death_cards.append({"card":cards[0].id(),"fight":run.fight_index,"deuter":run.deuter_id,"seed":run.seed_value})
		if death_cards.size()>30:death_cards.pop_front()
	var unlocked:Array[String]=[]
	for p in run.katalog.prophecies:
		var id:=String(p["id"])
		if completed.has(id):continue
		if prophecy_value(p,run)>=int(p["target"]):
			completed.append(id);unlocked.append(String(p["title"]))
	save_file()
	return {"headline":"DIE WELT FIEL" if run.won else "DU FÄLLST","unlocked":unlocked,"near":near_misses(run)}

func prophecy_value(p:Dictionary,run:Run=null)->int:
	var mode:=String(p.get("mode","best"));var key:=String(p.get("key",""))
	match mode:
		"meta":
			match key:
				"runs":return runs
				"wins":return wins+(1 if run!=null and run.won else 0)
				"highest_veil":return maxi(highest_veil,run.veil if run!=null and run.won else -1)
				"best_spiral":return maxi(best_spiral,Konst.spiral_depth(run.fight_index) if run!=null else 0)
				"seen_cards":
					var ids:=seen_cards.duplicate()
					if run!=null:
						for c in run.deck:if not ids.has(c.id()):ids.append(c.id())
					return ids.size()
		"sum":return int(lifetime.get(key,0))+(int(run.stats.get(key,0)) if run!=null else 0)
		"best":return maxi(int(best.get(key,0)),int(run.stats.get(key,0)) if run!=null else 0)
		"flag":return 1 if story_flags.has(key) or (run!=null and run.story_flags.has(key)) else 0
	return 0

func near_misses(run:Run)->Array:
	var out:Array=[]
	for p in run.katalog.prophecies:
		if completed.has(String(p["id"])):continue
		var v:=prophecy_value(p,run);var target:=int(p["target"]);var progress=float(v)/maxf(1.0,float(target))
		if progress>=0.25:out.append({"title":p["title"],"detail":"%s (%d / %d)"%[p["text"],v,target],"progress":minf(1.0,progress)})
	out.sort_custom(func(a,b):return float(a["progress"])>float(b["progress"]))
	return out.slice(0,3)
