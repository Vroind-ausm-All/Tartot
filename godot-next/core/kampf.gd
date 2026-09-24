extends RefCounted
class_name Kampf

var run:Run
var enemy_def:Dictionary
var rng:TRng
var enemy_hp:=0
var enemy_stance:=0
var enemy_sigils:=0
var enemy_shield:=0
var enemy_phase:=0
var enemy_attack_ramp:=0
var enemy_intent:=Konst.Intent.ATTACK
var enemy_intent_value:=0
var intent_hidden:=false
var turn:=1
var player_shield:=0
var hand:Array[Karte]=[]
var draw_pile:Array[Karte]=[]
var discard:Array[Karte]=[]
var slots:Dictionary={}
var blocked_slot:Variant=null
var veiled_ids:Array[String]=[]
var marked_id:=""
var mark_turns:=0
var pact_pending:=false
var pact_taken:=false
var pattern_chain:=0
var same_signature:=""
var repeat_count:=0
var player_won:=false
var player_lost:=false
var last_score:Dictionary={}
var max_shield:=0
var worlds_this_fight:=0
var log:Array[String]=[]

func _init(p_run:Run,p_def:Dictionary,p_rng:TRng)->void:
	run=p_run;enemy_def=p_def;rng=p_rng;enemy_hp=int(p_def["hp"]);enemy_stance=int(p_def["stance"]);enemy_sigils=int(p_def.get("sigils",0))
	draw_pile=run.deck.duplicate();rng.mische(draw_pile);player_shield=run.charm_stacks("white_thread")*3;_draw(5+mini(2,run.charm_stacks("blank_card")));_prepare_intent();_apply_boss_start()

func _draw(n:int)->void:
	for i in n:
		if draw_pile.is_empty(): draw_pile=discard;discard=[];rng.mische(draw_pile)
		if draw_pile.is_empty():return
		hand.append(draw_pile.pop_back())

func has_rule(rule:int)->bool:return enemy_def.get("rules",[]).has(rule)
func weakened()->bool:return bool(enemy_def.get("weakened",false))
func effective_slot(slot:int)->int:
	if has_rule(Konst.BossRule.HANGED) and (not weakened() or turn%2==0):
		if slot==Konst.Slot.PAST:return Konst.Slot.FUTURE
		if slot==Konst.Slot.FUTURE:return Konst.Slot.PAST
	if has_rule(Konst.BossRule.WHEEL):
		var dir=-1 if enemy_phase>=1 and not weakened() else 1
		if weakened() and turn%2==1:return slot
		return posmod(slot+dir*turn,3)
	return slot

func place(card:Karte,slot:int)->bool:
	if blocked_slot!=null and int(blocked_slot)==slot:return false
	if slots.has(slot):return false
	if not hand.has(card):return false
	hand.erase(card);slots[slot]=card;return true
func return_slot(slot:int)->void:
	if slots.has(slot):hand.append(slots[slot]);slots.erase(slot)
func can_resolve()->bool:return not slots.is_empty()

func preview()->Dictionary:
	return _score(false)

