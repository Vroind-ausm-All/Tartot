extends RefCounted
class_name Run

var katalog: Katalog
var meta: Meta
var seed_value: int
var rng: TRng
var rng_world: TRng
var rng_combat: TRng
var rng_progression: TRng

var deuter_id := "wahrsagerin"
var veil := 0
var is_daily := false
var hp := 72
var max_hp := 72
var gold := 90
var luck := 2
var fate := 0
var darkness := 0
var deck: Array[Karte] = []
var charms: Dictionary = {}
var items: Dictionary = {}

var fight_index := 0
var phase := Konst.Phase.PATH
var won := false
var combat: Kampf = null
var rewards: Array = []
var paths: Array = []
var current_event: Dictionary = {}
var event_resolved := false
var event_epilogue := ""
var upcoming_bosses: Array[String] = []
var defeated_bosses: Array[String] = []
var seen_events: Array[String] = []
var story_flags: Array[String] = []
var removed_cards: Array[Dictionary] = []
var grave_card_id := ""
var grave_fight := 0
var free_next_shop := false
var bonus_reward_choices := 0
var message := ""

var stats := {
	"world_spreads":0,"most_worlds_fight":0,"reversed_played":0,"most_shield":0,
	"thin_boss_kills":0,"best_overkill":0,"longest_chain":0,"pacts_accepted":0,
	"peak_darkness":0,"most_black":0,"events_seen":0,"best_hit":0,"fate_total":0
}

static func create(p_katalog: Katalog, p_meta: Meta, deuter: String, p_veil: int, seed_in: int = 0, daily := false) -> Run:
	var r := Run.new()
	r.katalog=p_katalog; r.meta=p_meta; r.deuter_id=deuter; r.veil=clampi(p_veil,0,Konst.MAX_VEIL); r.is_daily=daily
	r.seed_value=seed_in if seed_in!=0 else int(Time.get_unix_time_from_system()*1000.0)
	r.rng=TRng.new(r.seed_value); r.rng_world=r.rng.strom("world"); r.rng_combat=r.rng.strom("combat"); r.rng_progression=r.rng.strom("progression")
	r._setup_deuter(); r._plan_bosses(); r.build_paths()
	return r

func _setup_deuter() -> void:
	var d:=katalog.deuter_def(deuter_id)
	max_hp=int(d.get("hp",72))-(4 if veil>=4 else 0); hp=max_hp; gold=int(d.get("gold",90)); luck=int(d.get("luck",2))
	var reversed:Array=d.get("reversed",[]).duplicate()
	var n:=0
	for id in d.get("deck",[]):
		var k:=katalog.make_card(String(id),"%s-%d"%[String(id),n]); n+=1
		if reversed.has(id): k.orientation=Konst.Orientation.REVERSED; reversed.erase(id)
		deck.append(k)
	for id in d.get("charms",[]): charms[String(id)]=int(charms.get(String(id),0))+1
	for id in d.get("items",[]): items[String(id)]=int(items.get(String(id),0))+1

func _plan_bosses() -> void:
	upcoming_bosses.clear()
	for act in range(1,4):
		var pool:=katalog.bosses_for_act(act); upcoming_bosses.append(String(pool[rng_world.int_bis(pool.size())]))

func current_act() -> int: return Konst.act_of(fight_index)
func is_finale() -> bool: return Konst.is_finale(fight_index)
func is_spiral() -> bool: return Konst.is_spiral(fight_index)
func darkness_stage() -> int: return clampi(int(darkness/20),0,5)

func add_darkness(delta:int) -> void:
	darkness=clampi(darkness+delta,0,100); stats["peak_darkness"]=maxi(int(stats["peak_darkness"]),darkness)

func charm_stacks(id:String)->int: return int(charms.get(id,0))
func add_charm(id:String)->bool:
	var d:=katalog.charm_def(id); if d.is_empty(): return false
	var n:=charm_stacks(id); if n>=int(d.get("max",1)): return false
	charms[id]=n+1; return true

func build_paths() -> void:
	paths.clear()
	if is_finale() or Konst.is_boss_fight(fight_index):
		paths=[{"type":Konst.Path.FIGHT,"label":"OMEN — %s"%next_enemy_name()}]; return
	var choices=[Konst.Path.FIGHT,Konst.Path.SHOP,Konst.Path.RITUAL,Konst.Path.ORACLE,Konst.Path.ELITE,Konst.Path.EVENT,Konst.Path.REST]
	var picked:=rng_world.waehle_mehrere(choices,2)
	paths.append({"type":Konst.Path.FIGHT,"label":"KAMPF — kein Umweg (+%d Gold)"%Konst.DIRECT_PATH_GOLD})
	for p in picked: paths.append({"type":int(p),"label":Konst.PATH_NAME[int(p)].to_upper()})
	if Konst.fights_until_boss(fight_index)<=1 and not paths.any(func(x): return int(x["type"])==Konst.Path.REST):
		paths[2]={"type":Konst.Path.REST,"label":"RAST — vor dem Omen"}

