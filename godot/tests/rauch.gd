extends SceneTree

func _initialize() -> void:
	print("--- Rauchtest ---")
	var r := TRng.new(42)
	print("RNG 1: ", r.int_bis(1000), " ", r.int_bis(1000), " ", r.int_bis(1000))
	var r2 := TRng.new(42)
	print("RNG 2: ", r2.int_bis(1000), " ", r2.int_bis(1000), " ", r2.int_bis(1000))
	var kat := Katalog.new()
	var ok: bool = kat.laden()
	print("Katalog geladen: ", ok, " Fehler: ", kat.fehler)
	print("Kleine: ", kat.kleine.size(), " Grosse: ", kat.grosse.size(),
		" Charms: ", kat.charms.size(), " Items: ", kat.items.size(),
		" Gegner: ", kat.gegner.size(), " Deuter: ", kat.deuter.size())
	var k := kat.karte("schwerter_08")
	print("Karte: ", k.anzeigename(), " | ", kat.text(k))
	k.drehen()
	print("Gedreht: ", k.anzeigename(), " | ", kat.text(k))
	var kf := Kaempfer.neu("Test", 30)
	kf.gib(K.St.VERWUNDBAR, 2)
	print("Schaden 10 auf Verwundbar: ", kf.schaden_nehmen(10), " HP: ", kf.hp)
	quit(0)