func _score(commit:bool)->Dictionary:
	var cards:Array[Karte]=slots.values()
	var chips:=0;var mult:=1.0;var ranks:Array[int]=[];var suits:Array[int]=[];var reversed_count:=0
	for slot in slots:
		var card:Karte=slots[slot];var eff:=effective_slot(int(slot));var value=card.effective_rank();chips+=value;ranks.append(card.rank());suits.append(card.suit())
		if eff==Konst.Slot.PRESENT:mult+=0.15
		elif eff==Konst.Slot.FUTURE:mult+=0.10+0.10*run.charm_stacks("hangman_chain")
		if card.reversed():reversed_count+=1;mult+=Konst.BLOOD_READER_MULT if String(run.katalog.deuter_def(run.deuter_id).get("rule",""))=="blood_reader" else Konst.NORMAL_REVERSED_MULT
	var combo:="";var has_pattern:=false;var world:=ranks.size()==3 and ranks[0]+ranks[1]+ranks[2]==21
	if world:combo="DIE WELT";chips+=21;mult+=2.10;has_pattern=true
	elif _three_kind(ranks):combo="Dreiklang";chips+=12;mult+=1.0;has_pattern=true
	elif _sequence(ranks):combo="Folge";chips+=8;mult+=0.75;has_pattern=true
	elif _same_suit(suits):combo="Resonanz";chips+=10;mult+=0.65;has_pattern=true
	elif _pair(ranks):combo="Paar";chips+=5;mult+=0.50;has_pattern=true
	elif _three_suits(suits):combo="Drei Pfade";mult+=0.35
	var major_count:=0;for c in cards:if c.is_major():major_count+=1
	if major_count>=2:mult+=0.60+maxi(0,major_count-2)*0.25;if combo=="":combo="Großes Omen"
	var next_chain=min(Konst.PATTERN_CHAIN_MAX,pattern_chain+1) if has_pattern else 0
	mult+=next_chain*Konst.PATTERN_CHAIN_BONUS
	var signature:=combo+":"+":".join(ranks.map(func(x):return str(x)))
	var repeat_penalty:=1.0
	if signature==same_signature:
		var nr=repeat_count+1;repeat_penalty=[1.0,0.90,0.75,0.50][mini(3,nr)]
	var fate_damage=int(round(chips*mult*repeat_penalty))
	if pact_taken:fate_damage=int(round(fate_damage*1.5))
	var stance_damage=int(chips/9)
	for c in cards:if c.suit()==Konst.Suit.SWORDS:stance_damage+=2
	var breaks:=enemy_stance>0 and stance_damage>=enemy_stance
	var expected:=fate_damage
	if enemy_stance>0 and not breaks:expected=mini(expected,int(enemy_def["hp"]*Konst.STANCE_HIT_CAP))
	elif breaks:expected=int(round(expected*Konst.STANCE_BREAK_MULT))
	var lethal:=expected>=enemy_hp and enemy_sigils<=0
	var hints:Array[String]=[]
	if not world and ranks.size()>=2:
		var sum=0;for r in ranks:sum+=r
		for c in hand:
			if sum+c.rank()==21:hints.append("%s vollendet DIE WELT"%c.name());break
	return {"chips":chips,"multiplier":mult,"fate_damage":fate_damage,"combo":combo if combo!="" else "Legung","repeat_penalty":repeat_penalty,"chain":next_chain,"is_world":world,"has_pattern":has_pattern,"stance_damage":stance_damage,"breaks_stance":breaks,"expected_hit":expected,"lethal":lethal,"hints":hints,"reversed":reversed_count,"signature":signature}

func resolve()->Dictionary:
	if not can_resolve():return {}
	var score:=_score(true);last_score=score
	pattern_chain=int(score["chain"]);run.stats["longest_chain"]=maxi(int(run.stats["longest_chain"]),pattern_chain);run.stats["reversed_played"]=int(run.stats["reversed_played"])+int(score["reversed"])
	if bool(score["is_world"]):worlds_this_fight+=1;run.stats["world_spreads"]=int(run.stats["world_spreads"])+1;run.stats["most_worlds_fight"]=maxi(int(run.stats["most_worlds_fight"]),worlds_this_fight)
	run.stats["best_hit"]=maxi(int(run.stats["best_hit"]),int(score["fate_damage"]));run.stats["fate_total"]=int(run.stats["fate_total"])+int(score["fate_damage"]);run.fate+=int(score["fate_damage"])
	if String(score["signature"])==same_signature:repeat_count+=1
	else:same_signature=String(score["signature"]);repeat_count=0
	enemy_stance=maxi(0,enemy_stance-int(score["stance_damage"]))
	var hit=int(score["expected_hit"]);var before=enemy_hp;enemy_hp=maxi(0,enemy_hp-hit);var over=maxi(0,hit-before);run.stats["best_overkill"]=maxi(int(run.stats["best_overkill"]),over);if over>0:run.gold+=mini(4+4*run.current_act(),int(over/8))
	_pay_reversed_cost()
	for card in slots.values():discard.append(card)
	slots.clear()
	if enemy_hp<=0:_death_or_sigil()
	if player_won:return score
	_enemy_action()
	if run.hp<=0:player_lost=true;return score
	_after_turn();turn+=1;_draw(maxi(1,3-hand.size()));_prepare_intent()
	return score

func _pay_reversed_cost()->void:
	var count=0;for c in discard:if c.reversed():count+=1
	if count==0:return
	var factor=1.5 if run.veil>=7 else 1.0
	var cost=maxi(1,int(round(count*factor)));run.hp=maxi(1,run.hp-cost)

func _death_or_sigil()->void:
	if enemy_sigils>0:
		enemy_sigils-=1;enemy_phase+=1;enemy_hp=maxi(1,int(enemy_def["hp"]*Konst.SIGIL_REVIVE_HP));enemy_stance=int(enemy_def["stance"]);enemy_attack_ramp+=Konst.SIGIL_ATTACK_RAMP;log.append("SCHICKSALSSIEGEL BRICHT — das Omen erhebt sich.")
	else:player_won=true

func _enemy_action()->void:
	if player_won:return
	var damage:=enemy_intent_value+enemy_attack_ramp
	match enemy_intent:
		Konst.Intent.GUARD:enemy_shield+=damage
		Konst.Intent.HEX:run.hp=maxi(0,run.hp-int(damage/2));run.luck=maxi(0,run.luck-1)
		Konst.Intent.DRAIN:_take_damage(damage);enemy_hp=mini(int(enemy_def["hp"]),enemy_hp+int(damage/2))
		Konst.Intent.FRENZY:_take_damage(damage);_take_damage(damage)
		_:_take_damage(damage)

