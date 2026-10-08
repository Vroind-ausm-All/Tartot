-- HISTORISCH (2026-10-08): Pixel-Vorlage fuer den entfernten Aseprite-Import.
-- godot-next zeigt Bosse jetzt als gemalte Figuren (buehnen/, docs/GODOT_HANDOFF.md).
-- TARTOT · XVIII Der Mond
-- Aseprite-Helfer: legt das Produktionsdokument mit Ebenen und Tags an.
-- Ausfuehren: File -> Scripts -> Open Script Folder, Datei hineinlegen, starten.
-- Spezifikation: godot-next/assets/sprites/bosses/mond/ASSET_SPEC.md
local spr = Sprite(128, 160, ColorMode.RGB)
spr.filename = "boss_mond.aseprite"
spr:setPalette(Palette(8))
local pal = spr.palettes[1]
pal:setColor(0, Color{r=26,g=20,b=18,a=255})   -- Ink
pal:setColor(1, Color{r=239,g=227,b=200,a=255})-- Paper
pal:setColor(2, Color{r=201,g=180,b=142,a=255})-- Sepia 1
pal:setColor(3, Color{r=143,g=122,b=90,a=255}) -- Sepia 2
pal:setColor(4, Color{r=78,g=64,b=50,a=255})   -- Sepia 3
pal:setColor(5, Color{r=227,g=168,b=59,a=255}) -- Gold
pal:setColor(6, Color{r=179,g=38,b=43,a=255})  -- Blood
pal:setColor(7, Color{r=59,g=74,b=140,a=255})  -- Indigo

local layer_names = {"outline","body","face","cap","gloves","stars","fx"}
for _,name in ipairs(layer_names) do
  local l = spr:newLayer()
  l.name = name
end
spr.layers[1].name = "guide"

local function add_frames(n)
  while #spr.frames < n do spr:newEmptyFrame() end
end
-- idle 4, intro 5, attack 6, attack1 6, attack3 6, summon 5, veil 6, hit 3, phase_2 7, death 5
add_frames(53)

local function tag(name, a, b)
  local t = spr:newTag(a,b)
  t.name = name
end

tag("idle", 1, 4)
tag("intro", 5, 9)
tag("attack", 10, 15)    -- Hieb (attack2 faellt hierauf zurueck)
tag("attack1", 16, 21)   -- Aussaugen (Drain)
tag("attack3", 22, 27)   -- Fluch aus Sternen (Hex)
tag("summon", 28, 32)    -- Wolken (Guard)
tag("veil", 33, 38)      -- Nebel zieht ueber die Buehne
tag("hit", 39, 41)
tag("phase_2", 42, 48)   -- wird zum Blutmond
tag("death", 49, 53)

for i=1,#spr.frames do
  spr.frames[i].duration = 1/12
end

-- Grobe Fuehrungslinien, keine fertige Kunst
local guide = spr.layers[1]
local img = Image(128,160,ColorMode.RGB)
img:clear()
local ink = pal:getColor(0)
local paper = pal:getColor(1)
local indigo = pal:getColor(7)
local gold = pal:getColor(5)
img:drawEllipse{rect=Rectangle(14,34,84,84), color=paper}
img:drawEllipse{rect=Rectangle(40,40,68,68), color=ink}
img:drawLine(Point(30,30), Point(48,6), indigo)
img:drawLine(Point(100,0), Point(100,40), gold)
spr:newCel(guide, spr.frames[1], img, Point(0,0))

app.activeSprite = spr
app.refresh()