func choose_path(index:int) -> void:
	index=clampi(index,0,paths.size()-1); var p:=int(paths[index]["type"])
	match p:
		Konst.Path.FIGHT:
			if index==0 and not Konst.is_boss_fight(fight_index) and not is_finale(): gold+=Konst.DIRECT_PATH_GOLD
			start_combat(false)
		Konst.Path.ELITE: start_combat(true)
		Konst.Path.SHOP: phase=Konst.Phase.SHOP
		Konst.Path.RITUAL: phase=Konst.Phase.RITUAL
		Konst.Path.ORACLE: phase=Konst.Phase.ORACLE
		Konst.Path.EVENT: start_event()
		Konst.Path.REST: phase=Konst.Phase.REST

func next_enemy_id(elite:=false)->String:
	if is_finale(): return "boss_welt"
	if is_spiral() and Konst.is_spiral_boss(fight_index): return "weltenwurm"
	if Konst.is_boss_fight(fight_index): return upcoming_bosses[clampi(current_act()-1,0,2)]
	var pool:=katalog.elites_for_act(current_act()) if elite else katalog.normals_for_act(current_act())
	if is_spiral(): pool=katalog.elites_for_act(3) if elite else katalog.normals_for_act(3)
	return String(pool[rng_world.int_bis(pool.size())])
func next_enemy_name()->String: return String(katalog.enemy_def(next_enemy_id()).get("name","?"))

func start_combat(elite:=false) -> void:
	var id:=next_enemy_id(elite); var def:Dictionary=katalog.enemy_def(id).duplicate(true)
	if is_finale():
		def["rules"]=[]
		for boss in defeated_bosses:
			for rule in katalog.enemy_def(boss).get("rules",[]): if not def["rules"].has(rule): def["rules"].append(rule)
		def["weakened"]=true
	if is_spiral():
		var depth:=Konst.spiral_depth(fight_index)
		def["hp"]=int(float(def["hp"])*pow(1.08,depth)*(1.0+0.008*depth*depth)); def["stance"]=int(float(def["stance"])*pow(1.06,depth)); def["attack"]=int(def["attack"])+depth
		if depth>=8: def["sigils"]=int(def["sigils"])+int(depth/8)
	if veil>=2 and int(def["tier"])>=Konst.Tier.ELITE: def["hp"]=int(def["hp"]*1.2); def["stance"]=int(def["stance"]*1.2)
	if veil>=5 and current_act()>=2 and int(def["tier"])>=Konst.Tier.ELITE: def["attack"]=int(def["attack"])+current_act()-1
	if veil>=6 and current_act()>=2: def["attack"]=int(def["attack"])+1
	if is_finale() and veil>=8: def["sigils"]=int(def["sigils"])+1
	def["attack"]=int(def["attack"])+int(darkness/25)
	combat=Kampf.new(self,def,rng_combat.strom("fight_%d"%fight_index)); phase=Konst.Phase.COMBAT

func finish_combat() -> void:
	if combat==null:return
	if combat.player_lost:
		hp=maxi(0,hp); phase=Konst.Phase.GAME_OVER; message="Der Film reißt."; return
	var enemy_id:=String(combat.enemy_def.get("id","")); var tier:=int(combat.enemy_def.get("tier",0))
	stats["most_shield"]=maxi(int(stats["most_shield"]),combat.max_shield)
	if tier>=Konst.Tier.BOSS and deck.size()<=8: stats["thin_boss_kills"]=1
	if tier>=Konst.Tier.BOSS and enemy_id!="weltenwurm" and enemy_id!="boss_welt":
		defeated_bosses.append(enemy_id); add_darkness(6); phase=Konst.Phase.BOSS_LOOT; return
	if enemy_id=="boss_welt":
		won=true; phase=Konst.Phase.VICTORY; return
	fight_index+=1; _prepare_rewards()