func _take_damage(amount:int)->void:
	var blocked=mini(player_shield,amount);player_shield-=blocked;run.hp-=amount-blocked
func _after_turn()->void:
	if enemy_stance<=0:enemy_stance=int(enemy_def["stance"]*Konst.STANCE_RECOVERY)
	if String(run.katalog.deuter_def(run.deuter_id).get("rule",""))=="bookkeeper":player_shield=int(player_shield*.15)
	else:player_shield=0
	max_shield=maxi(max_shield,player_shield);_apply_boss_turn()

func _prepare_intent()->void:
	var pattern:Array=enemy_def.get("pattern",["A"]);var code=String(pattern[(turn-1)%pattern.size()])
	enemy_intent={"A":Konst.Intent.ATTACK,"G":Konst.Intent.GUARD,"H":Konst.Intent.HEX,"D":Konst.Intent.DRAIN,"F":Konst.Intent.FRENZY}.get(code,Konst.Intent.ATTACK)
	enemy_intent_value=int(enemy_def["attack"]);intent_hidden=has_rule(Konst.BossRule.MOON) and ((enemy_phase>=1 and not weakened()) or turn%2==0)

func intent_text()->String:
	if intent_hidden:return "???"
	match enemy_intent:
		Konst.Intent.GUARD:return "%d Schild"%enemy_intent_value
		Konst.Intent.HEX:return "Fluch"
		Konst.Intent.DRAIN:return "%d Schaden · heilt"%enemy_intent_value
		Konst.Intent.FRENZY:return "2 × %d Schaden"%enemy_intent_value
		_:return "%d Schaden"%enemy_intent_value

func rule_text()->String:
	var out:Array[String]=[]
	for rule in enemy_def.get("rules",[]):
		match int(rule):
			Konst.BossRule.TOWER:out.append("DER TURM: Positionen stürzen ein.")
			Konst.BossRule.MOON:out.append("DER MOND: Absicht und Karten werden verborgen.")
			Konst.BossRule.DEATH:out.append("DER TOD: Er zeichnet deine stärkste Karte.")
			Konst.BossRule.WHEEL:out.append("DAS RAD: Positionen wandern.")
			Konst.BossRule.DEVIL:out.append("DER TEUFEL: Mehr Macht gegen Lebenskraft.")
			Konst.BossRule.HANGED:out.append("DER GEHÄNGTE: Vergangenheit und Zukunft tauschen.")
	return " · ".join(out)

func _apply_boss_start()->void:
	if has_rule(Konst.BossRule.DEVIL):pact_pending=true
func answer_pact(accept:bool)->void:
	pact_pending=false
	if accept:
		pact_taken=true;run.max_hp=maxi(20,run.max_hp-6);run.hp=mini(run.hp,run.max_hp);run.add_darkness(8);run.stats["pacts_accepted"]=int(run.stats["pacts_accepted"])+1
	else:enemy_attack_ramp+=3

func _apply_boss_turn()->void:
	blocked_slot=null;veiled_ids.clear()
	if has_rule(Konst.BossRule.TOWER):
		var interval=4 if weakened() else (2 if enemy_phase>=1 else 3)
		if turn%interval==0:blocked_slot=rng.int_bis(3)
	if has_rule(Konst.BossRule.MOON):
		var n=1 if weakened() else (2 if enemy_phase>=1 else 1)
		if enemy_phase>=1 or turn%2==0:
			for c in rng.waehle_mehrere(hand,n):veiled_ids.append(c.instance_id)
	if has_rule(Konst.BossRule.DEATH) and hand.size()>0:
		if marked_id=="":
			var s=hand.duplicate();s.sort_custom(func(a,b):return a.strength()>b.strength());marked_id=s[0].instance_id;mark_turns=4 if weakened() else (2 if enemy_phase>=1 else 3)
		else:
			mark_turns-=1
			if mark_turns<=0:
				for c in hand:
					if c.instance_id==marked_id:hand.erase(c);break
				marked_id=""

func _pair(a:Array[int])->bool:
	for x in a:
		if a.count(x)>=2:return true
	return false
func _three_kind(a:Array[int])->bool:return a.size()>=3 and a.count(a[0])>=3
func _sequence(a:Array[int])->bool:
	if a.size()!=3:return false
	var b=a.duplicate();b.sort();return b[1]==b[0]+1 and b[2]==b[1]+1
func _same_suit(a:Array[int])->bool:return a.size()>=3 and a.all(func(x):return x==a[0])
func _three_suits(a:Array[int])->bool:
	var d:Dictionary={};for x in a:d[x]=true
	return d.size()>=3
