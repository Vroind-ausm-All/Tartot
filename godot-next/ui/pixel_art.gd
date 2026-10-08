extends Control
class_name PixelArt

var art_key:=""
var phase:=0
var accent:=Thema.SEPIA1

func _init(key:String="")->void:
	art_key=key;custom_minimum_size=Vector2(96,112);mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready()->void:
	var timer:=Timer.new();timer.wait_time=1.0/12.0;timer.autostart=true;timer.timeout.connect(func():phase=(phase+1)%4;queue_redraw());add_child(timer)

func set_key(key:String)->void:art_key=key;queue_redraw()

func _draw()->void:
	var bob=-2.0 if phase in [1,2] else 0.0
	draw_set_transform(Vector2(0,bob))
	var k=art_key.to_lower()
	if "turm" in k:_tower()
	elif "mond" in k:_moon()
	elif "tod" in k:_death()
	elif "rad" in k:_wheel()
	elif "teufel" in k:_devil()
	elif "gehäng" in k or "gehaeng" in k:_hanged()
	elif "welt" in k:_world()
	elif "münze" in k or "muenze" in k:_coin()
	elif "henker" in k:_hangman()
	else:_generic()

func _eye(p:Vector2)->void:
	draw_circle(p,6,Thema.INK);draw_circle(p+Vector2(2,-2),3,Thema.PAPER)
func _grin(rect:Rect2)->void:
	draw_rect(rect,Thema.INK)
	for x in range(int(rect.position.x)+3,int(rect.end.x)-2,6):draw_rect(Rect2(x,rect.position.y+2,3,3),Thema.PAPER)
func _glove(p:Vector2)->void:
	draw_circle(p,6,Thema.PAPER);draw_line(p,p+Vector2(-4,-8),Thema.INK,2);draw_line(p,p+Vector2(1,-9),Thema.INK,2);draw_line(p,p+Vector2(5,-7),Thema.INK,2)

func _generic()->void:
	draw_circle(Vector2(48,48),29,Thema.SEPIA1);draw_arc(Vector2(48,48),29,0,TAU,32,Thema.INK,3);_eye(Vector2(37,42));_eye(Vector2(59,42));_grin(Rect2(32,56,33,11));draw_line(Vector2(34,72),Vector2(18,101),Thema.INK,4);draw_line(Vector2(62,72),Vector2(78,101),Thema.INK,4);_glove(Vector2(16,103));_glove(Vector2(80,103))
func _coin()->void:
	draw_circle(Vector2(48,53),34,Thema.GOLD);draw_arc(Vector2(48,53),34,0,TAU,32,Thema.INK,3);_eye(Vector2(37,48));_eye(Vector2(59,48));_grin(Rect2(31,61,35,12));draw_rect(Rect2(31,11,34,13),Thema.INK);draw_rect(Rect2(24,22,48,5),Thema.INK);_glove(Vector2(10,55));_glove(Vector2(86,55))
func _hangman()->void:
	draw_line(Vector2(48,0),Vector2(48,25),Thema.SEPIA2,4);draw_circle(Vector2(48,42),20,Thema.PAPER);draw_arc(Vector2(48,42),20,0,TAU,32,Thema.INK,3);_eye(Vector2(39,38));_eye(Vector2(57,38));_grin(Rect2(35,51,27,10));draw_line(Vector2(48,62),Vector2(48,96),Thema.INK,4);draw_line(Vector2(48,72),Vector2(20,86),Thema.INK,4);draw_line(Vector2(48,72),Vector2(76,86),Thema.INK,4);_glove(Vector2(17,88));_glove(Vector2(79,88))
func _tower()->void:
	draw_rect(Rect2(22,28,52,80),Thema.SEPIA1);draw_rect(Rect2(22,28,52,80),Thema.INK,false,3);for x in [22,38,54]:draw_rect(Rect2(x,17,12,16),Thema.SEPIA1);_eye(Vector2(37,49));_eye(Vector2(59,49));_grin(Rect2(34,64,29,11));draw_polyline(PackedVector2Array([Vector2(48,28),Vector2(41,56),Vector2(57,78),Vector2(45,107)]),Thema.RED,3);_glove(Vector2(10,67));_glove(Vector2(86,67))
func _moon()->void:
	draw_circle(Vector2(44,50),39,Thema.INDIGO);draw_arc(Vector2(44,50),39,0,TAU,40,Thema.INK,3);draw_circle(Vector2(68,31),34,Thema.DEEP);_eye(Vector2(28,47));_grin(Rect2(21,62,35,11));_glove(Vector2(12,96));_glove(Vector2(77,96))
func _death()->void:
	draw_circle(Vector2(48,38),22,Thema.PAPER);draw_arc(Vector2(48,38),22,0,TAU,32,Thema.INK,3);_eye(Vector2(39,34));_eye(Vector2(57,34));_grin(Rect2(35,47,27,10));draw_rect(Rect2(32,7,32,16),Thema.INK);draw_rect(Rect2(25,21,46,5),Thema.INK);draw_rect(Rect2(31,63,34,47),Thema.INK);draw_line(Vector2(78,21),Vector2(79,108),Thema.SEPIA1,3);draw_line(Vector2(79,21),Vector2(93,14),Thema.PAPER,3)
func _wheel()->void:
	draw_circle(Vector2(48,55),40,Thema.GOLD);draw_arc(Vector2(48,55),40,0,TAU,48,Thema.INK,3);draw_circle(Vector2(48,55),23,Thema.SEPIA1);for i in 8:var a=i*TAU/8.0;draw_line(Vector2(48,55),Vector2(48,55)+Vector2(cos(a),sin(a))*38,Thema.INK,2);_eye(Vector2(39,52));_eye(Vector2(57,52));_grin(Rect2(36,65,25,9))
func _devil()->void:
	draw_circle(Vector2(48,47),29,Thema.RED);draw_arc(Vector2(48,47),29,0,TAU,32,Thema.INK,3);draw_line(Vector2(33,25),Vector2(20,5),Thema.RED,5);draw_line(Vector2(63,25),Vector2(76,5),Thema.RED,5);_eye(Vector2(38,43));_eye(Vector2(58,43));_grin(Rect2(33,58,31,11));draw_rect(Rect2(31,76,34,35),Thema.INK)
func _hanged()->void:
	draw_line(Vector2(48,0),Vector2(48,24),Thema.SEPIA1,4);draw_circle(Vector2(48,39),19,Thema.PAPER);draw_arc(Vector2(48,39),19,0,TAU,32,Thema.INK,3);_eye(Vector2(40,36));_eye(Vector2(56,36));_grin(Rect2(36,48,25,9));draw_line(Vector2(48,58),Vector2(48,94),Thema.INK,4);draw_line(Vector2(48,68),Vector2(19,82),Thema.INK,4);draw_line(Vector2(48,68),Vector2(77,82),Thema.INK,4)
func _world()->void:
	draw_arc(Vector2(48,52),43,0,TAU,48,Thema.GOLD,4);draw_arc(Vector2(48,52),34,0,TAU,48,Thema.RED,3);draw_circle(Vector2(48,52),20,Thema.PAPER);draw_arc(Vector2(48,52),20,0,TAU,32,Thema.INK,3);_eye(Vector2(40,48));_eye(Vector2(56,48));_grin(Rect2(37,60,23,9))