func _prepare_rewards() -> void:
	phase=Konst.Phase.REWARD; rewards.clear()
	var count:=3-(1 if veil>=3 else 0)+bonus_reward_choices; bonus_reward_choices=0
	var pool:Array=deck.map(func(k): return k.id())
	for i in count:
		var all:Array=katalog.cards.keys().filter(func(id): return not String(id).begins_with("major_"))
		rewards.append({"type":"card","card":katalog.make_card(String(all[rng_progression.int_bis(all.size())]),"reward-%d-%d"%[fight_index,i])})
	rewards.append({"type":"fate","value":25,"title":"Fate +25"})

func choose_reward(index:int) -> void:
	if index>=0 and index<rewards.size():
		var r:Dictionary=rewards[index]
		if r["type"]=="card": deck.append(r["card"])
		elif r["type"]=="fate": fate+=int(r["value"])
	fight_index+=1; phase=Konst.Phase.PATH; build_paths()

func boss_loot(choice:String) -> void:
	if choice=="soak":
		var sorted:=deck.duplicate(); sorted.sort_custom(func(a,b): return a.strength()>b.strength())
		for i in mini(3,sorted.size()): sorted[i].upgrade(); sorted[i].darken()
		add_darkness(Konst.SOAK_DARKNESS)
	elif choice=="bind":
		var bid:=defeated_bosses[-1]; var map={"boss_turm":16,"boss_mond":18,"boss_tod":13,"boss_rad":10,"boss_teufel":15,"boss_gehaengter":12}
		if map.has(bid):
			var k:=katalog.make_card("major_%d"%map[bid],"omen-%d"%fight_index); k.orientation=Konst.Orientation.REVERSED; k.shimmer=Konst.Shimmer.BLOOD; deck.append(k)
		add_darkness(Konst.BIND_DARKNESS)
	else:
		gold+=Konst.BANISH_GOLD; hp=mini(max_hp,hp+18); add_darkness(-Konst.BANISH_LIGHT)
	fight_index+=1; phase=Konst.Phase.PATH; build_paths()

func rest_heal() -> void:
	var amount=int(max_hp*(0.25 if veil>=7 else 0.35)); hp=mini(max_hp,hp+amount); phase=Konst.Phase.PATH; build_paths()
func rest_study(card:Karte)->void: card.upgrade(); phase=Konst.Phase.PATH; build_paths()

func start_event() -> void:
	var candidates:Array=[]
	for e in katalog.events:
		if not seen_events.has(String(e["id"])): candidates.append(e)
	if candidates.is_empty(): candidates=katalog.events
	current_event=candidates[rng_world.int_bis(candidates.size())]; seen_events.append(String(current_event["id"])); stats["events_seen"]=int(stats["events_seen"])+1; event_resolved=false; phase=Konst.Phase.EVENT

func resolve_event(choice_index:int) -> void:
	var choices:Array=current_event.get("choices",[]); if choices.is_empty(): phase=Konst.Phase.PATH; build_paths(); return
	var c:Dictionary=choices[clampi(choice_index,0,choices.size()-1)]; var op:=String(c.get("op","leave")); event_epilogue="Der Projektor rattert weiter."
	match op:
		"story": if not story_flags.has(String(c["flag"])): story_flags.append(String(c["flag"]))
		"heal": hp=mini(max_hp,hp+int(c["value"]))
		"heal_light": hp=mini(max_hp,hp+int(c["heal"])); add_darkness(-int(c["light"]))
		"gold_hurt": gold+=int(c["gold"]); hp=maxi(1,hp-int(c["hurt"]))
		"luck_dark": luck+=int(c["luck"]); add_darkness(int(c["dark"]))
		"gold_dark": gold+=int(c["gold"]); add_darkness(int(c["dark"]))
		"fate": fate+=int(c["value"])
		"remove": _remove_weakest()
		"mirror": var k=_strongest(); if k: deck.append(k.clone("copy-%d"%deck.size())); add_darkness(4)
		"sacrifice": _remove_weakest(); max_hp+=4; hp+=4
		"sew": _remove_weakest(); _remove_weakest(); var b=_strongest(); if b:b.upgrade()
		"charm": add_charm(String(c["id2"]))
		"age": max_hp=maxi(20,max_hp-8); hp=mini(hp,max_hp); var a=_strongest(); if a:a.upgrade();a.darken(); add_darkness(5)
		"confess": if gold>=25: gold-=25;add_darkness(-12)
		"lie": fate+=60;add_darkness(10)
		"black_page": var b=_strongest(); if b:b.shimmer=Konst.Shimmer.BLACK; add_darkness(15)
		"full_heal_light": hp=max_hp;add_darkness(-10)
		"bless": var b2=_random_card(); if b2:b2.upgrade(2)
		"major": var majors:Array=katalog.cards.keys().filter(func(id):return String(id).begins_with("major_")); var mk=katalog.make_card(String(majors[rng_progression.int_bis(majors.size())]),"event-major");mk.orientation=Konst.Orientation.REVERSED;deck.append(mk);add_darkness(8)
		"feast": hp=mini(max_hp,hp+int(max_hp*.4));var u=deck.filter(func(k):return k.orientation==Konst.Orientation.UPRIGHT);if not u.is_empty():u[rng_progression.int_bis(u.size())].flip()
		"paid_heal": if gold>=int(c["cost"]):gold-=int(c["cost"]);hp=mini(max_hp,hp+int(max_hp*float(c["share"])))
		"buy_charm": if gold>=int(c["cost"]):gold-=int(c["cost"]);_random_charm()
		"buy_item": if gold>=int(c["cost"]):gold-=int(c["cost"]);_random_item()
		"gold_hurt": pass
	event_resolved=true

