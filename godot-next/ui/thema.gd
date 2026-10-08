extends RefCounted
class_name Thema

const INK:=Color("#1A1412")
const DEEP:=Color("#0D0A09")
const PAPER:=Color("#EFE3C8")
const PAPER_DARK:=Color("#D8C8A6")
const SEPIA1:=Color("#C9B48E")
const SEPIA2:=Color("#8F7A5A")
const SEPIA3:=Color("#4E4032")
const GOLD:=Color("#E3A83B")
const GOLD_LIGHT:=Color("#F1C35C")
const RED:=Color("#B3262B")
const INDIGO:=Color("#3B4A8C")
const INDIGO_LIGHT:=Color("#6170B4")

static func label(text:String,size:int=12,color:Color=PAPER,align:=HORIZONTAL_ALIGNMENT_LEFT,wrap:=false)->Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align
	if wrap:l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l

static func panel(fill:Color=DEEP,border:Color=SEPIA3,width:=2)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.corner_radius_top_left=0;s.corner_radius_top_right=0;s.corner_radius_bottom_left=0;s.corner_radius_bottom_right=0
	s.content_margin_left=6;s.content_margin_right=6;s.content_margin_top=5;s.content_margin_bottom=5;return s

static func button_style(fill:Color,border:Color)->StyleBoxFlat:
	var s:=panel(fill,border,2);s.content_margin_left=8;s.content_margin_right=8;s.content_margin_top=7;s.content_margin_bottom=7;return s

static func button(text:String,primary:=false)->Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,44);b.add_theme_font_size_override("font_size",11);b.add_theme_color_override("font_color",PAPER if primary else PAPER)
	b.add_theme_stylebox_override("normal",button_style(RED if primary else INK,GOLD if primary else SEPIA2));b.add_theme_stylebox_override("hover",button_style(GOLD,INK));b.add_theme_stylebox_override("pressed",button_style(SEPIA3,PAPER));return b