func continue_event()->void: current_event={}; event_resolved=false; phase=Konst.Phase.PATH; build_paths()
func _strongest()->Karte: if deck.is_empty():return null;var s=deck.duplicate();s.sort_custom(func(a,b):return a.strength()>b.strength());return s[0]
func _random_card()->Karte:return null if deck.is_empty() else deck[rng_progression.int_bis(deck.size())]
func _remove_weakest()->void:
	if deck.size()<=Konst.MIN_DECK:return
	var s=deck.duplicate();s.sort_custom(func(a,b):return a.strength()<b.strength());removed_cards.append(s[0].save());deck.erase(s[0])
func _random_charm()->void:
	var ids:Array=katalog.charms.keys(); for n in ids.size(): var id=String(ids[rng_progression.int_bis(ids.size())]); if add_charm(id):return
func _random_item()->void:
	var ids:Array=katalog.items.keys();var id=String(ids[rng_progression.int_bis(ids.size())]);items[id]=int(items.get(id,0))+1

func continue_spiral()->void: fight_index=Konst.FINALE_INDEX+1;won=false;phase=Konst.Phase.PATH;hp=mini(max_hp,hp+int(max_hp*.4));build_paths()
func end_run()->void: phase=Konst.Phase.GAME_OVER

func save()->Dictionary:
	return {"version":3,"seed":seed_value,"deuter":deuter_id,"veil":veil,"daily":is_daily,"hp":hp,"max_hp":max_hp,"gold":gold,"luck":luck,"fate":fate,"darkness":darkness,"fight":fight_index,"phase":phase,"won":won,"deck":deck.map(func(k):return k.save()),"charms":charms,"items":items,"upcoming":upcoming_bosses,"defeated":defeated_bosses,"seen_events":seen_events,"flags":story_flags,"stats":stats,"rng":rng.speichern(),"world_rng":rng_world.speichern(),"combat_rng":rng_combat.speichern(),"progression_rng":rng_progression.speichern()}

static func load_from(data:Dictionary,katalog:Katalog,meta:Meta)->Run:
	var r:=Run.new();r.katalog=katalog;r.meta=meta;r.seed_value=int(data.get("seed",1));r.rng=TRng.new(r.seed_value);r.rng_world=r.rng.strom("world");r.rng_combat=r.rng.strom("combat");r.rng_progression=r.rng.strom("progression")
	r.rng.laden(data.get("rng",{}));r.rng_world.laden(data.get("world_rng",{}));r.rng_combat.laden(data.get("combat_rng",{}));r.rng_progression.laden(data.get("progression_rng",{}))
	r.deuter_id=String(data.get("deuter","wahrsagerin"));r.veil=int(data.get("veil",0));r.is_daily=bool(data.get("daily",false));r.hp=int(data.get("hp",72));r.max_hp=int(data.get("max_hp",72));r.gold=int(data.get("gold",90));r.luck=int(data.get("luck",2));r.fate=int(data.get("fate",0));r.darkness=int(data.get("darkness",0));r.fight_index=int(data.get("fight",0));r.phase=int(data.get("phase",Konst.Phase.PATH));r.won=bool(data.get("won",false))
	for x in data.get("deck",[]):var k=Karte.load_from(x,katalog);if k:r.deck.append(k)
	r.charms=data.get("charms",{}).duplicate();r.items=data.get("items",{}).duplicate();r.upcoming_bosses=data.get("upcoming",[]).duplicate();r.defeated_bosses=data.get("defeated",[]).duplicate();r.seen_events=data.get("seen_events",[]).duplicate();r.story_flags=data.get("flags",[]).duplicate();r.stats=data.get("stats",r.stats).duplicate()
	r.build_paths();return r
